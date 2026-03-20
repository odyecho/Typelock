import Carbon
import Cocoa

/// 增强版锁定引擎
/// 提供更智能的用户操作检测和输入法锁定功能
class EnhancedLockEngine {

    // MARK: - Properties

    private var _isLocked = false
    private var _isPaused = false
    private var _lockedInputSource: InputSourceModel?
    private var isMonitoring = false

    private var lastUserActionTime = Date()
    private var lastInputSourceChangeTime = Date()
    private var userActionThreshold: TimeInterval
    private var pendingUserInitiatedSwitch: (inputSourceId: String, expiry: Date)?
    private var consecutiveAutoSwitches = 0
    private var maxConsecutiveSwitches = 3
    private var restoreAttempts = 0
    private let delayedRestoreInterval: TimeInterval = 0.12

    private var eventMonitors: [Any] = []
    private var logger = Logger.shared
    private var settings: SettingsModel

    // 防抖：避免同一次切换触发多轮恢复
    private var pendingRestoreWorkItems: [DispatchWorkItem] = []

    /// 当前是否处于锁定状态
    var isLocked: Bool {
        _isLocked && !_isPaused
    }

    /// 当前是否暂停锁定
    var isPaused: Bool {
        _isPaused
    }

    /// 锁定的输入法
    var lockedInputSource: InputSourceModel? {
        _lockedInputSource
    }

    var debugConsecutiveAutoSwitches: Int {
        consecutiveAutoSwitches
    }

    var debugRestoreAttempts: Int {
        restoreAttempts
    }

    /// 锁定状态变化回调
    var onLockStateChanged: ((Bool) -> Void)?

    /// 输入法恢复回调
    var onInputSourceRestored: ((InputSourceModel) -> Void)?

    /// 用户操作检测回调
    var onUserActionDetected: (() -> Void)?

    // MARK: - Initialization

    init(settings: SettingsModel) {
        self.settings = settings
        userActionThreshold = TimeInterval(settings.userActionThreshold) / 1_000.0
    }

