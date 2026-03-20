import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager
    @ObservedObject var appStateManager: AppStateManager

    @State private var selectedTab: SettingsTab = .general
    @State private var showingResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            settingsHeader

            // 标签页选择
            tabSelector

            // 内容区域
            TabView(selection: $selectedTab) {
                GeneralSettingsView(settings: settings)
                    .tabItem { Label("通用", systemImage: "gear") }
                    .tag(SettingsTab.general)

                LockSettingsView(settings: settings, inputSourceManager: inputSourceManager)
                    .tabItem { Label("锁定", systemImage: "lock") }
                    .tag(SettingsTab.lock)

                InputMethodSettingsView(settings: settings, inputSourceManager: inputSourceManager)
                    .tabItem { Label("输入法", systemImage: "keyboard") }
                    .tag(SettingsTab.inputMethod)

                AppWhitelistView(settings: settings, appStateManager: appStateManager)
                    .tabItem { Label("应用", systemImage: "app") }
                    .tag(SettingsTab.apps)

                AdvancedSettingsView(settings: settings)
                    .tabItem { Label("高级", systemImage: "slider.horizontal.3") }
                    .tag(SettingsTab.advanced)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Typelock 设置")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("输入法锁定应用配置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("重置设置") {
                showingResetAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("这将重置所有设置到默认值，此操作不可撤销。")
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(
                    action: { selectedTab = tab },
                    label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 14))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                )
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable {
    case general
    case lock
    case inputMethod
    case apps
    case advanced

    var title: String {
        switch self {
        case .general: return "通用"
        case .lock: return "锁定"
        case .inputMethod: return "输入法"
        case .apps: return "应用"
        case .advanced: return "高级"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gear"
        case .lock: return "lock"
        case .inputMethod: return "keyboard"
        case .apps: return "app"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsModel

    var body: some View {
        Form {
            Section("启动设置") {
                Toggle("开机自启动", isOn: $settings.launchAtLogin)
                    .help("应用将在系统启动时自动运行")

                Toggle("显示状态栏图标", isOn: $settings.showStatusBarIcon)
                    .help("在状态栏显示 Typelock 图标")
            }

            Section("通知设置") {
                Toggle("显示通知", isOn: $settings.showNotifications)
                    .help("输入法状态变化时显示通知")

                if settings.showNotifications {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("锁定时显示通知", isOn: $settings.notifyOnLock)
                        Toggle("解锁时显示通知", isOn: $settings.notifyOnUnlock)

                        HStack {
                            Text("通知持续时间:")
                            Slider(value: $settings.notificationDuration, in: 1...10, step: 0.5) {
                                Text("通知持续时间")
                            }
                            Text("\(settings.notificationDuration, specifier: "%.1f")秒")
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding(.leading)
                }
            }

            Section("界面设置") {
                Picker("状态栏图标样式", selection: $settings.statusBarIconStyle) {
                    ForEach(StatusBarIconStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                HStack {
                    Text("快速操作面板宽度:")
                    Slider(value: $settings.quickActionPanelWidth, in: 200...400, step: 10) {
                        Text("面板宽度")
                    }
                    Text("\(Int(settings.quickActionPanelWidth))px")
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: settings.launchAtLogin) { _ in
            settings.saveSettings()
        }
        .onChange(of: settings.showStatusBarIcon) { _ in
            settings.saveSettings()
        }
        .onChange(of: settings.showNotifications) { _ in
            settings.saveSettings()
        }
    }
}

// MARK: - Lock Settings

struct LockSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager

    var body: some View {
        Form {
            Section("锁定行为") {
                Toggle("默认启用锁定", isOn: $settings.defaultLockState)
                    .help("应用启动时自动启用输入法锁定")

                Toggle("应用切换时自动锁定", isOn: $settings.autoLockOnAppSwitch)
                    .help("切换到新应用时自动锁定当前输入法")
            }

            Section("检测设置") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("用户操作检测阈值:")
                        Spacer()
                        Text("\(settings.userActionThreshold)ms")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: Binding(
                        get: { Double(settings.userActionThreshold) },
                        set: { settings.userActionThreshold = Int($0) }
                    ), in: 100...2_000, step: 50) {
                        Text("检测阈值")
                    }

                    Text("较小的值会更敏感地检测用户操作，但可能误判系统切换")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("当前状态") {
                HStack {
                    Text("锁定状态:")
                    Spacer()
                    Text(inputSourceManager.isLocked ? "已锁定" : "未锁定")
                        .foregroundColor(inputSourceManager.isLocked ? .red : .green)
                        .fontWeight(.medium)
                }

                if let lockedInputSource = inputSourceManager.lockedInputSource {
                    HStack {
                        Text("锁定的输入法:")
                        Spacer()
                        Text(lockedInputSource.name)
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    if inputSourceManager.isLocked {
                        Button("解锁") {
                            inputSourceManager.setLocked(false)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("锁定到当前输入法") {
                            inputSourceManager.lockToCurrent()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: settings.userActionThreshold) { _ in
            inputSourceManager.updateUserActionThreshold(settings.userActionThreshold)
            settings.saveSettings()
        }
    }
}

// MARK: - Input Method Settings

struct InputMethodSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager

    var body: some View {
        Form {
            Section("当前输入法") {
                if let current = inputSourceManager.currentInputSource {
                    HStack {
                        Image(systemName: current.iconName)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(current.name)
                                .fontWeight(.medium)
                            Text(current.typeDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("可用输入法") {
                ForEach(inputSourceManager.availableInputSources) { inputSource in
                    HStack {
                        Image(systemName: inputSource.iconName)
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(inputSource.name)
                                .fontWeight(.medium)
                            Text(inputSource.typeDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if settings.preferredInputSourceId == inputSource.id {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .help("偏好输入法")
                        }

                        if settings.isInBlacklist(inputSource.id) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .help("已禁用")
                        }

                        Menu {
                            Button("设为偏好") {
                                settings.preferredInputSourceId = inputSource.id
                                settings.saveSettings()
                            }

                            Button("切换到此输入法") {
                                inputSourceManager.switchToInputSource(inputSource)
                            }

                            Divider()

                            if settings.isInBlacklist(inputSource.id) {
                                Button("从黑名单移除") {
                                    settings.removeFromBlacklist(inputSource.id)
                                }
                            } else {
                                Button("添加到黑名单") {
                                    settings.addToBlacklist(inputSource.id)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 20)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("操作") {
                HStack {
                    Button("刷新输入法列表") {
                        inputSourceManager.refreshInputSources()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - App Whitelist

struct AppWhitelistView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var appStateManager: AppStateManager

    @State private var runningApps: [AppInfo] = []

    var body: some View {
        Form {
            Section("当前应用") {
                if let currentApp = appStateManager.currentApp {
                    HStack {
                        if let icon = currentApp.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 24, height: 24)
                        }

                        VStack(alignment: .leading) {
                            Text(currentApp.localizedName)
                                .fontWeight(.medium)
                            Text(currentApp.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if appStateManager.isCurrentAppWhitelisted {
                            Button("从白名单移除") {
                                appStateManager.removeCurrentAppFromWhitelist()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("添加到白名单") {
                                appStateManager.addCurrentAppToWhitelist()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("运行中的应用") {
                ForEach(runningApps) { app in
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 20, height: 20)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.localizedName)
                                .fontWeight(.medium)
                            Text(app.typeDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if settings.isInWhitelist(app.bundleIdentifier) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .help("在白名单中")

                            Button("移除") {
                                settings.removeFromWhitelist(app.bundleIdentifier)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("添加") {
                                settings.addToWhitelist(app.bundleIdentifier)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("说明") {
                Text("白名单中的应用在使用时不会触发输入法锁定功能。这对于某些需要频繁切换输入法的应用很有用。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            refreshRunningApps()
        }
        .onChange(of: appStateManager.currentApp) { _ in
            refreshRunningApps()
        }
    }

    private func refreshRunningApps() {
        runningApps = appStateManager.getRunningApps()
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsModel

    var body: some View {
        Form {
            Section("调试设置") {
                Toggle("调试模式", isOn: $settings.debugMode)
                    .help("启用详细的调试信息")

                Picker("日志级别", selection: $settings.logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }

            Section("性能监控") {
                Toggle("启用性能监控", isOn: $settings.enablePerformanceMonitoring)
                    .help("监控应用的 CPU 和内存使用情况")
            }

            Section("应用信息") {
                HStack {
                    Text("版本:")
                    Spacer()
                    Text(Constants.App.version)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("构建:")
                    Spacer()
                    Text(Constants.App.build)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Bundle ID:")
                    Spacer()
                    Text(Constants.App.bundleId)
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Section("操作") {
                HStack {
                    Button("打开日志目录") {
                        let url = URL(fileURLWithPath: Constants.logsPath)
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)

                    Button("导出设置") {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: settings.debugMode) { _ in
            settings.saveSettings()
        }
        .onChange(of: settings.logLevel) { _ in
            settings.saveSettings()
            Logger.shared.logLevel = settings.logLevel
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "typelock-settings.json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try JSONEncoder().encode(settings)
                    try data.write(to: url)
                } catch {
                    Logger.shared.error("导出设置失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        settings: SettingsModel(),
        inputSourceManager: EnhancedInputSourceManager(settings: SettingsModel()),
        appStateManager: AppStateManager(settings: SettingsModel())
    )
}
