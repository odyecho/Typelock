import Carbon
import Cocoa

/// 快捷键管理器
/// 负责全局快捷键的注册和处理
class HotKeyManager {

    // MARK: - Properties

    private var hotKeys: [HotKeyID: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var logger = Logger.shared

    /// 快捷键回调
    var onHotKeyPressed: ((HotKeyID) -> Void)?

    // MARK: - Initialization

    init() {
        setupEventHandler()
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    /// 注册快捷键
    /// - Parameters:
    ///   - keyCode: 键码
    ///   - modifiers: 修饰键
    ///   - identifier: 快捷键标识符
    /// - Returns: 是否注册成功
    @discardableResult
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, identifier: HotKeyID) -> Bool {
        // 如果已经注册，先取消注册
        if hotKeys[identifier] != nil {
            unregisterHotKey(identifier: identifier)
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(identifier.signature), id: UInt32(identifier.rawValue))

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventMonitorTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeys[identifier] = hotKeyRef
            logger.info("快捷键注册成功: \(identifier.description)", category: "HotKey")
            return true
        } else {
            logger.error("快捷键注册失败: \(identifier.description), 状态码: \(status)", category: "HotKey")
            return false
        }
    }

    /// 取消注册快捷键
    /// - Parameter identifier: 快捷键标识符
    func unregisterHotKey(identifier: HotKeyID) {
        guard let hotKeyRef = hotKeys[identifier] else { return }

        let status = UnregisterEventHotKey(hotKeyRef)
        if status == noErr {
            hotKeys.removeValue(forKey: identifier)
            logger.info("快捷键取消注册: \(identifier.description)", category: "HotKey")
        } else {
            logger.error("快捷键取消注册失败: \(identifier.description), 状态码: \(status)", category: "HotKey")
        }
    }

    /// 注册默认快捷键
    func registerDefaultHotKeys() {
        // Ctrl+Option+L: 切换锁定状态（避免与常用应用冲突）
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(controlKey | optionKey),
            identifier: .toggleLock
        )

        // Ctrl+Option+T: 显示快速操作面板
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(controlKey | optionKey),
            identifier: .showQuickActions
        )

        // Ctrl+Option+Comma: 显示设置（逗号键是设置的通用惯例）
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_Comma),
            modifiers: UInt32(controlKey | optionKey),
            identifier: .showSettings
        )

        // Ctrl+Option+R: 刷新输入法列表
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: UInt32(controlKey | optionKey),
            identifier: .refreshInputSources
        )

        logger.info("默认快捷键注册完成", category: "HotKey")
    }

    /// 取消所有快捷键
    func unregisterAllHotKeys() {
        for identifier in hotKeys.keys {
            unregisterHotKey(identifier: identifier)
        }
        logger.info("所有快捷键已取消注册", category: "HotKey")
    }

    /// 清理资源
    func cleanup() {
        unregisterAllHotKeys()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        logger.info("快捷键管理器清理完成", category: "HotKey")
    }

    // MARK: - Private Methods

    /// 设置事件处理器
    private func setupEventHandler() {
        let eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            ),
        ]

        let status = InstallEventHandler(
            GetEventMonitorTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                guard let event else { return OSStatus(eventNotHandledErr) }
                let hotKeyManager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return hotKeyManager.handleHotKeyEvent(event: event)
            },
            1,
            eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status == noErr {
            logger.info("快捷键事件处理器设置成功", category: "HotKey")
        } else {
            logger.error("快捷键事件处理器设置失败, 状态码: \(status)", category: "HotKey")
        }
    }

    /// 处理快捷键事件
    private func handleHotKeyEvent(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            logger.error("获取快捷键事件参数失败, 状态码: \(status)", category: "HotKey")
            return OSStatus(eventNotHandledErr)
        }

        // 查找对应的快捷键标识符
        for (identifier, _) in hotKeys {
            if identifier.signature == hotKeyID.signature, identifier.rawValue == Int(hotKeyID.id) {
                logger.debug("快捷键触发: \(identifier.description)", category: "HotKey")
                DispatchQueue.main.async { [weak self] in
                    self?.onHotKeyPressed?(identifier)
                }
                return noErr
            }
        }

        return OSStatus(eventNotHandledErr)
    }
}

// MARK: - HotKeyID

enum HotKeyID: Int, CaseIterable {
    case toggleLock = 1
    case showQuickActions = 2
    case showSettings = 3
    case refreshInputSources = 4
    case switchToNext = 5
    case switchToPrevious = 6

