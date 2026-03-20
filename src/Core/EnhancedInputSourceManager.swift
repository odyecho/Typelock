import Carbon
import Cocoa

/// 增强版输入法管理器
/// 提供更精确的输入法检测和管理功能
@MainActor
class EnhancedInputSourceManager: ObservableObject {

    // MARK: - Properties

    @Published var currentInputSource: InputSourceModel?
    @Published var availableInputSources: [InputSourceModel] = []
    @Published var isMonitoring = false

    private var lockEngine: EnhancedLockEngine?
    private var appStateManager: AppStateManager?
    private var logger = Logger.shared
    private var settings: SettingsModel

    /// 输入法状态变化回调
    var onInputSourceChanged: ((InputSourceModel) -> Void)?

    /// 锁定状态变化回调
    var onLockStateChanged: ((Bool) -> Void)?

    /// 输入法切换失败回调
    var onSwitchFailed: ((InputSourceModel, Error) -> Void)?

    // MARK: - Computed Properties

    /// 当前是否处于锁定状态
    var isLocked: Bool {
        lockEngine?.isLocked ?? false
    }

    /// 锁定的输入法
    var lockedInputSource: InputSourceModel? {
        lockEngine?.lockedInputSource
    }

    var debugIsLockPaused: Bool {
        lockEngine?.isPaused ?? false
    }

    // MARK: - Initialization

    init(settings: SettingsModel) {
        self.settings = settings
        lockEngine = EnhancedLockEngine(settings: settings)
        appStateManager = AppStateManager(settings: settings)

        setupLockEngineCallbacks()
        setupAppStateCallbacks()
        loadAvailableInputSources()
        updateCurrentInputSource()
    }

    // MARK: - Public Methods

