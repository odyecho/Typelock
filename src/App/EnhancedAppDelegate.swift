import Cocoa
import SwiftUI

/// 增强版应用委托
/// 集成所有核心功能和增强特性
@MainActor
class EnhancedAppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Core Components

    private var settings: SettingsModel!
    private var permissionManager: PermissionManager!
    private var inputSourceManager: EnhancedInputSourceManager!
    private var appStateManager: AppStateManager!
    private var statusBarController: UltimateStatusBarController!
    private var notificationManager: NotificationManager!
    private var performanceMonitor: PerformanceMonitor!

    private var logger = Logger.shared
    private var isSetupComplete = false

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("应用启动开始", category: "App")

        // 初始化核心组件
        initializeCoreComponents()

        // 检查并请求权限
        checkPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.completeSetup()
                } else {
                    self?.handlePermissionDenied()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("应用即将退出", category: "App")
        cleanup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 状态栏应用不需要重新打开窗口，但可以显示设置
        if !flag {
            statusBarController?.showSettings()
        }
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 应用激活时检查权限状态
        if isSetupComplete, !permissionManager.hasAccessibilityPermission() {
            logger.warning("应用激活时发现权限丢失", category: "App")
            handlePermissionLost()
        }
    }

    // MARK: - Initialization

    /// 初始化核心组件
    private func initializeCoreComponents() {
        logger.info("初始化核心组件", category: "App")

        // 设置管理器
        settings = SettingsModel()
        logger.logLevel = settings.logLevel

        // 权限管理器
        permissionManager = PermissionManager()

        // 应用状态管理器
        appStateManager = AppStateManager(settings: settings)

        // 输入法管理器
        inputSourceManager = EnhancedInputSourceManager(settings: settings)

        // 通知管理器
        notificationManager = NotificationManager(settings: settings)

        // 性能监控器
        if settings.enablePerformanceMonitoring {
            performanceMonitor = PerformanceMonitor()
        }

        logger.info("核心组件初始化完成", category: "App")
    }

    /// 检查权限
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        logger.info("检查应用权限", category: "App")

        permissionManager.checkAndRequestPermissions { [weak self] granted in
            if granted {
                self?.logger.info("权限检查通过", category: "App")
            } else {
                self?.logger.warning("权限检查失败", category: "App")
            }
            completion(granted)
        }
    }

    /// 完成应用设置
    private func completeSetup() {
        logger.info("完成应用设置", category: "App")

        // 设置应用策略为辅助应用（不显示在 Dock）
        NSApp.setActivationPolicy(.accessory)

        // 创建状态栏控制器
        statusBarController = UltimateStatusBarController(
            inputSourceManager: inputSourceManager,
            appStateManager: appStateManager,
            settings: settings
        )

        // 设置状态栏
        statusBarController.setupStatusBar()

        // 启动监控
        startMonitoring()

        // 设置通知
        setupNotifications()

        // 启动性能监控
        if let performanceMonitor {
            performanceMonitor.startMonitoring()
        }

        // 应用默认锁定状态
        if settings.defaultLockState {
            inputSourceManager.lockToCurrent()
            logger.info("应用默认锁定状态", category: "App")
        }

        isSetupComplete = true
        logger.info("应用设置完成", category: "App")

        // 发送启动完成通知
        if settings.showNotifications {
            notificationManager.showStartupNotification()
        }
    }

    /// 启动监控
    private func startMonitoring() {
        logger.info("启动系统监控", category: "App")

        inputSourceManager.startMonitoring()
        appStateManager.startMonitoring()

        logger.info("系统监控启动完成", category: "App")
    }

    /// 设置通知
    private func setupNotifications() {
        // 监听输入法变化
        self.inputSourceManager.onInputSourceChanged = { [weak self] inputSource in
            self?.handleInputSourceChanged(inputSource)
        }

        // 监听锁定状态变化
        self.inputSourceManager.onLockStateChanged = { [weak self] isLocked in
            self?.handleLockStateChanged(isLocked)
        }

        // 监听输入法切换失败
        inputSourceManager.onSwitchFailed = { [weak self] inputSource, error in
            self?.handleInputSourceSwitchFailed(inputSource, error: error)
        }

        // 监听应用切换
        appStateManager.onAppChanged = { [weak self] appInfo in
            self?.handleAppChanged(appInfo)
        }

        logger.info("通知设置完成", category: "App")
    }

    // MARK: - Event Handlers

    /// 处理输入法变化
    private func handleInputSourceChanged(_ inputSource: InputSourceModel) {
        logger.inputSource("输入法变化: \(inputSource.name)")

        // 更新状态栏
        statusBarController?.updateStatusBar()

        // 显示通知（如果启用）
        if settings.showNotifications, !inputSourceManager.isLocked {
            notificationManager.showInputSourceChanged(inputSource)
        }
    }

    /// 处理锁定状态变化
    private func handleLockStateChanged(_ isLocked: Bool) {
        logger.lockEngine("锁定状态变化: \(isLocked)")

        // 更新状态栏
        statusBarController?.updateStatusBar()

        // 显示通知
        if settings.showNotifications {
            if isLocked, settings.notifyOnLock {
                if let lockedInputSource = inputSourceManager.lockedInputSource {
                    notificationManager.showInputSourceLocked(lockedInputSource)
                }
            } else if !isLocked, settings.notifyOnUnlock {
                notificationManager.showInputSourceUnlocked()
            }
        }
    }

    /// 处理输入法切换失败
    private func handleInputSourceSwitchFailed(_ inputSource: InputSourceModel, error: Error) {
        logger.error("输入法切换失败: \(inputSource.name), 错误: \(error.localizedDescription)", category: "InputSource")

        // 显示错误通知
        if settings.showNotifications {
            notificationManager.showError("输入法切换失败", message: error.localizedDescription)
        }
    }

    /// 处理应用切换
    private func handleAppChanged(_ appInfo: AppInfo) {
        logger.debug("应用切换: \(appInfo.localizedName)", category: "App")

        // 更新状态栏
        statusBarController?.updateStatusBar()
    }

    /// 处理权限被拒绝
    private func handlePermissionDenied() {
        logger.error("权限被拒绝，应用无法正常工作", category: "App")

        let shouldOpenSettings = permissionManager.showPermissionDialog()

        if shouldOpenSettings {
            // 启动定时器检查权限状态
            startPermissionCheckTimer()
        } else {
            // 用户选择退出
            NSApp.terminate(nil)
        }
    }

    /// 处理权限丢失
    private func handlePermissionLost() {
        logger.warning("检测到权限丢失", category: "App")

        // 停止监控
        inputSourceManager.stopMonitoring()
        appStateManager.stopMonitoring()

        // 显示权限丢失通知
        if settings.showNotifications {
            notificationManager.showError("权限丢失", message: "请重新授予辅助功能权限")
        }

        // 重新检查权限
        checkPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startMonitoring()
                    self?.logger.info("权限恢复，重新启动监控", category: "App")
                }
            }
        }
    }

    /// 启动权限检查定时器
    private func startPermissionCheckTimer() {
        var checkCount = 0
        let maxChecks = 60 // 最多检查60次（60秒）

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            checkCount += 1

            if self?.permissionManager.hasAccessibilityPermission() == true {
                timer.invalidate()
                self?.completeSetup()
            } else if checkCount >= maxChecks {
                timer.invalidate()
                NSApp.terminate(nil)
            }
        }

        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Cleanup

    /// 清理资源
    private func cleanup() {
        logger.info("开始清理应用资源", category: "App")

        // 停止监控
        inputSourceManager?.stopMonitoring()
        appStateManager?.stopMonitoring()
        performanceMonitor?.stopMonitoring()

        // 清理组件
        statusBarController?.cleanup()
        inputSourceManager?.cleanup()
        appStateManager?.cleanup()

        // 保存设置
        settings?.saveSettings()

        logger.info("应用资源清理完成", category: "App")
    }
}

// MARK: - Menu Validation

extension EnhancedAppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // 根据当前状态验证菜单项
        switch menuItem.action {
        case #selector(toggleLock):
            return isSetupComplete && permissionManager.hasAccessibilityPermission()
        case #selector(showSettings):
            return isSetupComplete
        default:
            return true
        }
    }

    @objc private func toggleLock() {
        inputSourceManager?.toggleLock()
    }

    @objc private func showSettings() {
        statusBarController?.showSettings()
    }
}
