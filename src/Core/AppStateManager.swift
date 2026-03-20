import Cocoa
import Foundation

/// 应用状态管理器
/// 负责监控当前活跃应用和管理应用白名单
class AppStateManager: ObservableObject {

    // MARK: - Properties

    @Published var currentApp: AppInfo?
    @Published var isCurrentAppWhitelisted = false

    private var workspace: NSWorkspace
    private var logger = Logger.shared
    private var settings: SettingsModel

    /// 应用切换回调
    var onAppChanged: ((AppInfo) -> Void)?

    // MARK: - Initialization

    init(settings: SettingsModel) {
        workspace = NSWorkspace.shared
        self.settings = settings
        setupAppMonitoring()
        updateCurrentApp()
    }

    // MARK: - Public Methods

    /// 开始监控应用切换
    func startMonitoring() {
        logger.info("开始监控应用切换", category: "AppState")
        // 监控已在 init 中设置
    }

    /// 停止监控应用切换
    func stopMonitoring() {
        logger.info("停止监控应用切换", category: "AppState")
        workspace.notificationCenter.removeObserver(self)
    }

    /// 获取当前活跃应用信息
    func getCurrentApp() -> AppInfo? {
        guard let frontmostApp = workspace.frontmostApplication else {
            return nil
        }

        return AppInfo(
            bundleIdentifier: frontmostApp.bundleIdentifier ?? "unknown",
            localizedName: frontmostApp.localizedName ?? "Unknown App",
            processIdentifier: frontmostApp.processIdentifier,
            isActive: true
        )
    }

    /// 检查指定应用是否在白名单中
    func isAppWhitelisted(_ bundleId: String) -> Bool {
        settings.isInWhitelist(bundleId)
    }

    /// 添加当前应用到白名单
    func addCurrentAppToWhitelist() {
        guard let currentApp else { return }
        settings.addToWhitelist(currentApp.bundleIdentifier)
        updateWhitelistStatus()
        logger.info("添加应用到白名单: \(currentApp.localizedName)", category: "AppState")
    }

    /// 从白名单移除当前应用
    func removeCurrentAppFromWhitelist() {
        guard let currentApp else { return }
        settings.removeFromWhitelist(currentApp.bundleIdentifier)
        updateWhitelistStatus()
        logger.info("从白名单移除应用: \(currentApp.localizedName)", category: "AppState")
    }

    /// 获取所有运行中的应用
    func getRunningApps() -> [AppInfo] {
        workspace.runningApplications
            .filter { !$0.isTerminated }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      !bundleId.isEmpty,
                      bundleId != "com.typelock.macos" else { return nil }

                return AppInfo(
                    bundleIdentifier: bundleId,
                    localizedName: app.localizedName ?? "Unknown",
                    processIdentifier: app.processIdentifier,
                    isActive: app == workspace.frontmostApplication
                )
            }
            .sorted { $0.localizedName < $1.localizedName }
    }

    /// 清理资源
    func cleanup() {
        stopMonitoring()
    }

    // MARK: - Private Methods

    /// 设置应用监控
    private func setupAppMonitoring() {
        // 监控应用激活事件
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // 监控应用终止事件
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // 监控应用启动事件
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }

    /// 更新当前应用信息
    private func updateCurrentApp() {
        let newApp = getCurrentApp()

        if let newApp, newApp.bundleIdentifier != currentApp?.bundleIdentifier {
            currentApp = newApp
            updateWhitelistStatus()

            logger.info("应用切换到: \(newApp.localizedName) (\(newApp.bundleIdentifier))", category: "AppState")

            // 通知回调
            onAppChanged?(newApp)
        }
    }

    /// 更新白名单状态
    private func updateWhitelistStatus() {
        guard let currentApp else {
            isCurrentAppWhitelisted = false
            return
        }

        isCurrentAppWhitelisted = settings.isInWhitelist(currentApp.bundleIdentifier)
    }

    // MARK: - Notification Handlers

    @objc private func appDidActivate(_ notification: Notification) {
        updateCurrentApp()
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        logger.debug("应用终止: \(app.localizedName ?? "Unknown")", category: "AppState")
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        logger.debug("应用启动: \(app.localizedName ?? "Unknown")", category: "AppState")
    }
}

// MARK: - AppInfo Model

struct AppInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
    let isActive: Bool

    /// 应用图标
    var icon: NSImage? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) else {
            return nil
        }
        return app.icon
    }

    /// 是否是系统应用
    var isSystemApp: Bool {
        bundleIdentifier.hasPrefix("com.apple.") ||
            bundleIdentifier.contains("SystemUIServer") ||
            bundleIdentifier.contains("Finder")
    }

    /// 应用类型描述
    var typeDescription: String {
        if isSystemApp {
            return "系统应用"
        } else if bundleIdentifier.contains("com.apple.dt.Xcode") {
            return "开发工具"
        } else if bundleIdentifier.contains("browser") ||
            bundleIdentifier.contains("safari") ||
            bundleIdentifier.contains("chrome") ||
            bundleIdentifier.contains("firefox") {
            return "浏览器"
        } else {
            return "第三方应用"
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

// MARK: - AppInfo Extensions

extension AppInfo: CustomStringConvertible {
    var description: String {
        "AppInfo(name: \(localizedName), bundleId: \(bundleIdentifier), active: \(isActive))"
    }
}
