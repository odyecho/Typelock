import ApplicationServices
import Cocoa

class PermissionManager {
    private let logger = Logger.shared
    private var hasShownAccessibilityPrompt = false

    /// 检查并请求必要的权限
    /// - Parameter completion: 权限检查完成后的回调，参数表示是否已获得所有必要权限
    func checkAndRequestPermissions(completion: @escaping (Bool) -> Void) {
        // 检查辅助功能权限
        checkAccessibilityPermission { hasPermission in
            completion(hasPermission)
        }
    }

    /// 检查辅助功能权限
    /// - Parameter completion: 权限检查完成后的回调
    private func checkAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        if currentAccessibilityTrustStatus() {
            completion(true)
        } else {
            startPermissionMonitoring(checkInterval: 0.5, maxChecks: 6) { [weak self] trusted in
                guard let self else {
                    completion(false)
                    return
                }

                if trusted {
                    completion(true)
                } else {
                    self.requestAccessibilityPermission(completion: completion)
                }
            }
        }
    }

    /// 请求辅助功能权限
    /// - Parameter completion: 权限请求完成后的回调
    private func requestAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        let shouldPrompt = !hasShownAccessibilityPrompt
        if shouldPrompt {
            hasShownAccessibilityPrompt = true
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): shouldPrompt] as CFDictionary

        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            completion(true)
        } else {
            startPermissionMonitoring(completion: completion)
        }
    }

    private func startPermissionMonitoring(
        checkInterval: TimeInterval = 1.0,
        maxChecks: Int = 30,
        completion: @escaping (Bool) -> Void
    ) {
        var checkCount = 0

        let timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] timer in
            checkCount += 1

            let trusted = self?.currentAccessibilityTrustStatus() ?? false
            if trusted {
                timer.invalidate()
                completion(true)
            } else if checkCount >= maxChecks {
                timer.invalidate()
                completion(false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// 检查当前是否有辅助功能权限
    /// - Returns: 是否有权限
    func hasAccessibilityPermission() -> Bool {
        currentAccessibilityTrustStatus()
    }

    private func currentAccessibilityTrustStatus() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 打开系统偏好设置的辅助功能页面
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            logger.error("辅助功能设置 URL 无效", category: "Permission")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// 显示权限说明对话框
    /// - Returns: 用户的选择（true: 打开设置，false: 取消）
    func showPermissionDialog() -> Bool {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Typelock 需要辅助功能权限来监控输入法状态和实现锁定功能。

        请按照以下步骤授予权限：
        1. 点击"打开系统偏好设置"
        2. 在"隐私与安全性"中找到"辅助功能"
        3. 点击锁图标并输入密码
        4. 勾选 Typelock 应用
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后设置")
        alert.addButton(withTitle: "退出应用")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            openAccessibilitySettings()
            return true
        case .alertSecondButtonReturn:
            return false
        default:
            NSApp.terminate(nil)
            return false
        }
    }
}
