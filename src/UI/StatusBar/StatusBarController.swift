import Cocoa
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var inputSourceManager: InputSourceManager?

    override init() {
        super.init()
        inputSourceManager = InputSourceManager()
    }

    func setupStatusBar() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let statusItem else { return }

        // 配置状态栏按钮
        if let button = statusItem.button {
            // 设置初始图标
            updateStatusBarIcon(isLocked: false)

            // 设置点击事件
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 监听输入法状态变化
        setupInputSourceMonitoring()
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 右键点击：显示上下文菜单
            showContextMenu()
        } else {
            // 左键点击：显示快速操作面板
            showQuickActions()
        }
    }

    private func showQuickActions() {
        guard let button = statusItem?.button else { return }

        if popover == nil {
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: QuickActionView())
            popover?.behavior = .transient
            popover?.delegate = self
        }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()

        // 当前输入法状态
        let currentInputSource = inputSourceManager?.getCurrentInputSource()
        let statusItem = NSMenuItem(title: "当前输入法: \(currentInputSource?.name ?? "未知")", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 锁定/解锁切换
        let lockAction = inputSourceManager?.isLocked == true ? "解锁输入法" : "锁定输入法"
        menu.addItem(NSMenuItem(title: lockAction, action: #selector(toggleLock), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 设置
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(title: "退出 Typelock", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLock() {
        inputSourceManager?.toggleLock()
        updateStatusBarIcon(isLocked: inputSourceManager?.isLocked ?? false)
    }

    @objc private func showSettings() {
        // 后续接入设置窗口
        Logger.shared.info("显示设置窗口", category: "StatusBar")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupInputSourceMonitoring() {
        // 监听输入法状态变化
        self.inputSourceManager?.onInputSourceChanged = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon(isLocked: self?.inputSourceManager?.isLocked ?? false)
            }
        }

        self.inputSourceManager?.onLockStateChanged = { [weak self] isLocked in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon(isLocked: isLocked)
            }
        }
    }

    private func updateStatusBarIcon(isLocked: Bool) {
        guard let button = statusItem?.button else { return }

        // 根据锁定状态更新图标
        let iconName = isLocked ? "lock.fill" : "keyboard"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: isLocked ? "输入法已锁定" : "输入法未锁定")

        // 设置图标属性
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
    }

    func cleanup() {
        statusItem = nil
        popover = nil
        inputSourceManager?.cleanup()
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // 弹出窗口关闭时的处理
    }
}