    // MARK: - Public Methods

    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("锁定引擎已在监控中", category: "LockEngine")
            return
        }

        isMonitoring = true
        setupUserActionMonitoring()
        logger.info("锁定引擎开始监控", category: "LockEngine")
    }

    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        removeUserActionMonitoring()
        logger.info("锁定引擎停止监控", category: "LockEngine")
    }

    /// 切换锁定状态
    func toggleLock() {
        setLocked(!_isLocked)
    }

    /// 设置锁定状态
    /// - Parameter locked: 是否锁定
    func setLocked(_ locked: Bool) {
        let wasLocked = _isLocked
        _isLocked = locked

        if locked, _lockedInputSource == nil {
            // 锁定时如果没有指定输入法，使用当前输入法
            _lockedInputSource = getCurrentInputSource()
        } else if !locked {
            // 解锁时清除锁定状态和所有待执行的恢复任务
            _lockedInputSource = nil
            pendingUserInitiatedSwitch = nil
            consecutiveAutoSwitches = 0
            restoreAttempts = 0
            for item in pendingRestoreWorkItems { item.cancel() }
            pendingRestoreWorkItems.removeAll()
        }

        logger.info(
            "锁定状态变更: \(wasLocked) -> \(_isLocked), 输入法: \(_lockedInputSource?.name ?? "无")",
            category: "LockEngine"
        )

        // 通知状态变化
        if wasLocked != _isLocked {
            onLockStateChanged?(_isLocked)
        }
    }

    /// 锁定到指定输入法
    /// - Parameter inputSource: 要锁定的输入法
    func lockToInputSource(_ inputSource: InputSourceModel) {
        cancelUserInitiatedSwitchIntent()
        _lockedInputSource = inputSource
        setLocked(true)
        logger.info("锁定到指定输入法: \(inputSource.name)", category: "LockEngine")
    }

    /// 标记下一次输入法切换为用户主动切换
    /// - Parameter inputSource: 用户期望切换到的输入法
    func markUserInitiatedSwitch(to inputSource: InputSourceModel) {
        let expiry = Date().addingTimeInterval(userActionThreshold)
        pendingUserInitiatedSwitch = (inputSource.id, expiry)
        logger.debug(
            "记录用户主动切换意图: \(inputSource.name), 过期时间: \(expiry)",
            category: "LockEngine"
        )
    }

    /// 取消用户主动切换意图
    func cancelUserInitiatedSwitchIntent() {
        pendingUserInitiatedSwitch = nil
    }

    /// 暂停锁定
    func pauseLocking() {
        if !_isPaused {
            _isPaused = true
            logger.info("暂停锁定功能", category: "LockEngine")
            onLockStateChanged?(false)
        }
    }

    /// 恢复锁定
    func resumeLocking() {
        if _isPaused {
            _isPaused = false
            logger.info("恢复锁定功能", category: "LockEngine")
            if _isLocked {
                onLockStateChanged?(true)
            }
        }
    }

    /// 处理输入法变化
    /// - Parameter newInputSource: 新的输入法
    func handleInputSourceChange(_ newInputSource: InputSourceModel) {
        guard isLocked, let locked = _lockedInputSource else { return }

        lastInputSourceChangeTime = Date()

        // 检查是否切换到了不同的输入法
        if newInputSource.id != locked.id {
            let isUserAction = isPendingUserInitiatedSwitch(to: newInputSource)

            logger.debug(
                "输入法变化检测 - 目标: \(newInputSource.name), 阈值: \(userActionThreshold)s, 用户操作: \(isUserAction)",
                category: "LockEngine"
            )

            if isUserAction {
                // 用户主动切换，更新锁定的输入法
                pendingUserInitiatedSwitch = nil
                handleUserInitiatedSwitch(to: newInputSource)
            } else {
                // 系统自动切换，恢复到锁定的输入法
                handleSystemInitiatedSwitch(from: newInputSource, to: locked)
            }
        } else {
            // 切换回了锁定的输入法，重置计数器
            consecutiveAutoSwitches = 0
        }
    }

    /// 更新用户操作阈值
    /// - Parameter threshold: 新的阈值（毫秒）
    func updateUserActionThreshold(_ threshold: Int) {
        userActionThreshold = TimeInterval(threshold) / 1_000.0
        logger.info("更新用户操作阈值: \(threshold)ms", category: "LockEngine")
    }

    /// 清理资源
    func cleanup() {
        stopMonitoring()
        _isLocked = false
        _isPaused = false
        _lockedInputSource = nil
        pendingUserInitiatedSwitch = nil
        for item in pendingRestoreWorkItems { item.cancel() }
        pendingRestoreWorkItems.removeAll()
        logger.info("锁定引擎清理完成", category: "LockEngine")
    }

    // MARK: - Private Methods

    /// 处理用户主动切换
    private func handleUserInitiatedSwitch(to newInputSource: InputSourceModel) {
        _lockedInputSource = newInputSource
        consecutiveAutoSwitches = 0
        restoreAttempts = 0

        logger.info("用户主动切换，更新锁定输入法: \(newInputSource.name)", category: "LockEngine")

        // 如果设置中有偏好输入法，更新它
        if settings.preferredInputSourceId != newInputSource.id {
            settings.preferredInputSourceId = newInputSource.id
            settings.saveSettings()
        }
    }

    /// 处理系统自动切换
    private func handleSystemInitiatedSwitch(
        from currentInputSource: InputSourceModel,
        to targetInputSource: InputSourceModel
    ) {
        consecutiveAutoSwitches += 1

        logger.warning(
            "检测到系统自动切换 (\(consecutiveAutoSwitches)/\(maxConsecutiveSwitches)): \(currentInputSource.name) -> \(targetInputSource.name)",
            category: "LockEngine"
        )

        if consecutiveAutoSwitches >= maxConsecutiveSwitches {
            logger.error("连续自动切换次数过多，持续执行恢复策略", category: "LockEngine")
        }

        restoreAttempts += 1
        restoreLockedInputSource()
    }

    /// 恢复到锁定的输入法
    private func restoreLockedInputSource() {
        guard let locked = _lockedInputSource else { return }

        // 取消之前尚未执行的延迟恢复，避免堆积
        for item in pendingRestoreWorkItems { item.cancel() }
        pendingRestoreWorkItems.removeAll()

        logger.info("恢复到锁定输入法: \(locked.name)", category: "LockEngine")

        // 立即尝试一次
        if switchToInputSource(locked) {
            onInputSourceRestored?(locked)
        } else {
            logger.error("立即恢复输入法失败: \(locked.name)", category: "LockEngine")
        }

        // 在 30ms / 100ms / 300ms 后再各检查一次
        // 应对快速连按 / 长按 Ctrl+Space 导致系统持续切换的情况
        let delays: [TimeInterval] = [0.03, 0.1, 0.3]
        for delay in delays {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.isLocked,
                      let target = self._lockedInputSource,
                      target.id == locked.id else { return }
                let currentId = self.getCurrentInputSource()?.id
                if currentId != target.id {
                    self.logger.warning(
                        "延迟恢复（\(Int(delay * 1000))ms）：当前 \(currentId ?? "未知") -> \(target.name)",
                        category: "LockEngine"
                    )
                    if self.switchToInputSource(target) {
                        self.onInputSourceRestored?(target)
                    }
                }
            }
            pendingRestoreWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    /// 切换到指定输入法
    private func switchToInputSource(_ inputSource: InputSourceModel) -> Bool {
        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else { return false }

        let count = CFArrayGetCount(sources)

        for i in 0..<count {
            let source = CFArrayGetValueAtIndex(sources, i)
            guard let source else { continue }
            let tisInputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()

            // 获取输入法 ID 进行比较
            guard let sourceID = TISGetInputSourceProperty(tisInputSource, kTISPropertyInputSourceID) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

            if id == inputSource.id {
                let result = TISSelectInputSource(tisInputSource)
                if result == noErr {
                    logger.debug("成功切换到输入法: \(inputSource.name)", category: "LockEngine")
                    return true
                } else {
                    logger.error("切换输入法失败: \(inputSource.name), 错误码: \(result)", category: "LockEngine")
                    return false
                }
            }
        }

        logger.error("未找到指定输入法: \(inputSource.name)", category: "LockEngine")
        return false
    }

    private func isPendingUserInitiatedSwitch(to inputSource: InputSourceModel) -> Bool {
        guard let pendingUserInitiatedSwitch else {
            return false
        }

        if Date() > pendingUserInitiatedSwitch.expiry {
            self.pendingUserInitiatedSwitch = nil
            return false
        }

        if pendingUserInitiatedSwitch.inputSourceId != inputSource.id {
            return false
        }

        return true
    }

    /// 获取当前输入法
    private func getCurrentInputSource() -> InputSourceModel? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

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

        return InputSourceModel(
            id: id,
            name: name,
            category: "",
            isSelectable: true,
            isEnabled: true
        )
    }

    /// 设置用户操作监控
    private func setupUserActionMonitoring() {
        // 监控全局键盘事件
        let keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .keyDown,
            .keyUp,
            .flagsChanged,
        ]) { [weak self] event in
            self?.handleUserAction(type: "keyboard", details: "keyCode: \(event.keyCode)")
        }

        // 监控全局鼠标事件
        let mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ]) { [weak self] event in
            self?.handleUserAction(type: "mouse", details: "button: \(event.buttonNumber)")
        }

        // 监控本地事件（应用内）
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
        ]) { [weak self] event in
            self?.handleUserAction(type: "local", details: "type: \(event.type.rawValue)")
            return event
        }

        // 保存监控器引用
        if let keyboardMonitor {
            eventMonitors.append(keyboardMonitor)
        }
        if let mouseMonitor {
            eventMonitors.append(mouseMonitor)
        }
        if let localMonitor {
            eventMonitors.append(localMonitor)
        }

        logger.debug("用户操作监控已设置，监控器数量: \(eventMonitors.count)", category: "LockEngine")
    }

    /// 移除用户操作监控
    private func removeUserActionMonitoring() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        logger.debug("用户操作监控已移除", category: "LockEngine")
    }

    /// 处理用户操作
    private func handleUserAction(type: String, details: String) {
        let now = Date()
        let timeSinceLastAction = now.timeIntervalSince(lastUserActionTime)

        // 避免过于频繁的日志
        if timeSinceLastAction > 0.1 {
            logger.debug("用户操作检测: \(type) - \(details)", category: "LockEngine")
        }

        lastUserActionTime = now
        onUserActionDetected?()
    }
}
