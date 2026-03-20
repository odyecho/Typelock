import SwiftUI

struct UltimateSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var themeManager = ThemeManager.shared

    let hotKeyManager: HotKeyManager

    @State private var selectedTab: SettingsTab = .general
    @State private var showingResetAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 增强标题栏
            enhancedHeader

            Divider()

            // 主要内容区域
            HStack(spacing: 0) {
                // 侧边栏（固定宽度）
                sidebar
                    .frame(width: 200)

                Divider()

                // 内容区域
                contentArea
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 700, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .themedStyle()
        .sheet(isPresented: $showingExportSheet) {
            exportSettingsSheet
        }
        .sheet(isPresented: $showingImportSheet) {
            importSettingsSheet
        }
    }

    // MARK: - Enhanced Header

    private var enhancedHeader: some View {
        HStack {
            // 应用图标和信息
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Typelock 设置")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("输入法锁定应用配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索设置...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            // 操作按钮
            HStack(spacing: 8) {
                Menu {
                    Button("导出设置") { showingExportSheet = true }
                    Button("导入设置") { showingImportSheet = true }
                    Divider()
                    Button("重置设置", role: .destructive) { showingResetAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)

                Button("重置设置") {
                    showingResetAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.controlBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.8),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                withAnimation(.typelock) {
                    settings.resetToDefaults()
                }
            }
        } message: {
            Text("这将重置所有设置到默认值，此操作不可撤销。")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标签页列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredTabs, id: \.self) { tab in
                        sidebarItem(tab)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // 底部状态信息
            sidebarFooter
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var filteredTabs: [SettingsTab] {
        let availableTabs = SettingsTab.allCases.filter { $0.isImplemented }
        if searchText.isEmpty {
            return availableTabs
        } else {
            return availableTabs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                    $0.searchKeywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tab.iconName)
                .font(.system(size: 16))
                .foregroundColor(selectedTab == tab ? .white : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .primary)

                Text(tab.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(selectedTab == tab ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            if tab.hasNotification {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.typelockFast) {
                selectedTab = tab
            }
        }
        .padding(.horizontal, 8)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()

            // 当前状态
            HStack {
                Circle()
                    .fill(inputSourceManager.isMonitoring ? .green : .red)
                    .frame(width: 8, height: 8)

                Text(inputSourceManager.isMonitoring ? "监控中" : "已停止")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // 版本信息
            HStack {
                Text("版本 \(Constants.App.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Placeholder

    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("\(title)（开发中）")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selectedTab {
                case .general:
                    UltimateGeneralSettingsView(settings: settings, themeManager: themeManager)
                case .lock:
                    placeholderView(title: "锁定设置", icon: "lock")
                case .inputMethod:
                    placeholderView(title: "输入法设置", icon: "keyboard")
                case .apps:
                    placeholderView(title: "应用白名单", icon: "app")
                case .hotkeys:
                    UltimateHotKeySettingsView(hotKeyManager: hotKeyManager)
                case .appearance:
                    placeholderView(title: "外观设置", icon: "paintbrush")
                case .advanced:
                    placeholderView(title: "高级设置", icon: "slider.horizontal.3")
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Export/Import Sheets

    private var exportSettingsSheet: some View {
        VStack(spacing: 20) {
            Text("导出设置")
                .font(.title2)
                .fontWeight(.bold)

            Text("选择要导出的设置类别")
                .foregroundColor(.secondary)

            // 导出选项
            VStack(alignment: .leading, spacing: 12) {
                Toggle("通用设置", isOn: .constant(true))
                Toggle("锁定设置", isOn: .constant(true))
                Toggle("输入法设置", isOn: .constant(true))
                Toggle("应用白名单", isOn: .constant(true))
                Toggle("快捷键设置", isOn: .constant(true))
                Toggle("外观设置", isOn: .constant(true))
            }

            HStack {
                Button("取消") {
                    showingExportSheet = false
                }
                .buttonStyle(.bordered)

                Button("导出") {
                    exportSettings()
                    showingExportSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    private var importSettingsSheet: some View {
        VStack(spacing: 20) {
            Text("导入设置")
                .font(.title2)
                .fontWeight(.bold)

            Text("选择设置文件进行导入")
                .foregroundColor(.secondary)

            Button("选择文件") {
                importSettings()
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Button("取消") {
                    showingImportSheet = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }

    // MARK: - Helper Methods

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "typelock-settings-\(DateFormatter.exportFormatter.string(from: Date())).json"

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

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                do {
                    let data = try Data(contentsOf: url)
                    let importedSettings = try JSONDecoder().decode(SettingsModel.self, from: data)

                    // 应用导入的设置
                    withAnimation(.typelock) {
                        // 这里需要实现设置的复制逻辑
                        settings.saveSettings()
                    }
                } catch {
                    Logger.shared.error("导入设置失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Settings Tabs (Enhanced)

enum SettingsTab: String, CaseIterable {
    case general
    case lock
    case inputMethod
    case apps
    case hotkeys
    case appearance
    case advanced

    var title: String {
        switch self {
        case .general: return "通用"
        case .lock: return "锁定"
        case .inputMethod: return "输入法"
        case .apps: return "应用"
        case .hotkeys: return "快捷键"
        case .appearance: return "外观"
        case .advanced: return "高级"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "基本设置"
        case .lock: return "锁定行为"
        case .inputMethod: return "输入法管理"
        case .apps: return "应用白名单"
        case .hotkeys: return "全局快捷键"
        case .appearance: return "主题和外观"
        case .advanced: return "高级选项"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gear"
        case .lock: return "lock"
        case .inputMethod: return "keyboard"
        case .apps: return "app"
        case .hotkeys: return "command"
        case .appearance: return "paintbrush"
        case .advanced: return "slider.horizontal.3"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .general:
            return ["启动", "通知", "状态栏", "开机", "自启动"]
        case .lock:
            return ["锁定", "阈值", "检测", "自动", "切换"]
        case .inputMethod:
            return ["输入法", "键盘", "中文", "英文", "黑名单"]
        case .apps:
            return ["应用", "白名单", "程序", "软件"]
        case .hotkeys:
            return ["快捷键", "热键", "键盘", "组合键"]
        case .appearance:
            return ["外观", "主题", "颜色", "深色", "浅色"]
        case .advanced:
            return ["高级", "调试", "日志", "性能", "开发"]
        }
    }

    var hasNotification: Bool {
        // 可以根据需要添加通知逻辑
        false
    }

    /// 是否已实现（未实现的 Tab 不在侧边栏显示）
    var isImplemented: Bool {
        switch self {
        case .general, .hotkeys:
            return true
        default:
            return false
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    UltimateSettingsView(
        settings: SettingsModel(),
        inputSourceManager: EnhancedInputSourceManager(settings: SettingsModel()),
        appStateManager: AppStateManager(settings: SettingsModel()),
        hotKeyManager: HotKeyManager()
    )
}
