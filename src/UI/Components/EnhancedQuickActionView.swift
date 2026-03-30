import SwiftUI

struct EnhancedQuickActionView: View {
    @ObservedObject var inputSourceManager: EnhancedInputSourceManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var settings: SettingsModel

    let onSettingsRequested: () -> Void

    @State private var isAnimating = false
    @State private var showingInputSourceList = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // 主要内容
            ScrollView {
                VStack(spacing: 16) {
                    // 当前状态卡片
                    currentStatusCard

                    // 快速操作按钮
                    quickActionsSection

                    // 输入法信息
                    if showingInputSourceList {
                        inputSourceListSection
                    }

                    // 当前应用信息
                    currentAppSection
                }
                .padding()
            }

            Divider()

            // 底部操作栏
            bottomActionBar
        }
        .frame(width: settings.quickActionPanelWidth, height: showingInputSourceList ? 400 : 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
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

            Spacer()

            // 状态指示器
            statusIndicator
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isAnimating = inputSourceManager.isLocked
        }
        .onChange(of: inputSourceManager.isLocked) { isLocked in
            isAnimating = isLocked
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
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

    // MARK: - Current Status Card

    private var currentStatusCard: some View {
        VStack(spacing: 12) {
            // 当前输入法
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

                    if inputSourceManager.isLocked, inputSourceManager.lockedInputSource?.id == currentInputSource.id {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                HStack(spacing: 10) {
                    Spacer()

                    Button(action: toggleCurrentInputSourceLock) {
                        HStack(spacing: 6) {
                            Image(systemName: isCurrentInputSourceLocked ? "lock.open" : "lock")
                            Text(isCurrentInputSourceLocked ? "解锁输入法" : "锁定输入法")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(
                        action: { showingInputSourceList.toggle() },
                        label: { Image(systemName: showingInputSourceList ? "chevron.up" : "list.bullet") }
                    )
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(showingInputSourceList ? "隐藏输入法列表" : "显示输入法列表")
                }
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
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            // 辅助操作
            HStack(spacing: 8) {
                Button("刷新") {
                    inputSourceManager.refreshInputSources()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("设置") {
                    onSettingsRequested()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    // MARK: - Input Source List

    private var inputSourceListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("可用输入法")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(inputSourceManager.availableInputSources.count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 4) {
                ForEach(inputSourceManager.availableInputSources.prefix(6)) { inputSource in
                    inputSourceRow(inputSource)
                }

                if inputSourceManager.availableInputSources.count > 6 {
                    Text("还有 \(inputSourceManager.availableInputSources.count - 6) 个输入法...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func inputSourceRow(_ inputSource: InputSourceModel) -> some View {
        HStack {
            Image(systemName: inputSource.iconName)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(inputSource.getSimplifiedName())
                    .font(.system(size: 12, weight: .medium))

                Text(inputSource.typeDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态指示器
            HStack(spacing: 4) {
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

                if settings.isInBlacklist(inputSource.id) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            }

            // 操作按钮
            Button(
                action: { inputSourceManager.switchToInputSource(inputSource) },
                label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                }
            )
            .buttonStyle(.borderless)
            .help("切换到此输入法")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(inputSource.id == inputSourceManager.currentInputSource?.id ? Color.blue.opacity(0.1) : Color
                    .clear)
        )
    }

    // MARK: - Current App Section

    private var currentAppSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let currentApp = appStateManager.currentApp {
                HStack {
                    Text("当前应用")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if appStateManager.isCurrentAppWhitelisted {
                        Text("白名单")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    if let icon = currentApp.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 24, height: 24)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentApp.localizedName)
                            .font(.body)
                            .fontWeight(.medium)

                        Text(currentApp.typeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(appStateManager.isCurrentAppWhitelisted ? "移除" : "添加") {
                        if appStateManager.isCurrentAppWhitelisted {
                            appStateManager.removeCurrentAppFromWhitelist()
                        } else {
                            appStateManager.addCurrentAppToWhitelist()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    private func toggleLock() {
        inputSourceManager.toggleLock()

        // 添加触觉反馈（如果支持）
        if #available(macOS 10.14, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }

    private func toggleCurrentInputSourceLock() {
        if isCurrentInputSourceLocked {
            inputSourceManager.setLocked(false)
        } else {
            inputSourceManager.lockToCurrent()
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedQuickActionView(
        inputSourceManager: EnhancedInputSourceManager(settings: SettingsModel()),
        appStateManager: AppStateManager(settings: SettingsModel()),
        settings: SettingsModel()
    ) {}
}
