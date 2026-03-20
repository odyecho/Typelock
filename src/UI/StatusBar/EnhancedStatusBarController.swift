import Cocoa
import SwiftUI

/// 增强版状态栏控制器
/// 提供更丰富的状态栏交互和视觉反馈
@MainActor
class EnhancedStatusBarController: NSObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var quickActionPopover: NSPopover?
    private var settingsWindow: NSWindow?

    private var inputSourceManager: EnhancedInputSourceManager
    private var appStateManager: AppStateManager
    private var settings: SettingsModel
    private var logger = Logger.shared

    // 状态栏图标状态
    private var currentIconState: IconState = .unlocked
    private var isAnimating = false

    // MARK: - Initialization

    init(inputSourceManager: EnhancedInputSourceManager, appStateManager: AppStateManager, settings: SettingsModel) {
        self.inputSourceManager = inputSourceManager
        self.appStateManager = appStateManager
        self.settings = settings

        super.init()

        setupCallbacks()
    }

    // MARK: - Public Methods

    /// 设置状态栏
    func setupStatusBar() {
        guard settings.showStatusBarIcon else {
            logger.info("状态栏图标已禁用", category: "StatusBar")
            return
        }

        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let statusItem else {
            logger.error("创建状态栏项目失败", category: "StatusBar")
            return
        }

        // 配置状态栏按钮
        if let button = statusItem.button {
            // 设置初始图标
            updateStatusBarIcon()

            // 设置点击事件
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // 设置工具提示
            updateToolTip()

            logger.info("状态栏设置完成", category: "StatusBar")
        }
    }

    /// 显示设置窗口
    func showSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logger.info("显示设置窗口", category: "StatusBar")
    }

    /// 隐藏所有弹出窗口
    func hideAllPopovers() {
        quickActionPopover?.performClose(nil)
    }

    /// 更新状态栏显示
    func updateStatusBar() {
        updateStatusBarIcon()
        updateToolTip()
    }

    /// 清理资源
    func cleanup() {
        statusItem = nil
        quickActionPopover = nil
        settingsWindow?.close()
        settingsWindow = nil

        logger.info("状态栏控制器清理完成", category: "StatusBar")
    }

    // MARK: - Private Methods

    /// 设置回调
    private func setupCallbacks() {
        // 监听输入法状态变化
        self.inputSourceManager.onInputSourceChanged = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusBar()
            }
        }

        // 监听锁定状态变化
        self.inputSourceManager.onLockStateChanged = { [weak self] isLocked in
            DispatchQueue.main.async {
                self?.handleLockStateChanged(isLocked)
            }
        }

        // 监听应用切换
        appStateManager.onAppChanged = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusBar()
            }
        }

        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    /// 状态栏按钮点击处理
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        logger.debug("状态栏按钮点击: \(event.type.rawValue)", category: "StatusBar")

        if event.type == .rightMouseUp {
            // 右键点击：显示上下文菜单
            showContextMenu()
        } else {
            // 左键点击：显示快速操作面板
            showQuickActions()
        }
    }

    /// 显示快速操作面板
    private func showQuickActions() {
        guard let button = statusItem?.button else { return }

        if quickActionPopover == nil {
            createQuickActionPopover()
        }

        if quickActionPopover?.isShown == true {
            quickActionPopover?.performClose(nil)
        } else {
            quickActionPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            logger.debug("显示快速操作面板", category: "StatusBar")
        }
    }

    /// 创建快速操作弹出窗口
    private func createQuickActionPopover() {
        quickActionPopover = NSPopover()
        quickActionPopover?.contentViewController = NSHostingController(
            rootView: EnhancedQuickActionView(
                inputSourceManager: inputSourceManager,
                appStateManager: appStateManager,
                settings: settings
            ) { [weak self] in
                self?.quickActionPopover?.performClose(nil)
                self?.showSettings()
            }
        )
        quickActionPopover?.behavior = .transient
        quickActionPopover?.delegate = self
    }

    /// 显示上下文菜单
    private func showContextMenu() {
        guard let statusItem else { return }

        let menu = createContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil

        logger.debug("显示上下文菜单", category: "StatusBar")
    }

    /// 创建上下文菜单
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()

        // 当前状态信息
        let currentInputSource = inputSourceManager.currentInputSource
        let statusTitle = "当前输入法: \(currentInputSource?.name ?? "未知")"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let lockStatus = inputSourceManager.isLocked ? "已锁定" : "未锁定"
        let lockStatusItem = NSMenuItem(title: "状态: \(lockStatus)", action: nil, keyEquivalent: "")
        lockStatusItem.isEnabled = false
        menu.addItem(lockStatusItem)

        menu.addItem(NSMenuItem.separator())

        // 锁定/解锁操作
        let lockAction = inputSourceManager.isLocked ? "解锁输入法" : "锁定到当前输入法"
        let lockMenuItem = NSMenuItem(title: lockAction, action: #selector(toggleLock), keyEquivalent: "")
        lockMenuItem.target = self
        menu.addItem(lockMenuItem)

        // 如果已锁定，显示锁定的输入法
        if let lockedInputSource = inputSourceManager.lockedInputSource {
            let lockedItem = NSMenuItem(title: "锁定到: \(lockedInputSource.name)", action: nil, keyEquivalent: "")
            lockedItem.isEnabled = false
            menu.addItem(lockedItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 快速切换输入法
        let availableInputSources = inputSourceManager.availableInputSources.prefix(5)
        if !availableInputSources.isEmpty {
            let switchSubmenu = NSMenu()
            for inputSource in availableInputSources {
                let item = NSMenuItem(
                    title: inputSource.name,
                    action: #selector(switchToInputSource(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = inputSource
                item.state = inputSource.id == currentInputSource?.id ? .on : .off
                switchSubmenu.addItem(item)
            }

            let switchMenuItem = NSMenuItem(title: "切换输入法", action: nil, keyEquivalent: "")
            switchMenuItem.submenu = switchSubmenu
            menu.addItem(switchMenuItem)

            menu.addItem(NSMenuItem.separator())
        }

        // 应用白名单
        if let currentApp = appStateManager.currentApp {
            let whitelistAction = appStateManager.isCurrentAppWhitelisted ? "从白名单移除" : "添加到白名单"
            let whitelistItem = NSMenuItem(
                title: "\(whitelistAction) \(currentApp.localizedName)",
                action: #selector(toggleCurrentAppWhitelist),
                keyEquivalent: ""
            )
            whitelistItem.target = self
            menu.addItem(whitelistItem)

            menu.addItem(NSMenuItem.separator())
        }

        // 设置和退出
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "关于 Typelock", action: #selector(showAbout), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "退出 Typelock", action: #selector(quitApp), keyEquivalent: "q"))

        // 设置目标
        for item in menu.items where item.target == nil {
            item.target = self
        }

        return menu
    }

    /// 更新状态栏图标
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        let newState = determineIconState()

        // 如果状态没有变化且不在动画中，不需要更新
        if newState == currentIconState, !isAnimating {
            return
        }

        currentIconState = newState

        // 获取图标
        let (iconName, color) = getIconNameAndColor(for: newState)

        // 创建图标
        if let image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: getAccessibilityDescription(for: newState)
        ) {
            // 设置图标属性
            image.isTemplate = (color == nil)

            // 如果有指定颜色，创建带颜色的图标
            if let color {
                button.image = image.tinted(with: color)
            } else {
                button.image = image
            }

            button.imagePosition = .imageOnly

            logger.debug("更新状态栏图标: \(iconName), 状态: \(newState)", category: "StatusBar")
        }
    }

    /// 确定图标状态
    private func determineIconState() -> IconState {
        if !inputSourceManager.isMonitoring {
            return .disabled
        }

        if inputSourceManager.isLocked {
            if appStateManager.isCurrentAppWhitelisted {
                return .lockedPaused
            } else {
                return .locked
            }
        } else {
            return .unlocked
        }
    }

    /// 获取图标名称和颜色
    private func getIconNameAndColor(for state: IconState) -> (String, NSColor?) {
        switch state {
        case .locked:
            return ("lock.fill", .systemRed)
        case .unlocked:
            return ("keyboard", nil)
        case .lockedPaused:
            return ("lock.slash", .systemOrange)
        case .disabled:
            return ("keyboard.badge.ellipsis", .systemGray)
        }
    }

    /// 获取无障碍描述
    private func getAccessibilityDescription(for state: IconState) -> String {
        switch state {
        case .locked:
            return "输入法已锁定"
        case .unlocked:
            return "输入法未锁定"
        case .lockedPaused:
            return "输入法锁定已暂停"
        case .disabled:
            return "输入法监控已禁用"
        }
    }

    /// 更新工具提示
    private func updateToolTip() {
        guard let button = statusItem?.button else { return }

        var tooltip = "Typelock"

        if let currentInputSource = inputSourceManager.currentInputSource {
            tooltip += "\n当前输入法: \(currentInputSource.name)"
        }

        if inputSourceManager.isLocked {
            if let lockedInputSource = inputSourceManager.lockedInputSource {
                tooltip += "\n已锁定到: \(lockedInputSource.name)"
            } else {
                tooltip += "\n状态: 已锁定"
            }
        } else {
            tooltip += "\n状态: 未锁定"
        }

        if appStateManager.isCurrentAppWhitelisted {
            tooltip += "\n当前应用在白名单中"
        }

        button.toolTip = tooltip
    }

    /// 处理锁定状态变化
    private func handleLockStateChanged(_ isLocked: Bool) {
        updateStatusBar()

        // 显示动画效果
        if settings.showNotifications {
            animateStatusBarIcon()
        }

        logger.info("锁定状态变化: \(isLocked)", category: "StatusBar")
    }

    /// 状态栏图标动画
    private func animateStatusBarIcon() {
        guard let button = statusItem?.button, !isAnimating else { return }

        isAnimating = true

        // 简单的缩放动画
        let originalTransform = button.layer?.transform ?? CATransform3DIdentity

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setCompletionBlock { [weak self] in
            self?.isAnimating = false
        }

        let scaleTransform = CATransform3DScale(originalTransform, 1.2, 1.2, 1.0)
        button.layer?.transform = scaleTransform

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            button.layer?.transform = originalTransform
        }

        CATransaction.commit()
    }

    /// 创建设置窗口
    private func createSettingsWindow() {
        let showStatusBarIconBinding = Binding(
            get: { self.settings.showStatusBarIcon },
            set: { self.settings.showStatusBarIcon = $0 }
        )
        let showNotificationsBinding = Binding(
            get: { self.settings.showNotifications },
            set: { self.settings.showNotifications = $0 }
        )
        let quickActionPanelWidthBinding = Binding(
            get: { self.settings.quickActionPanelWidth },
            set: { self.settings.quickActionPanelWidth = $0 }
        )
        let settingsView = VStack(alignment: .leading, spacing: 12) {
            Text("Typelock 设置")
                .font(.title2)
                .fontWeight(.semibold)
            Toggle("显示状态栏图标", isOn: showStatusBarIconBinding)
            Toggle("显示通知", isOn: showNotificationsBinding)
            HStack {
                Text("快速面板宽度")
                Slider(value: quickActionPanelWidthBinding, in: 200...400, step: 10)
                Text("\(Int(settings.quickActionPanelWidth))")
                    .frame(width: 40)
            }
            HStack {
                Spacer()
                Button("关闭") {
                    self.settingsWindow?.close()
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 260)

        let hostingController = NSHostingController(rootView: settingsView)
        settingsWindow = NSWindow(contentViewController: hostingController)

        settingsWindow?.title = "Typelock 设置"
        settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
        settingsWindow?.isReleasedWhenClosed = false
        settingsWindow?.center()
    }

    // MARK: - Menu Actions

    @objc private func toggleLock() {
        inputSourceManager.toggleLock()
    }

    @objc private func switchToInputSource(_ sender: NSMenuItem) {
        guard let inputSource = sender.representedObject as? InputSourceModel else { return }
        inputSourceManager.switchToInputSource(inputSource)
    }

    @objc private func toggleCurrentAppWhitelist() {
        if appStateManager.isCurrentAppWhitelisted {
            appStateManager.removeCurrentAppFromWhitelist()
        } else {
            appStateManager.addCurrentAppToWhitelist()
        }
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "关于 Typelock"
        alert.informativeText = """
        Typelock \(Constants.App.version)

        macOS 输入法锁定应用
        防止输入法自动切换，保持用户偏好的输入法状态

        \(Constants.App.copyright)
        """
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func settingsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBar()
        }
    }
}

// MARK: - NSPopoverDelegate

extension EnhancedStatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        logger.debug("快速操作面板已关闭", category: "StatusBar")
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        true
    }
}

// MARK: - IconState

private enum IconState: Equatable {
    case locked // 已锁定
    case unlocked // 未锁定
    case lockedPaused // 锁定但暂停（白名单应用）
    case disabled // 禁用状态
}
