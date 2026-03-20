import SwiftUI

struct QuickActionView: View {
    @State private var isLocked = false
    @State private var currentInputSource = "未知"

    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.blue)
                Text("Typelock")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Divider()

            // 当前输入法状态
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前输入法:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text(currentInputSource)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                }
            }

            // 锁定状态
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("锁定状态:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                        .foregroundColor(isLocked ? .red : .green)
                    Text(isLocked ? "已锁定" : "未锁定")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isLocked ? .red : .green)
                    Spacer()
                }
            }

            Divider()

            // 操作按钮
            VStack(spacing: 8) {
                Button(action: toggleLock) {
                    HStack {
                        Image(systemName: isLocked ? "lock.open" : "lock.fill")
                        Text(isLocked ? "解锁输入法" : "锁定输入法")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(width: 250)
        .onAppear {
            updateStatus()
        }
    }

    private func toggleLock() {
        isLocked.toggle()
        // 后续接入实际的锁定/解锁逻辑
        Logger.shared.info("切换锁定状态: \(isLocked)", category: "QuickAction")
    }

    private func openSettings() {
        // 后续接入设置窗口
        Logger.shared.info("打开设置", category: "QuickAction")
    }

    private func updateStatus() {
        // 后续从 InputSourceManager 获取实际状态
        currentInputSource = "简体中文"
        isLocked = false
    }
}
