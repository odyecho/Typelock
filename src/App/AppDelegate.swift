import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var permissionManager: PermissionManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化权限管理器
        permissionManager = PermissionManager()

        // 检查并请求必要权限
        permissionManager?.checkAndRequestPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupApplication()
                } else {
                    self?.showPermissionAlert()
                }
            }
        }
    }

    private func setupApplication() {
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        statusBarController?.setupStatusBar()

        // 隐藏 Dock 图标（通过 LSUIElement 配置）
        NSApp.setActivationPolicy(.accessory)
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "Typelock 需要辅助功能权限来监控输入法状态。请在系统偏好设置中授予权限。"
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "退出")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统偏好设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        // 退出应用
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        statusBarController?.cleanup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 状态栏应用不需要重新打开窗口
        false
    }
}
