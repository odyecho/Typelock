import Carbon
import Cocoa

class InputSourceManager {

    // MARK: - Properties

    private let logger = Logger.shared
    private var isMonitoring = false
    private var lockEngine: LockEngine?

    /// 当前是否处于锁定状态
    var isLocked: Bool {
        lockEngine?.isLocked ?? false
    }

    /// 输入法状态变化回调
    var onInputSourceChanged: ((InputSourceModel) -> Void)?

    /// 锁定状态变化回调
    var onLockStateChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    init() {
        lockEngine = LockEngine()
        setupLockEngineCallbacks()
    }

    // MARK: - Public Methods

    /// 开始监控输入法状态
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        setupInputSourceNotifications()
        lockEngine?.startMonitoring()

        logger.info("开始监控输入法状态", category: "InputSource")
    }

    /// 停止监控输入法状态
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        removeInputSourceNotifications()
        lockEngine?.stopMonitoring()

        logger.info("停止监控输入法状态", category: "InputSource")
    }

    /// 获取当前输入法
    /// - Returns: 当前输入法信息
    func getCurrentInputSource() -> InputSourceModel? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return createInputSourceModel(from: inputSource)
    }

    /// 获取所有可用的输入法
    /// - Returns: 输入法列表
    func getAvailableInputSources() -> [InputSourceModel] {
        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else { return [] }

        let count = CFArrayGetCount(sources)
        var inputSources: [InputSourceModel] = []

        for i in 0..<count {
            let inputSource = CFArrayGetValueAtIndex(sources, i)
            guard let inputSource else { continue }
            let tisInputSource = Unmanaged<TISInputSource>.fromOpaque(inputSource).takeUnretainedValue()

            if let model = createInputSourceModel(from: tisInputSource) {
                inputSources.append(model)
            }
        }

        return inputSources
    }

    /// 切换到指定的输入法
    /// - Parameter inputSource: 目标输入法
    /// - Returns: 是否切换成功
    @discardableResult
    func switchToInputSource(_ inputSource: InputSourceModel) -> Bool {
        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else { return false }

        let count = CFArrayGetCount(sources)

        for i in 0..<count {
            let source = CFArrayGetValueAtIndex(sources, i)
            guard let source else { continue }
            let tisInputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()

            if let model = createInputSourceModel(from: tisInputSource),
               model.id == inputSource.id {
                let result = TISSelectInputSource(tisInputSource)
                return result == noErr
            }
        }

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

    /// 清理资源
    func cleanup() {
        stopMonitoring()
        lockEngine?.cleanup()
    }

    // MARK: - Private Methods

    /// 设置锁定引擎回调
    private func setupLockEngineCallbacks() {
        self.lockEngine?.onLockStateChanged = { [weak self] isLocked in
            self?.onLockStateChanged?(isLocked)
        }
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
    }

    /// 移除输入法变化通知
    private func removeInputSourceNotifications() {
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.removeObserver(self)
    }

    /// 输入法变化通知处理
    @objc private func inputSourceDidChange() {
        guard let currentInputSource = getCurrentInputSource() else { return }

        logger.info("输入法变化 - \(currentInputSource.name)", category: "InputSource")

        // 通知锁定引擎
        lockEngine?.handleInputSourceChange(currentInputSource)

        // 通知外部监听者
        onInputSourceChanged?(currentInputSource)
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
