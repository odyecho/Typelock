import SwiftUI

struct UltimateQuickActionView: View {
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var themeManager = ThemeManager.shared

    let onSettingsRequested: () -> Void

    @State private var isAnimating = false
    @State private var showingInputSourceList = false
    @State private var selectedInputSourceIndex = 0
    @State private var showingAppList = false
    @State private var searchText = ""
    @State private var buttonHint: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 动态标题栏
            headerView
                .background(headerBackground)

            Divider()

            // 主要内容区域
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 状态卡片
                    statusCard
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))

                    // 快速操作区域
                    quickActionsSection

                    // 输入法列表（可展开）
                    if showingInputSourceList {
                        inputSourceListSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    // 应用列表（可展开）
                    if showingAppList {
                        appListSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    // 当前应用信息
                    currentAppSection
                }
                .padding()
            }

            Divider()

            // 底部工具栏
            bottomToolbar
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: settings.quickActionPanelWidth, height: calculateHeight())
        .background(Color(NSColor.windowBackgroundColor))
        .themedStyle()
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // 应用图标和标题
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Typelock")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("输入法锁定控制")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 状态指示器
            statusIndicator
        }
        .padding()
    }

    private var headerBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(NSColor.controlBackgroundColor),
                Color(NSColor.controlBackgroundColor).opacity(0.8),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating && inputSourceManager.isLocked ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }

    private var statusColor: Color {
        if !inputSourceManager.isMonitoring {
            return .gray
        } else if inputSourceManager.isLocked {
            return appStateManager.isCurrentAppWhitelisted ? .orange : .red
        } else {
            return .green
        }
    }

    private var statusText: String {
        if !inputSourceManager.isMonitoring {
            return "已禁用"
        } else if inputSourceManager.isLocked {
            return appStateManager.isCurrentAppWhitelisted ? "已暂停" : "已锁定"
        } else {
            return "未锁定"
        }
    }

    private var isCurrentInputSourceLocked: Bool {
        guard let currentInputSource = inputSourceManager.currentInputSource else { return false }
        return inputSourceManager.isLocked && inputSourceManager.lockedInputSource?.id == currentInputSource.id
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            // 当前输入法信息
            if let currentInputSource = inputSourceManager.currentInputSource {
                HStack {
                    Image(systemName: currentInputSource.iconName)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前输入法")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(currentInputSource.name)
                            .font(.body)
                            .fontWeight(.semibold)

                        Text(currentInputSource.typeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 状态标识
                    VStack(alignment: .trailing, spacing: 4) {
                        if inputSourceManager.isLocked,
                           inputSourceManager.lockedInputSource?.id == currentInputSource.id {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                Text("已锁定")
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                        }

                        if settings.preferredInputSourceId == currentInputSource.id {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                Text("偏好")
                                    .font(.caption)
                            }
                            .foregroundColor(.yellow)
                        }
                    }
                }

                Button(action: { inputSourceManager.lockToCurrent() }) {
                    HStack(spacing: 8) {
                        Image(systemName: isCurrentInputSourceLocked ? "lock.fill" : "lock")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isCurrentInputSourceLocked ? "已锁定当前输入法" : "锁定当前输入法")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCurrentInputSourceLocked)
            }

            // 锁定状态详情
            if inputSourceManager.isLocked, let lockedInputSource = inputSourceManager.lockedInputSource {
                Divider()

                HStack {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("锁定到")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(lockedInputSource.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }

                    Spacer()

                    if appStateManager.isCurrentAppWhitelisted {
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                            Text("已暂停")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按钮
            HStack(spacing: 12) {
                Button(action: toggleLock) {
                    HStack {
                        Image(systemName: inputSourceManager.isLocked ? "lock.open" : "lock.fill")
                            .font(.title3)
                        Text(inputSourceManager.isLocked ? "解锁输入法" : "锁定输入法")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(
                    action: { showingInputSourceList.toggle() },
                    label: {
                        Image(systemName: showingInputSourceList ? "chevron.up" : "list.bullet")
                            .font(.title3)
                    }
                )
                .buttonStyle(.bordered)
                .help(showingInputSourceList ? "隐藏输入法列表" : "显示输入法列表")
            }

            // 辅助操作按钮
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.typelock) {
                            inputSourceManager.refreshInputSources()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .onHover { hovering in
                        buttonHint = hovering ? "刷新：重新扫描已安装的输入法" : ""
                    }

                    Button {
                        onSettingsRequested()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .onHover { hovering in
                        buttonHint = hovering ? "设置：打开应用设置" : ""
                    }

                    Spacer()

                    Button(
                        action: { showingAppList.toggle() },
                        label: { Image(systemName: showingAppList ? "app.badge.checkmark" : "app") }
                    )
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .onHover { hovering in
                        buttonHint = hovering ? (showingAppList ? "隐藏应用列表" : "显示白名单应用列表") : ""
                    }
                }

                // 悬停提示文字
                if !buttonHint.isEmpty {
                    Text(buttonHint)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Input Source List

    private var inputSourceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("可用输入法")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(inputSourceManager.availableInputSources.count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索输入法...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            // 输入法列表
            LazyVStack(spacing: 6) {
                ForEach(filteredInputSources.prefix(8)) { inputSource in
                    inputSourceRow(inputSource)
                }

                if filteredInputSources.count > 8 {
                    Text("还有 \(filteredInputSources.count - 8) 个输入法...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    private var filteredInputSources: [InputSourceModel] {
        if searchText.isEmpty {
            return inputSourceManager.availableInputSources
        } else {
            return inputSourceManager.availableInputSources.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func inputSourceRow(_ inputSource: InputSourceModel) -> some View {
        HStack {
            Image(systemName: inputSource.iconName)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(inputSource.getSimplifiedName())
                    .font(.system(size: 13, weight: .medium))

                Text(inputSource.typeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态指示器
            HStack(spacing: 6) {
                if inputSource.id == inputSourceManager.currentInputSource?.id {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }

                if inputSource.id == inputSourceManager.lockedInputSource?.id {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }

                if settings.preferredInputSourceId == inputSource.id {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }

                if settings.isInBlacklist(inputSource.id) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            }

            // 操作按钮
            Button(
                action: {
                    _ = inputSourceManager.switchToInputSource(inputSource)
                },
                label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 14))
                }
            )
            .buttonStyle(.borderless)
            .help("切换到此输入法")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(inputSource.id == inputSourceManager.currentInputSource?.id ? Color.blue.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            _ = inputSourceManager.switchToInputSource(inputSource)
        }
    }

    // MARK: - App List Section

    private var appListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("运行中的应用")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(appStateManager.getRunningApps().count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 6) {
                ForEach(appStateManager.getRunningApps().prefix(6)) { app in
                    appRow(app)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    private func appRow(_ app: AppInfo) -> some View {
        HStack {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "app")
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.localizedName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(app.typeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if settings.isInWhitelist(app.bundleIdentifier) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))

                Button("移除") {
                    withAnimation(.typelockFast) {
                        settings.removeFromWhitelist(app.bundleIdentifier)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                Button("添加") {
                    withAnimation(.typelockFast) {
                        settings.addToWhitelist(app.bundleIdentifier)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(app.isActive ? Color.blue.opacity(0.1) : Color.clear)
        )
    }

    // MARK: - Current App Section

    private var currentAppSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let currentApp = appStateManager.currentApp {
                // 标题行：说明白名单的作用
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前活跃应用")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("白名单内的应用不受输入法锁定限制")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 白名单状态标签
                    if appStateManager.isCurrentAppWhitelisted {
                        Label("已豁免", systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    }
                }

                // 应用信息行
                HStack(spacing: 10) {
                    // 应用图标
                    if let icon = currentApp.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .frame(width: 36, height: 36)
                            .foregroundColor(.secondary)
                    }

                    // 应用名称与类型
                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentApp.localizedName)
                            .font(.body)
                            .fontWeight(.medium)

                        Text(currentApp.typeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 操作按钮：明确说明操作含义
                    if appStateManager.isCurrentAppWhitelisted {
                        Button {
                            withAnimation(.typelock) {
                                appStateManager.removeCurrentAppFromWhitelist()
                            }
                        } label: {
                            Label("移出白名单", systemImage: "shield.slash")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("将此应用从白名单移除，恢复输入法锁定")
                    } else {
                        Button {
                            withAnimation(.typelock) {
                                appStateManager.addCurrentAppToWhitelist()
                            }
                        } label: {
                            Label("加入白名单", systemImage: "shield.checkmark")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("加入后此应用不受输入法锁定限制")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            // 版本信息
            Text("v\(Constants.App.version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // 监控状态
            HStack(spacing: 4) {
                Circle()
                    .fill(inputSourceManager.isMonitoring ? .green : .red)
                    .frame(width: 6, height: 6)

                Text(inputSourceManager.isMonitoring ? "监控中" : "已停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 快捷键提示
            Text("⌃⌥L 切换锁定")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Helper Methods

    private func calculateHeight() -> CGFloat {
        // 基础高度：标题栏(56) + 状态卡片(~90) + 快捷操作区(~90) + 当前应用区(~110) + 底部栏(40) + 间距
        var height: CGFloat = 430

        if showingInputSourceList {
            height += 280
        }

        if showingAppList {
            height += 200
        }

        return min(height, 700) // 最大高度限制
    }

    private func startAnimations() {
        isAnimating = inputSourceManager.isLocked
    }

    private func toggleLock() {
        withAnimation(.typelock) {
            inputSourceManager.toggleLock()
        }

        // 触觉反馈
        if #available(macOS 10.14, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }
}

// MARK: - Preview

#Preview {
    UltimateQuickActionView(
        inputSourceManager: EnhancedInputSourceManager(settings: SettingsModel()),
        appStateManager: AppStateManager(settings: SettingsModel()),
        settings: SettingsModel()
    ) {}
}
