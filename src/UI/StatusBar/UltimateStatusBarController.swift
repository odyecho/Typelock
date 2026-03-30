import Cocoa
import SwiftUI

/// 终极版状态栏控制器
/// 集成所有增强功能：动画、主题、快捷键、手势等
@MainActor
class UltimateStatusBarController: NSObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var quickActionPopover: NSPopover?
    private var settingsWindow: NSWindow?

    private var inputSourceManager: EnhancedInputSourceManager
    private var appStateManager: AppStateManager
    private var settings: SettingsModel
    private var hotKeyManager: HotKeyManager
    private var themeManager = ThemeManager.shared
    private var animationManager = AnimationManager.shared
    private var logger = Logger.shared

    // 状态和动画
    private var currentIconState: IconState = .unlocked
    private var isAnimating = false
    private var lastClickTime = Date()
    private var clickCount = 0

    // 手势识别
    private var panGestureRecognizer: NSPanGestureRecognizer?
    private var longPressTimer: Timer?

    // 全局鼠标事件监听器（用于点击面板外部自动关闭）
    private var outsideClickMonitor: Any?

    // MARK: - Initialization

    init(inputSourceManager: EnhancedInputSourceManager, appStateManager: AppStateManager, settings: SettingsModel) {
        self.inputSourceManager = inputSourceManager
        self.appStateManager = appStateManager
        self.settings = settings
        hotKeyManager = HotKeyManager()

        super.init()

        setupCallbacks()
        setupHotKeys()
        setupThemeObserver()
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
            setupStatusBarButton(button)
            updateStatusBarIcon()
            updateToolTip()

            logger.info("终极版状态栏设置完成", category: "StatusBar")
        }
    }

    /// 显示设置窗口
    func showSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }

        if let window = settingsWindow {
            animationManager.scaleInWindow(window)
            NSApp.activate(ignoringOtherApps: true)
        }

        logger.info("显示设置窗口", category: "StatusBar")
    }

    /// 显示快速操作面板
    func showQuickActions() {
        guard let button = statusItem?.button else { return }

        if quickActionPopover == nil {
            createQuickActionPopover()
        }

        if quickActionPopover?.isShown == true {
            hideQuickActionsWithAnimation()
        } else {
            showQuickActionsWithAnimation()
        }
    }

    /// 隐藏所有弹出窗口
    func hideAllPopovers() {
        hideQuickActionsWithAnimation()
    }

    /// 更新状态栏显示
    func updateStatusBar() {
        updateStatusBarIcon()
        updateToolTip()
    }

    /// 清理资源
    func cleanup() {
        hotKeyManager.cleanup()
        statusItem = nil
        quickActionPopover = nil
        settingsWindow?.close()
        settingsWindow = nil

        logger.info("终极版状态栏控制器清理完成", category: "StatusBar")
    }

    // MARK: - Private Setup Methods

    /// 设置状态栏按钮
    private func setupStatusBarButton(_ button: NSStatusBarButton) {
        // 基本设置
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // 启用图层动画
        button.wantsLayer = true
        button.layer?.cornerRadius = 4

        // 添加手势识别
        setupGestureRecognizers(for: button)

        // 添加鼠标跟踪
        setupMouseTracking(for: button)
    }

    /// 设置手势识别器
    private func setupGestureRecognizers(for button: NSStatusBarButton) {
        // 拖拽手势
        panGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        if let panGestureRecognizer {
            button.addGestureRecognizer(panGestureRecognizer)
        }
    }

    /// 设置鼠标跟踪
    private func setupMouseTracking(for button: NSStatusBarButton) {
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
    }

    /// 设置回调
    private func setupCallbacks() {
        // 监听输入法状态变化
        self.inputSourceManager.onInputSourceChanged = { [weak self] inputSource in
            DispatchQueue.main.async {
                self?.handleInputSourceChanged(inputSource)
            }
        }

        // 监听锁定状态变化
        self.inputSourceManager.onLockStateChanged = { [weak self] isLocked in
            DispatchQueue.main.async {
                self?.handleLockStateChanged(isLocked)
            }
        }

        // 监听应用切换
        appStateManager.onAppChanged = { [weak self] appInfo in
            DispatchQueue.main.async {
                self?.handleAppChanged(appInfo)
            }
        }

        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )

        // 监听通知交互
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationAction(_:)),
            name: .showQuickActions,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationAction(_:)),
            name: .showSettings,
            object: nil
        )
    }

    /// 设置快捷键
    private func setupHotKeys() {
        hotKeyManager.registerDefaultHotKeys()

        hotKeyManager.onHotKeyPressed = { [weak self] hotKeyID in
            self?.handleHotKeyPressed(hotKeyID)
        }
    }

    /// 设置主题观察者
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    // MARK: - Event Handlers

    /// 状态栏按钮点击处理
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // 检测多次点击
        let now = Date()
        if now.timeIntervalSince(lastClickTime) < 0.5 {
            clickCount += 1
        } else {
            clickCount = 1
        }
        lastClickTime = now

        logger.debug("状态栏按钮点击: 类型=\(event.type.rawValue), 次数=\(clickCount)", category: "StatusBar")

        // 根据点击类型和次数处理
        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        case .leftMouseUp:
            if clickCount >= 2 {
                // 双击：快速切换锁定状态
                handleDoubleClick()
            } else {
                // 单击：显示快速操作面板
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    if self?.clickCount == 1 {
                        self?.showQuickActions()
                    }
                }
            }
        default:
            break
        }
    }

    /// 处理双击
    private func handleDoubleClick() {
        inputSourceManager.toggleLock()

        // 双击动画效果
        if let button = statusItem?.button {
            animationManager.pulseStatusBarIcon(button, color: inputSourceManager.isLocked ? .systemRed : .systemGreen)
        }

        logger.info("双击切换锁定状态: \(inputSourceManager.isLocked)", category: "StatusBar")
    }

    /// 处理拖拽手势
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let button = statusItem?.button else { return }

        switch gesture.state {
        case .began:
            startLongPressTimer()
        case .changed:
            let translation = gesture.translation(in: button)
            // 根据拖拽方向执行不同操作
            if abs(translation.x) > 20 {
                cancelLongPressTimer()
                if translation.x > 0 {
                    // 向右拖拽：切换到下一个输入法
                    switchToNextInputSource()
                } else {
                    // 向左拖拽：切换到上一个输入法
                    switchToPreviousInputSource()
                }
                gesture.state = .ended
            }
        case .ended, .cancelled:
            cancelLongPressTimer()
        default:
            break
        }
    }

    /// 鼠标进入
    func mouseEntered(with event: NSEvent) {
        guard let button = statusItem?.button else { return }

        // 鼠标悬停效果
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        }
    }

    /// 鼠标离开
    func mouseExited(with event: NSEvent) {
        guard let button = statusItem?.button else { return }

        // 移除悬停效果
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    /// 处理输入法变化
    private func handleInputSourceChanged(_ inputSource: InputSourceModel) {
        updateStatusBar()

        // 输入法变化动画
        if let button = statusItem?.button {
            animationManager.rotateStatusBarIcon(button)
        }

        logger.inputSource("输入法变化: \(inputSource.name)")
    }

    /// 处理锁定状态变化
    private func handleLockStateChanged(_ isLocked: Bool) {
        updateStatusBar()

        // 锁定状态变化动画
        if let button = statusItem?.button {
            let color: NSColor = isLocked ? .systemRed : .systemGreen
            animationManager.pulseStatusBarIcon(button, color: color)
        }

        logger.lockEngine("锁定状态变化: \(isLocked)")
    }

    /// 处理应用切换
    private func handleAppChanged(_ appInfo: AppInfo) {
        updateStatusBar()
        logger.debug("应用切换: \(appInfo.localizedName)", category: "StatusBar")
    }

    /// 处理快捷键按下
    private func handleHotKeyPressed(_ hotKeyID: HotKeyID) {
        logger.info("快捷键触发: \(hotKeyID.description)", category: "StatusBar")

        switch hotKeyID {
        case .toggleLock:
            inputSourceManager.toggleLock()
        case .showQuickActions:
            showQuickActions()
        case .showSettings:
            showSettings()
        case .refreshInputSources:
            inputSourceManager.refreshInputSources()
        case .switchToNext:
            switchToNextInputSource()
        case .switchToPrevious:
            switchToPreviousInputSource()
        }
    }

    /// 处理通知操作
    @objc private func handleNotificationAction(_ notification: Notification) {
        switch notification.name {
        case .showQuickActions:
            showQuickActions()
        case .showSettings:
            showSettings()
        default:
            break
        }
    }

    @objc private func settingsChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.settings.showStatusBarIcon {
                // 若图标之前被隐藏，重新创建
                if self.statusItem == nil {
                    self.setupStatusBar()
                }
                self.updateStatusBar()
            } else {
                // 隐藏图标但保持后台运行，可通过快捷键唤起
                self.statusItem = nil
            }
        }
    }

    @objc private func themeDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBar()
        }
    }

    // MARK: - Long Press Timer

    /// 开始长按定时器
    private func startLongPressTimer() {
        cancelLongPressTimer()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.handleLongPress()
        }
    }

    /// 取消长按定时器
    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    /// 处理长按
    private func handleLongPress() {
        // 长按显示设置
        showSettings()

        // 长按震动反馈
        if #available(macOS 10.14, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }

        logger.info("长按触发设置", category: "StatusBar")
    }

    // MARK: - Input Source Navigation

    /// 切换到下一个输入法
    private func switchToNextInputSource() {
        let availableSources = inputSourceManager.availableInputSources
        guard !availableSources.isEmpty else { return }

        if let currentSource = inputSourceManager.currentInputSource,
           let currentIndex = availableSources.firstIndex(where: { $0.id == currentSource.id }) {
            let nextIndex = (currentIndex + 1) % availableSources.count
            let nextSource = availableSources[nextIndex]
            inputSourceManager.switchToInputSource(nextSource)
        } else {
            // 如果找不到当前输入法，切换到第一个
            inputSourceManager.switchToInputSource(availableSources[0])
        }
    }

    /// 切换到上一个输入法
    private func switchToPreviousInputSource() {
        let availableSources = inputSourceManager.availableInputSources
        guard !availableSources.isEmpty else { return }

        if let currentSource = inputSourceManager.currentInputSource,
           let currentIndex = availableSources.firstIndex(where: { $0.id == currentSource.id }) {
            let previousIndex = currentIndex > 0 ? currentIndex - 1 : availableSources.count - 1
            let previousSource = availableSources[previousIndex]
            inputSourceManager.switchToInputSource(previousSource)
        } else {
            // 如果找不到当前输入法，切换到最后一个
            if let lastSource = availableSources.last {
                inputSourceManager.switchToInputSource(lastSource)
            }
        }
    }

    // MARK: - UI Creation and Animation

    /// 创建快速操作弹出窗口
    private func createQuickActionPopover() {
        quickActionPopover = NSPopover()
        quickActionPopover?.contentViewController = NSHostingController(
            rootView: UltimateQuickActionView(
                inputSourceManager: inputSourceManager,
                appStateManager: appStateManager,
                settings: settings
            ) { [weak self] in
                self?.hideQuickActionsWithAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.showSettings()
                }
            }
        )
        quickActionPopover?.behavior = .applicationDefined
        quickActionPopover?.delegate = self
    }

    /// 显示快速操作面板（带动画）
    private func showQuickActionsWithAnimation() {
        guard let button = statusItem?.button, let popover = quickActionPopover else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        animationManager.animatePopoverAppearance(popover)

        // 菜单栏应用不是前台 App，.transient 无法收到外部点击事件
        // 使用全局监听器代替，仅当点击发生在面板窗口之外时才关闭
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            guard let popover = self.quickActionPopover, popover.isShown else { return }
            // 获取鼠标当前在屏幕上的坐标
            let mouseLocation = NSEvent.mouseLocation
            // 若存在面板窗口，只有点击在窗口外部才关闭
            if let popoverWindow = popover.contentViewController?.view.window {
                if !popoverWindow.frame.contains(mouseLocation) {
                    self.hideQuickActionsWithAnimation()
                }
            } else {
                self.hideQuickActionsWithAnimation()
            }
        }

        logger.debug("显示快速操作面板", category: "StatusBar")
    }

    /// 隐藏快速操作面板（带动画）
    private func hideQuickActionsWithAnimation() {
        // 移除外部点击监听器
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }

        guard let popover = quickActionPopover, popover.isShown else { return }

        animationManager.animatePopoverDisappearance(popover) {
            popover.performClose(nil)
        }

        logger.debug("隐藏快速操作面板", category: "StatusBar")
    }

    /// 显示上下文菜单
    private func showContextMenu() {
        guard let statusItem else { return }

        let menu = createEnhancedContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil

        logger.debug("显示增强上下文菜单", category: "StatusBar")
    }

    /// 创建增强上下文菜单
    private func createEnhancedContextMenu() -> NSMenu {
        let menu = NSMenu()

        // 当前状态信息（带图标）
        let currentInputSource = inputSourceManager.currentInputSource
        let statusTitle = "当前输入法: \(currentInputSource?.name ?? "未知")"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.image = NSImage(
            systemSymbolName: currentInputSource?.iconName ?? "keyboard",
            accessibilityDescription: nil
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let lockStatus = inputSourceManager.isLocked ? "已锁定" : "未锁定"
        let lockStatusItem = NSMenuItem(title: "状态: \(lockStatus)", action: nil, keyEquivalent: "")
        lockStatusItem.image = NSImage(
            systemSymbolName: inputSourceManager.isLocked ? "lock.fill" : "lock.open",
            accessibilityDescription: nil
        )
        lockStatusItem.isEnabled = false
        menu.addItem(lockStatusItem)

        menu.addItem(NSMenuItem.separator())

        // 快速操作
        let toggleAction = inputSourceManager.isLocked ? "解锁输入法" : "锁定到当前输入法"
        let toggleItem = NSMenuItem(title: toggleAction, action: #selector(toggleLock), keyEquivalent: "l")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        // 如果已锁定，显示锁定的输入法
        if let lockedInputSource = inputSourceManager.lockedInputSource {
            let lockedItem = NSMenuItem(title: "锁定到: \(lockedInputSource.name)", action: nil, keyEquivalent: "")
            lockedItem.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
            lockedItem.isEnabled = false
            menu.addItem(lockedItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 输入法快速切换
        let availableInputSources = inputSourceManager.availableInputSources.prefix(5)
        if !availableInputSources.isEmpty {
            let switchSubmenu = NSMenu()
            for (index, inputSource) in availableInputSources.enumerated() {
                let item = NSMenuItem(
                    title: inputSource.name,
                    action: #selector(switchToInputSource(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = inputSource
                item.state = inputSource.id == currentInputSource?.id ? .on : .off
                item.image = NSImage(systemSymbolName: inputSource.iconName, accessibilityDescription: nil)

                // 添加快捷键（1-5）
                if index < 5 {
                    item.keyEquivalent = "\(index + 1)"
                    item.keyEquivalentModifierMask = [.command, .shift]
                }

                switchSubmenu.addItem(item)
            }

            let switchMenuItem = NSMenuItem(title: "切换输入法", action: nil, keyEquivalent: "")
            switchMenuItem.image = NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: nil
            )
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
            whitelistItem.image = NSImage(
                systemSymbolName: appStateManager.isCurrentAppWhitelisted ? "minus.circle" : "plus.circle",
                accessibilityDescription: nil
            )
            whitelistItem.target = self
            menu.addItem(whitelistItem)

            menu.addItem(NSMenuItem.separator())
        }

        // 设置和帮助
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(showSettingsAction), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "关于 Typelock", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 Typelock", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)

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

        // 获取图标和颜色
        let (iconName, color) = getIconNameAndColor(for: newState)

        // 创建图标
        if let image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: getAccessibilityDescription(for: newState)
        ) {
            // 根据主题调整图标
            let iconColor = color ?? themeManager.getStatusBarIconColor()

            if color != nil {
                button.image = image.tinted(with: iconColor)
            } else {
                button.image = image
                image.isTemplate = true
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

        var tooltip = "Typelock - 输入法锁定工具"

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

        tooltip += "\n\n快捷键:"
        tooltip += "\n• 双击: 切换锁定状态"
        tooltip += "\n• 长按: 显示设置"
        tooltip += "\n• 左右拖拽: 切换输入法"
        tooltip += "\n• ⌃⌥L: 切换锁定"
        tooltip += "\n• ⌃⌥T: 快速操作"

        button.toolTip = tooltip
    }

    /// 创建设置窗口
    private func createSettingsWindow() {
        let settingsView = UltimateSettingsView(
            settings: settings,
            inputSourceManager: inputSourceManager,
            appStateManager: appStateManager,
            hotKeyManager: hotKeyManager
        )

        let hostingController = NSHostingController(rootView: settingsView)
        settingsWindow = NSWindow(contentViewController: hostingController)

        settingsWindow?.title = "Typelock 设置"
        settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        settingsWindow?.isReleasedWhenClosed = false
        settingsWindow?.center()
        settingsWindow?.setContentSize(NSSize(width: 700, height: 600))
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

        特性：
        • 智能输入法锁定
        • 应用白名单支持
        • 全局快捷键
        • 手势操作
        • 主题支持

        \(Constants.App.copyright)
        """
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSPopoverDelegate

extension UltimateStatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // 确保任何关闭路径都清理掉监听器
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
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
