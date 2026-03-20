import Cocoa
import SwiftUI

/// 主题管理器
/// 提供应用的主题和外观管理
class ThemeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ThemeManager()

    // MARK: - Properties

    @Published var currentTheme: AppTheme = .system
    @Published var accentColor: Color = .blue
    @Published var isDarkMode = false

    private var logger = Logger.shared

    // MARK: - Initialization

    private init() {
        loadThemeSettings()
        setupSystemAppearanceObserver()
        updateDarkModeStatus()
    }

    // MARK: - Public Methods

    /// 设置主题
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveThemeSettings()
        applyTheme()
        logger.info("主题已切换: \(theme.displayName)", category: "Theme")
    }

    /// 设置强调色
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveThemeSettings()
        logger.info("强调色已更新", category: "Theme")
    }

    /// 获取当前有效的外观
    func getEffectiveAppearance() -> NSAppearance {
        switch currentTheme {
        case .system:
            return NSApp.effectiveAppearance
        case .light:
            return NSAppearance(named: .aqua) ?? NSApp.effectiveAppearance
        case .dark:
            return NSAppearance(named: .darkAqua) ?? NSApp.effectiveAppearance
        }
    }

    /// 获取状态栏图标颜色
    func getStatusBarIconColor() -> NSColor {
        switch currentTheme {
        case .system:
            return isDarkMode ? .white : .black
        case .light:
            return .black
        case .dark:
            return .white
        }
    }

    // MARK: - Private Methods

    /// 加载主题设置
    private func loadThemeSettings() {
        if let themeRawValue = UserDefaults.standard.string(forKey: "TypelockTheme"),
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        }

        if let colorData = UserDefaults.standard.data(forKey: "TypelockAccentColor") {
            if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                accentColor = Color(nsColor)
            }
        }
    }

    /// 保存主题设置
    private func saveThemeSettings() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "TypelockTheme")

        let nsColor = NSColor(accentColor)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: "TypelockAccentColor")
        }
    }

    /// 应用主题
    private func applyTheme() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let appearance = self.getEffectiveAppearance()
            NSApp.appearance = appearance

            // 通知主题变化
            NotificationCenter.default.post(name: .themeDidChange, object: self.currentTheme)
        }
    }

    /// 设置系统外观观察者
    private func setupSystemAppearanceObserver() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    /// 系统外观变化处理
    @objc private func systemAppearanceDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateDarkModeStatus()
            if self?.currentTheme == .system {
                self?.applyTheme()
            }
        }
    }

    /// 更新深色模式状态
    private func updateDarkModeStatus() {
        let appearance = NSApp.effectiveAppearance
        isDarkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

// MARK: - AppTheme

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色模式"
        case .dark:
            return "深色模式"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

// MARK: - Theme Colors

extension ThemeManager {
    /// 主题颜色集合
    enum Colors {
        // 主要颜色
        static let primary = Color.blue
        static let secondary = Color.gray
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red

        // 背景颜色
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryBackground = Color(NSColor.underPageBackgroundColor)

        // 文本颜色
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)

        /// 分隔线颜色
        static let separator = Color(NSColor.separatorColor)

        // 状态颜色
        static let locked = Color.red
        static let unlocked = Color.green
        static let paused = Color.orange
        static let disabled = Color.gray
    }

    /// 获取状态颜色
    func getStatusColor(for state: LockState) -> Color {
        switch state {
        case .locked:
            return Colors.locked
        case .unlocked:
            return Colors.unlocked
        case .paused:
            return Colors.paused
        case .disabled:
            return Colors.disabled
        }
    }
}

// MARK: - LockState

enum LockState {
    case locked
    case unlocked
    case paused
    case disabled
}

// MARK: - Notification Names

extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

// MARK: - SwiftUI Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// 应用主题样式
    func themedStyle() -> some View {
        environment(\.themeManager, ThemeManager.shared)
    }

    /// 应用状态颜色
    func statusColor(_ state: LockState) -> some View {
        foregroundColor(ThemeManager.shared.getStatusColor(for: state))
    }
}

// MARK: - Color Extensions

extension Color {
    /// 从十六进制创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 转换为十六进制字符串
    var hexString: String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#000000" }
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// 调整亮度
    func brightness(_ amount: Double) -> Color {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return self }

        let red = max(0, min(1, rgbColor.redComponent + amount))
        let green = max(0, min(1, rgbColor.greenComponent + amount))
        let blue = max(0, min(1, rgbColor.blueComponent + amount))

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: rgbColor.alphaComponent)
    }

    /// 调整饱和度
    func saturation(_ amount: Double) -> Color {
        let nsColor = NSColor(self)
        guard let hsbColor = nsColor.usingColorSpace(.deviceRGB) else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let newSaturation = max(0, min(1, saturation + amount))

        return Color(
            hue: Double(hue),
            saturation: Double(newSaturation),
            brightness: Double(brightness),
            opacity: Double(alpha)
        )
    }
}
