import Foundation

/// 应用常量定义
enum Constants {

    // MARK: - App Information

    enum App {
        static let name = "Typelock"
        static let bundleId = "com.typelock.macos"
        static let copyright = "Copyright © 2026 Typelock. All rights reserved."

        /// 从应用 Bundle 读取版本号，避免与构建配置重复维护。
        static var version: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }

        /// 从应用 Bundle 读取构建号，确保界面显示与安装包一致。
        static var build: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        }
    }

    // MARK: - User Defaults Keys

    enum UserDefaults {
        static let settings = "TypelockSettings"
        static let firstLaunch = "TypelockFirstLaunch"
        static let lastVersion = "TypelockLastVersion"
        static let lockState = "TypelockLockState"
        static let preferredInputSource = "TypelockPreferredInputSource"
    }

    // MARK: - Notification Names

    enum Notifications {
        static let inputSourceChanged = "TypelockInputSourceChanged"
        static let lockStateChanged = "TypelockLockStateChanged"
        static let settingsChanged = "TypelockSettingsChanged"
        static let permissionGranted = "TypelockPermissionGranted"
        static let permissionDenied = "TypelockPermissionDenied"
    }

    // MARK: - UI Constants

    enum UI {
        // Status Bar
        static let statusBarIconSize: CGFloat = 18
        static let statusBarSpacing: CGFloat = 4

        // Quick Action Panel
        static let quickActionPanelWidth: CGFloat = 250
        static let quickActionPanelHeight: CGFloat = 200
        static let quickActionPanelPadding: CGFloat = 16

        // Settings Window
        static let settingsWindowWidth: CGFloat = 500
        static let settingsWindowHeight: CGFloat = 400
        static let settingsWindowMinWidth: CGFloat = 450
        static let settingsWindowMinHeight: CGFloat = 350

        // Animation
        static let defaultAnimationDuration = 0.3
        static let quickAnimationDuration = 0.15
        static let slowAnimationDuration = 0.5
    }

    // MARK: - Timing Constants

    enum Timing {
        /// 用户操作检测阈值（毫秒）
        static let userActionThreshold: TimeInterval = 0.5

        /// 输入法切换延迟（毫秒）
        static let inputSwitchDelay: TimeInterval = 0.1

        /// 权限检查间隔（秒）
        static let permissionCheckInterval: TimeInterval = 1.0

        /// 权限检查最大次数
        static let maxPermissionChecks = 30

        /// 通知显示时间（秒）
        static let notificationDuration: TimeInterval = 3.0

        /// 状态更新间隔（秒）
        static let statusUpdateInterval: TimeInterval = 0.5
    }

    // MARK: - System Constants

    enum System {
        /// 最低支持的 macOS 版本
        static let minimumMacOSVersion = "12.0"

        /// 辅助功能权限标识
        static let accessibilityPermissionKey = "com.apple.preference.security?Privacy_Accessibility"

        /// 登录项标识
        static let loginItemIdentifier = "com.typelock.macos.helper"
    }

    // MARK: - Input Source Constants

    enum InputSource {
        /// 常见输入法 Bundle ID
        enum BundleIds {
            static let appleABC = "com.apple.keylayout.ABC"
            static let appleSimplifiedChinese = "com.apple.inputmethod.SCIM.ITABC"
            static let appleTraditionalChinese = "com.apple.inputmethod.TCIM.Cangjie"
            static let appleJapanese = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"
            static let sogouPinyin = "com.sogou.inputmethod.sogou"
            static let baiduPinyin = "com.baidu.inputmethod.BaiduIM"
        }

        /// 输入法类别
        enum Categories {
            static let keyboardLayout = "TISCategoryKeyboardInputSource"
            static let inputMethod = "TISCategoryInputMethodSource"
            static let paletteInputMethod = "TISCategoryPaletteInputSource"
        }
    }

    // MARK: - File Paths

    enum Paths {
        /// 应用支持目录
        static let applicationSupport = "~/Library/Application Support/Typelock"

        /// 日志文件目录
        static let logs = "~/Library/Logs/Typelock"

        /// 配置文件目录
        static let preferences = "~/Library/Preferences"

        /// 缓存目录
        static let caches = "~/Library/Caches/Typelock"
    }

    // MARK: - URLs

    enum URLs {
        static let homepage = "https://typelock.app"
        static let support = "https://typelock.app/support"
        static let privacy = "https://typelock.app/privacy"
        static let github = "https://github.com/typelock/typelock-macos"
        static let releases = "https://github.com/typelock/typelock-macos/releases"

        /// 系统偏好设置 URL
        static let systemPreferences = "x-apple.systempreferences:"
        static let accessibilitySettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        static let loginItemsSettings = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    }

    // MARK: - Error Codes

    enum ErrorCodes {
        static let permissionDenied = 1_001
        static let inputSourceNotFound = 1_002
        static let switchFailed = 1_003
        static let configurationError = 1_004
        static let systemError = 1_005
    }

    // MARK: - Performance Limits

    enum Performance {
        /// 最大内存使用量（MB）
        static let maxMemoryUsage: Double = 50

        /// 最大 CPU 使用率（%）
        static let maxCPUUsage: Double = 5

        /// 最大日志文件大小（MB）
        static let maxLogFileSize: Double = 10

        /// 最大缓存大小（MB）
        static let maxCacheSize: Double = 20
    }

    // MARK: - Debug Constants

    enum Debug {
        /// 是否启用详细日志
        static let verboseLogging = false

        /// 是否启用性能监控
        static let performanceMonitoring = false

        /// 是否启用内存监控
        static let memoryMonitoring = false

        /// 调试信息显示时间（秒）
        static let debugInfoDuration: TimeInterval = 5.0
    }
}

// MARK: - Computed Properties

extension Constants {
    /// 获取应用版本信息字符串
    static var versionString: String {
        "\(App.name) \(App.version) (\(App.build))"
    }

    /// 获取完整的应用标识符
    static var fullBundleIdentifier: String {
        App.bundleId
    }

    /// 获取应用支持目录的完整路径
    static var applicationSupportPath: String {
        NSString(string: Paths.applicationSupport).expandingTildeInPath
    }

    /// 获取日志目录的完整路径
    static var logsPath: String {
        NSString(string: Paths.logs).expandingTildeInPath
    }
}
