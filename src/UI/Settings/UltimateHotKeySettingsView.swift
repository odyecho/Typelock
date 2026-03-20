import Carbon
import SwiftUI

struct UltimateHotKeySettingsView: View {
    let hotKeyManager: HotKeyManager

    @State private var hotKeyBindings: [HotKeyID: HotKeyBinding] = [:]
    @State private var isRecording: HotKeyID?
    @State private var showingConflictAlert = false
    @State private var conflictMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 页面标题
            pageHeader

            // 快捷键列表
            hotKeyList

            // 说明信息
            helpSection

            Spacer()
        }
        .padding(24)
        .onAppear {
            loadHotKeyBindings()
        }
        .alert("快捷键冲突", isPresented: $showingConflictAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷键设置")
                .font(.title2)
                .fontWeight(.bold)

            Text("配置全局快捷键来快速控制 Typelock")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - HotKey List

    private var hotKeyList: some View {
        SettingsSection(title: "全局快捷键", icon: "command") {
            VStack(spacing: 12) {
                ForEach(HotKeyID.allCases, id: \.self) { hotKeyID in
                    hotKeyRow(hotKeyID)
                }
            }
        }
    }

    private func hotKeyRow(_ hotKeyID: HotKeyID) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hotKeyID.displayName)
                    .font(.system(size: 14, weight: .medium))

                Text(getHotKeyDescription(hotKeyID))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 快捷键显示/录制按钮
            Button(
                action: {
                    if isRecording == hotKeyID {
                        stopRecording()
                    } else {
                        startRecording(hotKeyID)
                    }
                },
                label: {
                    HStack {
                        if isRecording == hotKeyID {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)

                                Text("按下快捷键...")
                                    .font(.system(size: 12))
                            }
                        } else {
                            Text(getHotKeyDisplayString(hotKeyID))
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording == hotKeyID ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isRecording == hotKeyID ? Color.red : Color.clear, lineWidth: 1)
                            )
                    )
                }
            )
            .buttonStyle(.plain)

            // 清除按钮
            if hotKeyBindings[hotKeyID] != nil {
                Button(
                    action: { clearHotKey(hotKeyID) },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                )
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Help Section

    private var helpSection: some View {
        SettingsSection(title: "使用说明", icon: "questionmark.circle") {
            VStack(alignment: .leading, spacing: 12) {
                helpItem(
                    icon: "1.circle",
                    title: "录制快捷键",
                    description: "点击快捷键按钮，然后按下你想要的组合键"
                )

                helpItem(
                    icon: "2.circle",
                    title: "修饰键要求",
                    description: "快捷键必须包含 Command (⌘) 或 Control (⌃) 键"
                )

                helpItem(
                    icon: "3.circle",
                    title: "冲突检测",
                    description: "系统会自动检测并提示快捷键冲突"
                )

                helpItem(
                    icon: "4.circle",
                    title: "清除快捷键",
                    description: "点击 ✕ 按钮可以清除已设置的快捷键"
                )
            }
        }
    }

    private func helpItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadHotKeyBindings() {
        // 从 UserDefaults 加载快捷键绑定
        for hotKeyID in HotKeyID.allCases {
            if let data = UserDefaults.standard.data(forKey: "HotKey_\(hotKeyID.rawValue)"),
               let binding = try? JSONDecoder().decode(HotKeyBinding.self, from: data) {
                hotKeyBindings[hotKeyID] = binding
            } else if let defaultCombo = hotKeyID.defaultKeyCombo {
                // 使用默认快捷键
                let binding = HotKeyBinding(
                    keyCode: defaultCombo.keyCode,
                    modifiers: defaultCombo.modifiers
                )
                hotKeyBindings[hotKeyID] = binding
            }
        }
    }

    private func saveHotKeyBinding(_ hotKeyID: HotKeyID, _ binding: HotKeyBinding?) {
        if let binding {
            if let data = try? JSONEncoder().encode(binding) {
                UserDefaults.standard.set(data, forKey: "HotKey_\(hotKeyID.rawValue)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "HotKey_\(hotKeyID.rawValue)")
        }
    }

    private func startRecording(_ hotKeyID: HotKeyID) {
        isRecording = hotKeyID

        // 设置全局事件监听器
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event, for: hotKeyID)
        }
    }

    private func stopRecording() {
        isRecording = nil
        // 移除事件监听器
        NSEvent.removeMonitor(self)
    }

    private func handleKeyEvent(_ event: NSEvent, for hotKeyID: HotKeyID) {
        guard isRecording == hotKeyID else { return }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        // 检查是否包含必需的修饰键
        let hasRequiredModifier = modifiers.contains(.command) || modifiers.contains(.control)
        guard hasRequiredModifier else {
            conflictMessage = "快捷键必须包含 Command (⌘) 或 Control (⌃) 键"
            showingConflictAlert = true
            stopRecording()
            return
        }

        // 转换修饰键
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        // 检查冲突
        if checkForConflicts(keyCode: UInt32(keyCode), modifiers: carbonModifiers, excluding: hotKeyID) {
            conflictMessage = "此快捷键已被其他功能使用，请选择其他组合键"
            showingConflictAlert = true
            stopRecording()
            return
        }

        // 保存新的快捷键绑定
        let binding = HotKeyBinding(keyCode: UInt32(keyCode), modifiers: carbonModifiers)
        hotKeyBindings[hotKeyID] = binding
        saveHotKeyBinding(hotKeyID, binding)

        // 重新注册快捷键
        hotKeyManager.unregisterHotKey(identifier: hotKeyID)
        hotKeyManager.registerHotKey(
            keyCode: UInt32(keyCode),
            modifiers: carbonModifiers,
            identifier: hotKeyID
        )

        stopRecording()
    }

    private func clearHotKey(_ hotKeyID: HotKeyID) {
        hotKeyBindings.removeValue(forKey: hotKeyID)
        saveHotKeyBinding(hotKeyID, nil)
        hotKeyManager.unregisterHotKey(identifier: hotKeyID)
    }

    private func checkForConflicts(keyCode: UInt32, modifiers: UInt32, excluding: HotKeyID) -> Bool {
        for (id, binding) in hotKeyBindings {
            if id != excluding, binding.keyCode == keyCode, binding.modifiers == modifiers {
                return true
            }
        }
        return false
    }

    private func getHotKeyDisplayString(_ hotKeyID: HotKeyID) -> String {
        guard let binding = hotKeyBindings[hotKeyID] else {
            return "未设置"
        }

        var result = ""

        // 修饰键
        if binding.modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if binding.modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if binding.modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if binding.modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }

        // 主键
        result += getKeyDisplayName(binding.keyCode)

        return result
    }

    private func getKeyDisplayName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        // 标点符号键
        case UInt32(kVK_ANSI_Comma): return ","
        case UInt32(kVK_ANSI_Period): return "."
        case UInt32(kVK_ANSI_Slash): return "/"
        case UInt32(kVK_ANSI_Semicolon): return ";"
        case UInt32(kVK_ANSI_Quote): return "'"
        case UInt32(kVK_ANSI_LeftBracket): return "["
        case UInt32(kVK_ANSI_RightBracket): return "]"
        case UInt32(kVK_ANSI_Backslash): return "\\"
        case UInt32(kVK_ANSI_Grave): return "`"
        case UInt32(kVK_ANSI_Minus): return "-"
        case UInt32(kVK_ANSI_Equal): return "="
        default: return "Key\(keyCode)"
        }
    }

    private func getHotKeyDescription(_ hotKeyID: HotKeyID) -> String {
        switch hotKeyID {
        case .toggleLock:
            return "切换输入法锁定状态"
        case .showQuickActions:
            return "显示快速操作面板"
        case .showSettings:
            return "打开设置窗口"
        case .refreshInputSources:
            return "刷新输入法列表"
        case .switchToNext:
            return "切换到下一个输入法"
        case .switchToPrevious:
            return "切换到上一个输入法"
        }
    }
}

// MARK: - HotKeyBinding Model

struct HotKeyBinding: Codable {
    let keyCode: UInt32
    let modifiers: UInt32
}

// MARK: - Preview

#Preview {
    UltimateHotKeySettingsView(hotKeyManager: HotKeyManager())
        .frame(width: 500, height: 600)
}
