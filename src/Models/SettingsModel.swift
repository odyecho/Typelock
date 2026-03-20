import Foundation

/// 应用设置数据模型
class SettingsModel: ObservableObject, Codable {

    // MARK: - General Settings

    /// 是否开机自启动
    @Published var launchAtLogin = false

    /// 是否显示通知
    @Published var showNotifications = true

    /// 是否显示状态栏图标
    @Published var showStatusBarIcon = true

    // MARK: - Lock Settings

    /// 默认锁定状态
    @Published var defaultLockState = false

    /// 用户操作检测阈值（毫秒）
    @Published var userActionThreshold = 500

    /// 是否在应用切换时自动锁定
    @Published var autoLockOnAppSwitch = false

    /// 锁定时是否显示通知
    @Published var notifyOnLock = true

    /// 解锁时是否显示通知
    @Published var notifyOnUnlock = true

    // MARK: - Input Method Settings

    /// 偏好的输入法 ID
    @Published var preferredInputSourceId: String?

    /// 应用白名单（这些应用中不进行锁定）
    @Published var appWhitelist: Set<String> = []

    /// 输入法黑名单（不允许切换到这些输入法）
    @Published var inputMethodBlacklist: Set<String> = []

    // MARK: - UI Settings

    /// 快速操作面板宽度
    @Published var quickActionPanelWidth: Double = 320

    /// 状态栏图标样式
    @Published var statusBarIconStyle: StatusBarIconStyle = .adaptive

    /// 通知持续时间（秒）
    @Published var notificationDuration = 3.0

    // MARK: - Advanced Settings

    /// 调试模式
    @Published var debugMode = false

    /// 日志级别
    @Published var logLevel: LogLevel = .info