    /// 开始监控输入法状态
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("输入法监控已在运行", category: "InputSource")
            return
        }

        isMonitoring = true
        setupInputSourceNotifications()
        lockEngine?.startMonitoring()
        appStateManager?.startMonitoring()

        logger.info("开始监控输入法状态", category: "InputSource")
    }

    /// 停止监控输入法状态
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        removeInputSourceNotifications()
        lockEngine?.stopMonitoring()
        appStateManager?.stopMonitoring()

        logger.info("停止监控输入法状态", category: "InputSource")
    }

    /// 获取当前输入法
    /// - Returns: 当前输入法信息
    func getCurrentInputSource() -> InputSourceModel? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            logger.warning("无法获取当前输入法", category: "InputSource")
            return nil
        }

        let model = createInputSourceModel(from: inputSource)
        logger.debug("当前输入法: \(model?.name ?? "未知")", category: "InputSource")
        return model
    }

    /// 获取所有可用的输入法
    /// - Returns: 输入法列表
    func getAvailableInputSources() -> [InputSourceModel] {
        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else {
            logger.warning("无法获取输入法列表", category: "InputSource")
            return []
        }

        let count = CFArrayGetCount(sources)
        var inputSources: [InputSourceModel] = []

        for i in 0..<count {
            let inputSource = CFArrayGetValueAtIndex(sources, i)
            guard let inputSource else { continue }
            let tisInputSource = Unmanaged<TISInputSource>.fromOpaque(inputSource).takeUnretainedValue()

            if let model = createInputSourceModel(from: tisInputSource) {
                // 只包含可选择且已启用的输入法
                if model.isSelectable, model.isEnabled {
                    inputSources.append(model)
                }
            }
        }

        logger.info("找到 \(inputSources.count) 个可用输入法", category: "InputSource")
        return inputSources.sorted { $0.name < $1.name }
    }

    /// 切换到指定的输入法
    /// - Parameter inputSource: 目标输入法
    /// - Returns: 是否切换成功
    @discardableResult
    func switchToInputSource(_ inputSource: InputSourceModel) -> Bool {
        logger.info("尝试切换到输入法: \(inputSource.name)", category: "InputSource")
        let shouldSyncLockedInputSource = isLocked

        if shouldSyncLockedInputSource {
            lockEngine?.markUserInitiatedSwitch(to: inputSource)
        }

        // 检查是否在黑名单中
        if settings.isInBlacklist(inputSource.id) {
            lockEngine?.cancelUserInitiatedSwitchIntent()
            logger.warning("输入法在黑名单中，拒绝切换: \(inputSource.name)", category: "InputSource")
            return false
        }

        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else {
            lockEngine?.cancelUserInitiatedSwitchIntent()
            let error = InputSourceError.systemError("无法获取输入法列表")
            logger.error("无法获取输入法列表进行切换", category: "InputSource")
            onSwitchFailed?(inputSource, error)
            return false
        }

        let count = CFArrayGetCount(sources)

        for i in 0..<count {
            let source = CFArrayGetValueAtIndex(sources, i)
            guard let source else { continue }
            let tisInputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()

            if let model = createInputSourceModel(from: tisInputSource),
               model.id == inputSource.id {
                let result = TISSelectInputSource(tisInputSource)

                if result == noErr {
                    if shouldSyncLockedInputSource {
                        lockEngine?.lockToInputSource(inputSource)
                        lockEngine?.cancelUserInitiatedSwitchIntent()
                    }
                    logger.info("成功切换到输入法: \(inputSource.name)", category: "InputSource")
                    return true
                } else {
                    lockEngine?.cancelUserInitiatedSwitchIntent()
                    let error = InputSourceError.switchFailed(code: result)
                    logger.error("切换输入法失败: \(inputSource.name), 错误码: \(result)", category: "InputSource")
                    onSwitchFailed?(inputSource, error)
                    return false
                }
            }
        }

        let error = InputSourceError.inputSourceNotFound(inputSource.id)
        lockEngine?.cancelUserInitiatedSwitchIntent()
        logger.error("未找到指定的输入法: \(inputSource.name)", category: "InputSource")
        onSwitchFailed?(inputSource, error)
        return false
    }

    /// 切换锁定状态
    func toggleLock() {
        lockEngine?.toggleLock()
    }

    /// 设置锁定状态
    /// - Parameter locked: 是否锁定
    func setLocked(_ locked: Bool) {
        lockEngine?.setLocked(locked)
    }

    /// 更新用户操作检测阈值
    /// - Parameter threshold: 阈值（毫秒）
    func updateUserActionThreshold(_ threshold: Int) {
        lockEngine?.updateUserActionThreshold(threshold)
    }

    /// 锁定到当前输入法
    func lockToCurrent() {
        guard let current = getCurrentInputSource() else {
            logger.warning("无法锁定到当前输入法：无法获取当前输入法", category: "InputSource")
            return
        }

        lockEngine?.lockToInputSource(current)
        logger.info("锁定到当前输入法: \(current.name)", category: "InputSource")
    }

    /// 锁定到指定输入法
    /// - Parameter inputSource: 要锁定的输入法
    func lockToInputSource(_ inputSource: InputSourceModel) {
        lockEngine?.lockToInputSource(inputSource)
        logger.info("锁定到指定输入法: \(inputSource.name)", category: "InputSource")
    }

    /// 刷新输入法列表
    func refreshInputSources() {
        loadAvailableInputSources()
        updateCurrentInputSource()
        logger.info("刷新输入法列表完成", category: "InputSource")
    }

    /// 清理资源
    func cleanup() {
        stopMonitoring()
        lockEngine?.cleanup()
        appStateManager?.cleanup()
        logger.info("输入法管理器清理完成", category: "InputSource")
    }

    // MARK: - Private Methods

    /// 设置锁定引擎回调
    private func setupLockEngineCallbacks() {
        self.lockEngine?.onLockStateChanged = { [weak self] isLocked in
            DispatchQueue.main.async {
                // 触发 SwiftUI 重绘（isLocked 是计算属性，不会自动 publish）
                self?.objectWillChange.send()
                self?.onLockStateChanged?(isLocked)
            }
        }

        lockEngine?.onInputSourceRestored = { [weak self] inputSource in
            self?.logger.info("输入法已恢复: \(inputSource.name)", category: "InputSource")
        }
    }

    /// 设置应用状态回调
    private func setupAppStateCallbacks() {
        appStateManager?.onAppChanged = { [weak self] appInfo in
            self?.handleAppChanged(appInfo)
        }
    }

    /// 处理应用切换
    private func handleAppChanged(_ appInfo: AppInfo) {
        logger.debug("应用切换: \(appInfo.localizedName)", category: "InputSource")

        // 如果当前应用在白名单中，暂停锁定
        if settings.isInWhitelist(appInfo.bundleIdentifier) {
            lockEngine?.pauseLocking()
            logger.info("当前应用在白名单中，暂停锁定: \(appInfo.localizedName)", category: "InputSource")
        } else {
            lockEngine?.resumeLocking()
            logger.debug("恢复锁定功能", category: "InputSource")
        }

        // 如果启用了应用切换时自动锁定
        if settings.autoLockOnAppSwitch, !settings.isInWhitelist(appInfo.bundleIdentifier) {
            lockToCurrent()
        }
    }

    func processAppChangeForTesting(_ appInfo: AppInfo) {
        handleAppChanged(appInfo)
    }

    func processAppChangeForTesting(_ appInfo: AppInfo, simulatedCurrentInputSource: InputSourceModel) {
        logger.debug("测试路径应用切换: \(appInfo.localizedName)", category: "InputSource")

        if settings.isInWhitelist(appInfo.bundleIdentifier) {
            lockEngine?.pauseLocking()
        } else {
            lockEngine?.resumeLocking()
        }

        if settings.autoLockOnAppSwitch, !settings.isInWhitelist(appInfo.bundleIdentifier) {
            lockEngine?.lockToInputSource(simulatedCurrentInputSource)
        }
    }

    /// 加载可用输入法列表
    private func loadAvailableInputSources() {
        availableInputSources = getAvailableInputSources()
    }

    /// 更新当前输入法
    private func updateCurrentInputSource() {
        currentInputSource = getCurrentInputSource()
    }

    /// 设置输入法变化通知
    private func setupInputSourceNotifications() {
        let notificationCenter = DistributedNotificationCenter.default()

        notificationCenter.addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(inputSourceListDidChange),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )
    }

    /// 移除输入法变化通知
    private func removeInputSourceNotifications() {
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.removeObserver(self)
    }

    /// 输入法变化通知处理
    @objc private func inputSourceDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let previousInputSource = self.currentInputSource
            self.updateCurrentInputSource()

            guard let newInputSource = self.currentInputSource else { return }

            // 检查是否真的发生了变化
            if previousInputSource?.id != newInputSource.id {
                self.logger.info(
                    "输入法变化: \(previousInputSource?.name ?? "未知") -> \(newInputSource.name)",
                    category: "InputSource"
                )

                // 通知锁定引擎
                self.lockEngine?.handleInputSourceChange(newInputSource)

                // 通知外部监听者
                self.onInputSourceChanged?(newInputSource)
            }
        }
    }

    /// 输入法列表变化通知处理
    @objc private func inputSourceListDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.logger.info("输入法列表发生变化，重新加载", category: "InputSource")
            self?.loadAvailableInputSources()
        }
    }

    /// 从 TISInputSource 创建 InputSourceModel
    /// - Parameter inputSource: TIS 输入法对象
    /// - Returns: 输入法模型
    private func createInputSourceModel(from inputSource: TISInputSource) -> InputSourceModel? {
        // 获取输入法 ID
        guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return nil
        }
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

        // 获取输入法名称
        let sourceName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName)
        let name = sourceName.flatMap { sourceName in
            Unmanaged<CFString>.fromOpaque(sourceName).takeUnretainedValue() as String
        } ?? id

        // 获取输入法类型
        let sourceCategory = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory)
        let category = sourceCategory.flatMap { sourceCategory in
            Unmanaged<CFString>.fromOpaque(sourceCategory).takeUnretainedValue() as String
        } ?? ""

        // 检查是否可选择
        let selectableProperty = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable)
        let isSelectable = selectableProperty.map { selectableProperty in
            CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(selectableProperty).takeUnretainedValue())
        } ?? false

        // 检查是否启用
        let enabledProperty = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
        let isEnabled = enabledProperty.map { enabledProperty in
            CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledProperty).takeUnretainedValue())
        } ?? false

        return InputSourceModel(
            id: id,
            name: name,
            category: category,
            isSelectable: isSelectable,
            isEnabled: isEnabled
        )
    }
}

// MARK: - InputSourceError

enum InputSourceError: LocalizedError {
    case inputSourceNotFound(String)
    case switchFailed(code: OSStatus)
    case permissionDenied
    case systemError(String)

    var errorDescription: String? {
        switch self {
        case let .inputSourceNotFound(id):
            return "未找到输入法: \(id)"
        case let .switchFailed(code):
            return "输入法切换失败，错误码: \(code)"
        case .permissionDenied:
            return "权限不足，无法切换输入法"
        case let .systemError(message):
            return "系统错误: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .inputSourceNotFound:
            return "请检查输入法是否已安装并启用"
        case .switchFailed:
            return "请重试或检查系统设置"
        case .permissionDenied:
            return "请在系统偏好设置中授予辅助功能权限"
        case .systemError:
            return "请重启应用或联系技术支持"
        }
    }
}