    /// 快捷键签名
    var signature: UInt32 {
        0x5459_5045
    }

    /// 描述
    var description: String {
        switch self {
        case .toggleLock:
            return "切换锁定状态 (⌃⌥L)"
        case .showQuickActions:
            return "显示快速操作 (⌃⌥T)"
        case .showSettings:
            return "显示设置 (⌃⌥,)"
        case .refreshInputSources:
            return "刷新输入法 (⌃⌥R)"
        case .switchToNext:
            return "切换到下一个输入法"
        case .switchToPrevious:
            return "切换到上一个输入法"
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .toggleLock:
            return "切换锁定状态"
        case .showQuickActions:
            return "显示快速操作"
        case .showSettings:
            return "显示设置"
        case .refreshInputSources:
            return "刷新输入法"
        case .switchToNext:
            return "下一个输入法"
        case .switchToPrevious:
            return "上一个输入法"
        }
    }

    /// 默认快捷键组合
    var defaultKeyCombo: (keyCode: UInt32, modifiers: UInt32)? {
        switch self {
        case .toggleLock:
            return (UInt32(kVK_ANSI_L), UInt32(controlKey | optionKey))
        case .showQuickActions:
            return (UInt32(kVK_ANSI_T), UInt32(controlKey | optionKey))
        case .showSettings:
            return (UInt32(kVK_ANSI_Comma), UInt32(controlKey | optionKey))
        case .refreshInputSources:
            return (UInt32(kVK_ANSI_R), UInt32(controlKey | optionKey))
        case .switchToNext:
            return nil // 用户自定义
        case .switchToPrevious:
            return nil // 用户自定义
        }
    }
}

// MARK: - Key Code Constants

extension HotKeyManager {
    /// 常用键码
    enum KeyCodes {
        static let escape: UInt32 = 53
        static let space: UInt32 = 49
        static let enter: UInt32 = 36
        static let tab: UInt32 = 48
        static let delete: UInt32 = 51
        static let forwardDelete: UInt32 = 117

        // 字母键
        static let a: UInt32 = 0
        static let s: UInt32 = 1
        static let d: UInt32 = 2
        static let f: UInt32 = 3
        static let h: UInt32 = 4
        static let g: UInt32 = 5
        static let z: UInt32 = 6
        static let x: UInt32 = 7
        static let c: UInt32 = 8
        static let v: UInt32 = 9
        static let b: UInt32 = 11
        static let q: UInt32 = 12
        static let w: UInt32 = 13
        static let e: UInt32 = 14
        static let r: UInt32 = 15
        static let y: UInt32 = 16
        static let t: UInt32 = 17
        static let o: UInt32 = 31
        static let u: UInt32 = 32
        static let i: UInt32 = 34
        static let p: UInt32 = 35
        static let l: UInt32 = 37
        static let j: UInt32 = 38
        static let k: UInt32 = 40
        static let n: UInt32 = 45
        static let m: UInt32 = 46

        // 数字键
        static let num1: UInt32 = 18
        static let num2: UInt32 = 19
        static let num3: UInt32 = 20
        static let num4: UInt32 = 21
        static let num6: UInt32 = 22
        static let num5: UInt32 = 23
        static let num9: UInt32 = 25
        static let num7: UInt32 = 26
        static let num8: UInt32 = 28
        static let num0: UInt32 = 29

        // 功能键
        static let f1: UInt32 = 122
        static let f2: UInt32 = 120
        static let f3: UInt32 = 99
        static let f4: UInt32 = 118
        static let f5: UInt32 = 96
        static let f6: UInt32 = 97
        static let f7: UInt32 = 98
        static let f8: UInt32 = 100
        static let f9: UInt32 = 101
        static let f10: UInt32 = 109
        static let f11: UInt32 = 103
        static let f12: UInt32 = 111

        // 方向键
        static let leftArrow: UInt32 = 123
        static let rightArrow: UInt32 = 124
        static let downArrow: UInt32 = 125
        static let upArrow: UInt32 = 126
    }

    /// 修饰键
    enum Modifiers {
        static let command = UInt32(cmdKey)
        static let shift = UInt32(shiftKey)
        static let option = UInt32(optionKey)
        static let control = UInt32(controlKey)
        static let capsLock = UInt32(alphaLock)
    }
}
