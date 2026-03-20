import SwiftUI

struct UltimateGeneralSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var themeManager: ThemeManager

    @State private var showStatusBarWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 页面标题
            pageHeader

            // 启动设置
            startupSection

            // 通知设置
            notificationSection

            // 界面设置
            interfaceSection

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通用设置")
                .font(.title2)
                .fontWeight(.bold)

            Text("配置应用的基本行为和界面选项")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Startup Section

    private var startupSection: some View {
        SettingsSection(title: "启动设置", icon: "power") {
            VStack(spacing: 16) {
                SettingsRow(
                    title: "开机自启动",
                    subtitle: "系统启动时自动运行 Typelock",
                    icon: "power.circle"
                ) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                }

                SettingsRow(
                    title: "显示状态栏图标",
                    subtitle: "在顶部菜单栏显示图标，点击可打开快捷面板",
                    icon: "menubar.rectangle"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.showStatusBarIcon },
                        set: { newValue in
                            if !newValue {
                                // 关闭前弹出确认，防止用户失去唯一入口
                                showStatusBarWarning = true
                            } else {
                                settings.showStatusBarIcon = true
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .alert("隐藏状态栏图标", isPresented: $showStatusBarWarning) {
                        Button("确认隐藏", role: .destructive) {
                            settings.showStatusBarIcon = false
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("隐藏后将无法通过点击状态栏访问 Typelock。\n\n可使用默认快捷键 ⌘⇧T 唤起快捷面板，或前往「快捷键」设置自定义。")
                    }
                }

                if settings.showStatusBarIcon {
                    SettingsRow(
                        title: "状态栏图标样式",
                        subtitle: "选择状态栏图标的显示样式",
                        icon: "paintbrush"
                    ) {
                        Picker("", selection: $settings.statusBarIconStyle) {
                            ForEach(StatusBarIconStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
            }
        }
        .onChange(of: settings.launchAtLogin) { _ in
            settings.saveSettings()
        }
        .onChange(of: settings.showStatusBarIcon) { _ in
            settings.saveSettings()
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        SettingsSection(title: "通知设置", icon: "bell") {
            VStack(spacing: 16) {
                SettingsRow(
                    title: "启用系统通知",
                    subtitle: "锁定或解锁输入法时，在屏幕右上角弹出提示",
                    icon: "bell.badge"
                ) {
                    Toggle("", isOn: $settings.showNotifications)
                        .toggleStyle(.switch)
                }

                if settings.showNotifications {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "锁定时显示通知",
                            subtitle: "输入法锁定时显示通知",
                            icon: "lock.circle"
                        ) {
                            Toggle("", isOn: $settings.notifyOnLock)
                                .toggleStyle(.switch)
                        }

                        SettingsRow(
                            title: "解锁时显示通知",
                            subtitle: "输入法解锁时显示通知",
                            icon: "lock.open"
                        ) {
                            Toggle("", isOn: $settings.notifyOnUnlock)
                                .toggleStyle(.switch)
                        }

                        SettingsRow(
                            title: "通知持续时间",
                            subtitle: "通知显示的时长（秒）",
                            icon: "timer"
                        ) {
                            HStack {
                                Slider(
                                    value: $settings.notificationDuration,
                                    in: 1...10,
                                    step: 0.5
                                ) {
                                    Text("通知持续时间")
                                }
                                .frame(width: 100)

                                Text("\(settings.notificationDuration, specifier: "%.1f")s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.leading, 32)
                }
            }
        }
        .onChange(of: settings.showNotifications) { _ in
            settings.saveSettings()
        }
    }

    // MARK: - Interface Section

    private var interfaceSection: some View {
        SettingsSection(title: "界面设置", icon: "rectangle.on.rectangle") {
            VStack(spacing: 16) {
                SettingsRow(
                    title: "快捷面板宽度",
                    subtitle: "点击状态栏图标弹出的快捷操作面板的宽度",
                    icon: "sidebar.left"
                ) {
                    HStack {
                        Slider(
                            value: $settings.quickActionPanelWidth,
                            in: 280...480,
                            step: 10
                        ) {
                            Text("面板宽度")
                        }
                        .frame(width: 120)

                        Text("\(Int(settings.quickActionPanelWidth))px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                SettingsRow(
                    title: "主题",
                    subtitle: "选择应用的外观主题",
                    icon: "circle.lefthalf.filled"
                ) {
                    Picker("", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            HStack {
                                Image(systemName: theme.iconName)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                SettingsRow(
                    title: "强调色",
                    subtitle: "选择应用的强调色",
                    icon: "paintpalette"
                ) {
                    ColorPicker("", selection: $themeManager.accentColor)
                        .frame(width: 60)
                }
            }
        }
        .onChange(of: settings.quickActionPanelWidth) { _ in
            settings.saveSettings()
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 12) {
                content
            }
            .padding(.leading, 32)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            content
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    UltimateGeneralSettingsView(
        settings: SettingsModel(),
        themeManager: ThemeManager.shared
    )
    .frame(width: 500, height: 600)
}
