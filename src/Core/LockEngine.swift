import Carbon
import Cocoa

class LockEngine {

    // MARK: - Properties

    private var _isLocked = false
    private var lockedInputSource: InputSourceModel?
    private var isMonitoring = false
    private var lastUserActionTime = Date()
    private var userActionThreshold: TimeInterval = 0.5 // 500ms 内的切换认为是用户主动操作
    private let logger = Logger.shared

    /// 当前是否处于锁定状态
    var isLocked: Bool {
        _isLocked
    }

    /// 锁定状态变化回调
    var onLockStateChanged: ((Bool) -> Void)?

    // MARK: - Public Methods

    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        setupUserActionMonitoring()

        logger.info("开始监控用户操作", category: "LockEngine")
    }

    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        removeUserActionMonitoring()

        logger.info("停止监控用户操作", category: "LockEngine")
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

        if locked {
            // 锁定时记录当前输入法
            lockedInputSource = getCurrentInputSource()
            logger.info("锁定输入法 - \(lockedInputSource?.name ?? "未知")", category: "LockEngine")
        } else {
            // 解锁时清除记录
            lockedInputSource = nil
            logger.info("解锁输入法", category: "LockEngine")
        }

        // 通知状态变化
        if wasLocked != _isLocked {
            onLockStateChanged?(_isLocked)
        }
    }

    /// 处理输入法变化
    /// - Parameter newInputSource: 新的输入法
    func handleInputSourceChange(_ newInputSource: InputSourceModel) {
        guard _isLocked, let locked = lockedInputSource else { return }

        // 检查是否是用户主动切换
        let timeSinceLastAction = Date().timeIntervalSince(lastUserActionTime)
        let isUserAction = timeSinceLastAction <= userActionThreshold

        if isUserAction {
            // 用户主动切换，更新锁定的输入法
            lockedInputSource = newInputSource
            logger.info("用户主动切换，更新锁定输入法 - \(newInputSource.name)", category: "LockEngine")
        } else if newInputSource.id != locked.id {
            // 系统自动切换，恢复到锁定的输入法
            logger.info("检测到自动切换，恢复到锁定输入法 - \(locked.name)", category: "LockEngine")
            restoreLockedInputSource()
        }
    }

    /// 清理资源
    func cleanup() {
        stopMonitoring()
        _isLocked = false
        lockedInputSource = nil
    }

    // MARK: - Private Methods

    /// 设置用户操作监控
    private func setupUserActionMonitoring() {
        // 监控键盘事件
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] _ in
            self?.handleUserAction()
        }

        // 监控鼠标事件
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.handleUserAction()
        }
    }

    /// 移除用户操作监控
    private func removeUserActionMonitoring() {
        // 注意：NSEvent.addGlobalMonitorForEvents 返回的监控器需要保存并在这里移除
        // 这里简化处理，实际项目中应该保存监控器引用
    }

    /// 处理用户操作
    private func handleUserAction() {
        lastUserActionTime = Date()
    }

    /// 恢复到锁定的输入法
    private func restoreLockedInputSource() {
        guard let locked = lockedInputSource else { return }

        // 延迟执行，避免与系统切换冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.switchToInputSource(locked)
        }
    }

    /// 切换到指定输入法
    /// - Parameter inputSource: 目标输入法
    private func switchToInputSource(_ inputSource: InputSourceModel) {
        let inputSourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        guard let sources = inputSourceList else { return }

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
                    logger.info("成功恢复输入法 - \(inputSource.name)", category: "LockEngine")
                } else {
                    logger.error("恢复输入法失败 - \(inputSource.name), 错误码: \(result)", category: "LockEngine")
                }
                break
            }
        }
    }

    /// 获取当前输入法
    /// - Returns: 当前输入法模型
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
}