    /// 性能监控
    @Published var enablePerformanceMonitoring = false

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showNotifications
        case showStatusBarIcon
        case defaultLockState
        case userActionThreshold
        case autoLockOnAppSwitch
        case notifyOnLock
        case notifyOnUnlock
        case preferredInputSourceId
        case appWhitelist
        case inputMethodBlacklist
        case quickActionPanelWidth
        case statusBarIconStyle
        case notificationDuration
        case debugMode
        case logLevel
        case enablePerformanceMonitoring
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        showStatusBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showStatusBarIcon) ?? true
        defaultLockState = try container.decodeIfPresent(Bool.self, forKey: .defaultLockState) ?? false
        userActionThreshold = try container.decodeIfPresent(Int.self, forKey: .userActionThreshold) ?? 500
        autoLockOnAppSwitch = try container.decodeIfPresent(Bool.self, forKey: .autoLockOnAppSwitch) ?? false
        notifyOnLock = try container.decodeIfPresent(Bool.self, forKey: .notifyOnLock) ?? true
        notifyOnUnlock = try container.decodeIfPresent(Bool.self, forKey: .notifyOnUnlock) ?? true
        preferredInputSourceId = try container.decodeIfPresent(String.self, forKey: .preferredInputSourceId)
        appWhitelist = try container.decodeIfPresent(Set<String>.self, forKey: .appWhitelist) ?? []
        inputMethodBlacklist = try container.decodeIfPresent(Set<String>.self, forKey: .inputMethodBlacklist) ?? []
        quickActionPanelWidth = try container.decodeIfPresent(Double.self, forKey: .quickActionPanelWidth) ?? 320
        statusBarIconStyle = try container
            .decodeIfPresent(StatusBarIconStyle.self, forKey: .statusBarIconStyle) ?? .adaptive
        notificationDuration = try container.decodeIfPresent(Double.self, forKey: .notificationDuration) ?? 3.0
        debugMode = try container.decodeIfPresent(Bool.self, forKey: .debugMode) ?? false
        logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? .info
        enablePerformanceMonitoring = try container
            .decodeIfPresent(Bool.self, forKey: .enablePerformanceMonitoring) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(showNotifications, forKey: .showNotifications)
        try container.encode(showStatusBarIcon, forKey: .showStatusBarIcon)
        try container.encode(defaultLockState, forKey: .defaultLockState)
        try container.encode(userActionThreshold, forKey: .userActionThreshold)
        try container.encode(autoLockOnAppSwitch, forKey: .autoLockOnAppSwitch)
        try container.encode(notifyOnLock, forKey: .notifyOnLock)
        try container.encode(notifyOnUnlock, forKey: .notifyOnUnlock)
        try container.encode(preferredInputSourceId, forKey: .preferredInputSourceId)
        try container.encode(appWhitelist, forKey: .appWhitelist)
        try container.encode(inputMethodBlacklist, forKey: .inputMethodBlacklist)
        try container.encode(quickActionPanelWidth, forKey: .quickActionPanelWidth)
        try container.encode(statusBarIconStyle, forKey: .statusBarIconStyle)
        try container.encode(notificationDuration, forKey: .notificationDuration)
        try container.encode(debugMode, forKey: .debugMode)
        try container.encode(logLevel, forKey: .logLevel)
        try container.encode(enablePerformanceMonitoring, forKey: .enablePerformanceMonitoring)
    }

    // MARK: - Settings Management

    /// 加载设置
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "TypelockSettings"),
              let settings = try? JSONDecoder().decode(SettingsModel.self, from: data) else {
            // 使用默认设置
            return
        }

        // 复制加载的设置
        launchAtLogin = settings.launchAtLogin
        showNotifications = settings.showNotifications
        showStatusBarIcon = settings.showStatusBarIcon
        defaultLockState = settings.defaultLockState
        userActionThreshold = settings.userActionThreshold
        autoLockOnAppSwitch = settings.autoLockOnAppSwitch
        notifyOnLock = settings.notifyOnLock
        notifyOnUnlock = settings.notifyOnUnlock
        preferredInputSourceId = settings.preferredInputSourceId
        appWhitelist = settings.appWhitelist
        inputMethodBlacklist = settings.inputMethodBlacklist
        quickActionPanelWidth = settings.quickActionPanelWidth
        statusBarIconStyle = settings.statusBarIconStyle
        notificationDuration = settings.notificationDuration
        debugMode = settings.debugMode
        logLevel = settings.logLevel
        enablePerformanceMonitoring = settings.enablePerformanceMonitoring
    }

    /// 保存设置
    func saveSettings() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "TypelockSettings")
    }

    /// 重置为默认设置
    func resetToDefaults() {
        launchAtLogin = false
        showNotifications = true
        showStatusBarIcon = true
        defaultLockState = false
        userActionThreshold = 500
        autoLockOnAppSwitch = false
        notifyOnLock = true
        notifyOnUnlock = true
        preferredInputSourceId = nil
        appWhitelist.removeAll()
        inputMethodBlacklist.removeAll()
        quickActionPanelWidth = 320
        statusBarIconStyle = .adaptive
        notificationDuration = 3.0
        debugMode = false
        logLevel = .info
        enablePerformanceMonitoring = false

        saveSettings()
    }

    // MARK: - Helper Methods

    /// 添加应用到白名单
    /// - Parameter bundleId: 应用的 Bundle ID
    func addToWhitelist(_ bundleId: String) {
        appWhitelist.insert(bundleId)
        saveSettings()
    }

    /// 从白名单移除应用
    /// - Parameter bundleId: 应用的 Bundle ID
    func removeFromWhitelist(_ bundleId: String) {
        appWhitelist.remove(bundleId)
        saveSettings()
    }

    /// 检查应用是否在白名单中
    /// - Parameter bundleId: 应用的 Bundle ID
    /// - Returns: 是否在白名单中
    func isInWhitelist(_ bundleId: String) -> Bool {
        appWhitelist.contains(bundleId)
    }

    /// 添加输入法到黑名单
    /// - Parameter inputMethodId: 输入法 ID
    func addToBlacklist(_ inputMethodId: String) {
        inputMethodBlacklist.insert(inputMethodId)
        saveSettings()
    }

    /// 从黑名单移除输入法
    /// - Parameter inputMethodId: 输入法 ID
    func removeFromBlacklist(_ inputMethodId: String) {
        inputMethodBlacklist.remove(inputMethodId)
        saveSettings()
    }

    /// 检查输入法是否在黑名单中
    /// - Parameter inputMethodId: 输入法 ID
    /// - Returns: 是否在黑名单中
    func isInBlacklist(_ inputMethodId: String) -> Bool {
        inputMethodBlacklist.contains(inputMethodId)
    }
}

// MARK: - Supporting Enums

/// 状态栏图标样式
enum StatusBarIconStyle: String, CaseIterable, Codable {
    case adaptive // 自适应（根据系统主题）
    case light // 浅色
    case dark // 深色
    case colorful // 彩色

    var displayName: String {
        switch self {
        case .adaptive: return "自适应"
        case .light: return "浅色"
        case .dark: return "深色"
        case .colorful: return "彩色"
        }
    }
}

/// 日志级别
enum LogLevel: String, CaseIterable, Codable {
    case debug
    case info
    case warning
    case error

    var displayName: String {
        switch self {
        case .debug: return "调试"
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        }
    }
}
