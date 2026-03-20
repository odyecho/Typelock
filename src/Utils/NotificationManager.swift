import Cocoa
import UserNotifications

/// 通知管理器
/// 负责显示各种系统通知和用户反馈
class NotificationManager: NSObject {

    // MARK: - Properties

    private var settings: SettingsModel
    private var logger = Logger.shared
    private var notificationCenter: UNUserNotificationCenter

    /// 是否已请求通知权限
    private var hasRequestedPermission = false

    // MARK: - Initialization

    init(settings: SettingsModel) {
        self.settings = settings
        notificationCenter = UNUserNotificationCenter.current()

        super.init()

        setupNotificationCenter()
        requestNotificationPermission()
    }

    // MARK: - Public Methods

    /// 显示启动完成通知
    func showStartupNotification() {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "Typelock 已启动"
        content.body = "输入法锁定功能已准备就绪"
        content.sound = .default

        showNotification(content, identifier: "startup")
    }

    /// 显示输入法变化通知
    func showInputSourceChanged(_ inputSource: InputSourceModel) {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "输入法已切换"
        content.body = "当前输入法: \(inputSource.name)"
        content.sound = nil

        showNotification(content, identifier: "inputSourceChanged", delay: 0.5)
    }

    /// 显示输入法锁定通知
    func showInputSourceLocked(_ inputSource: InputSourceModel) {
        guard settings.showNotifications, settings.notifyOnLock else { return }

        let content = UNMutableNotificationContent()
        content.title = "输入法已锁定"
        content.body = "锁定到: \(inputSource.name)"
        content.sound = .default

        showNotification(content, identifier: "inputSourceLocked")
    }

    /// 显示输入法解锁通知
    func showInputSourceUnlocked() {
        guard settings.showNotifications, settings.notifyOnUnlock else { return }

        let content = UNMutableNotificationContent()
        content.title = "输入法已解锁"
        content.body = "输入法锁定已关闭"
        content.sound = .default

        showNotification(content, identifier: "inputSourceUnlocked")
    }

    /// 显示输入法恢复通知
    func showInputSourceRestored(_ inputSource: InputSourceModel) {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "输入法已恢复"
        content.body = "已恢复到: \(inputSource.name)"
        content.sound = nil

        showNotification(content, identifier: "inputSourceRestored", delay: 0.3)
    }

    /// 显示应用白名单通知
    func showAppWhitelistChanged(_ appName: String, added: Bool) {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = added ? "应用已添加到白名单" : "应用已从白名单移除"
        content.body = appName
        content.sound = .default

        showNotification(content, identifier: "appWhitelistChanged")
    }

    /// 显示错误通知
    func showError(_ title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .defaultCritical

        showNotification(content, identifier: "error")
    }

    /// 显示警告通知
    func showWarning(_ title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        showNotification(content, identifier: "warning")
    }

    /// 显示权限请求通知
    func showPermissionRequired() {
        let content = UNMutableNotificationContent()
        content.title = "需要辅助功能权限"
        content.body = "请在系统偏好设置中授予 Typelock 辅助功能权限"
        content.sound = .defaultCritical

        // 添加操作按钮
        let openSettingsAction = UNNotificationAction(
            identifier: "openSettings",
            title: "打开设置",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: "permissionRequired",
            actions: [openSettingsAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
        content.categoryIdentifier = "permissionRequired"

        showNotification(content, identifier: "permissionRequired")
    }

    /// 显示性能警告
    func showPerformanceWarning(_ message: String) {
        guard settings.enablePerformanceMonitoring else { return }

        let content = UNMutableNotificationContent()
        content.title = "性能警告"
        content.body = message
        content.sound = .default

        showNotification(content, identifier: "performanceWarning")
    }

    // MARK: - Private Methods

    /// 设置通知中心
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
    }

    /// 请求通知权限
    private func requestNotificationPermission() {
        guard !hasRequestedPermission else { return }

        hasRequestedPermission = true

        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error {
                    self?.logger.error("请求通知权限失败: \(error)", category: "Notification")
                } else if granted {
                    self?.logger.info("通知权限已授予", category: "Notification")
                } else {
                    self?.logger.warning("通知权限被拒绝", category: "Notification")
                }
            }
        }
    }

    /// 显示通知
    private func showNotification(_ content: UNMutableNotificationContent, identifier: String,
                                  delay: TimeInterval = 0) {
        // 移除之前的同类通知
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])

        // 创建通知请求
        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // 添加通知
        notificationCenter.add(request) { [weak self] error in
            if let error {
                self?.logger.error("显示通知失败: \(error)", category: "Notification")
            } else {
                self?.logger.debug("通知已显示: \(identifier)", category: "Notification")
            }
        }

        // 设置自动移除定时器
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.notificationDuration + delay) {
            self.notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 应用在前台时是否显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台也显示通知
        completionHandler([.alert, .sound])
    }

    /// 处理通知点击
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier

        logger.info("通知交互: \(identifier), 操作: \(actionIdentifier)", category: "Notification")

        switch actionIdentifier {
        case "openSettings":
            if identifier == "permissionRequired" {
                // 打开系统偏好设置
                if let url = URL(string: Constants.URLs.accessibilitySettings) {
                    NSWorkspace.shared.open(url)
                }
            }

        case UNNotificationDefaultActionIdentifier:
            // 默认点击操作
            handleDefaultNotificationAction(identifier: identifier)

        default:
            break
        }

        completionHandler()
    }

    /// 处理默认通知操作
    private func handleDefaultNotificationAction(identifier: String) {
        switch identifier {
        case "startup", "inputSourceLocked", "inputSourceUnlocked":
            // 显示快速操作面板
            // 这里需要通过通知或回调来触发状态栏控制器
            NotificationCenter.default.post(name: .showQuickActions, object: nil)

        case "error", "warning":
            // 显示设置窗口
            NotificationCenter.default.post(name: .showSettings, object: nil)

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showQuickActions = Notification.Name("ShowQuickActions")
    static let showSettings = Notification.Name("ShowSettings")
}
