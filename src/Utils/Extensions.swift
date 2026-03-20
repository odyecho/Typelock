import Cocoa
import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// 本地化字符串
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }

    /// 移除空白字符
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 检查是否为空或只包含空白字符
    var isBlank: Bool {
        trimmed.isEmpty
    }
}

// MARK: - Date Extensions

extension Date {
    /// 格式化为用户友好的字符串
    var userFriendlyString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    /// 相对时间字符串（如：2分钟前）
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// 检查是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// 检查是否是昨天
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}

// MARK: - NSApplication Extensions

extension NSApplication {
    /// 获取应用版本
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// 获取构建版本
    var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// 获取完整版本字符串
    var fullVersion: String {
        "\(appVersion) (\(buildVersion))"
    }

    /// 检查是否在沙盒环境中运行
    var isSandboxed: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    /// 获取应用名称
    var appName: String {
        infoDictionary?["CFBundleName"] as? String ?? "Typelock"
    }

    /// 获取显示名称
    var displayName: String {
        infoDictionary?["CFBundleDisplayName"] as? String ?? appName
    }

    /// 获取 Bundle ID
    var bundleId: String {
        bundleIdentifier ?? "com.typelock.macos"
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    /// 安全地设置对象
    func setObject(_ object: some Codable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        set(data, forKey: key)
    }

    /// 安全地获取对象
    func getObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - NSImage Extensions

extension NSImage {
    /// 创建带颜色的图像
    func tinted(with color: NSColor) -> NSImage {
        guard let image = copy() as? NSImage else {
            return self
        }
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    /// 调整图像大小
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }

    /// 创建系统符号图像
    static func systemSymbol(_ name: String, size: CGFloat = 16) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }
}

// MARK: - NSColor Extensions

extension NSColor {
    /// 十六进制颜色初始化
    convenience init(hex: String) {
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
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }

    /// 转换为十六进制字符串
    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return "#000000" }
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// 安全地获取指定索引的元素
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    /// 移除指定条件的元素
    mutating func removeAll(where predicate: (Element) throws -> Bool) rethrows {
        self = try filter { try !predicate($0) }
    }
}

// MARK: - Optional Extensions

extension Optional {
    /// 如果为 nil 则抛出错误
    func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }

    /// 如果为 nil 则使用默认值
    func or(_ defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }
}

// MARK: - Result Extensions

extension Result {
    /// 获取成功值，失败时返回 nil
    var value: Success? {
        switch self {
        case let .success(value):
            return value
        case .failure:
            return nil
        }
    }

    /// 获取错误，成功时返回 nil
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }
}

// MARK: - DispatchQueue Extensions

extension DispatchQueue {
    /// 在主队列中安全执行
    static func mainSafe(execute work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// 延迟执行
    static func delay(_ delay: TimeInterval, execute work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// 获取应用支持目录
    var applicationSupportDirectory: URL? {
        urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// 获取文档目录
    var documentsDirectory: URL? {
        urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// 获取缓存目录
    var cachesDirectory: URL? {
        urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// 创建目录（如果不存在）
    func createDirectoryIfNeeded(at url: URL) throws {
        if !fileExists(atPath: url.path) {
            try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// 获取文件大小
    func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.size] as? Int64
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let inputSourceChanged = Notification.Name("TypelockInputSourceChanged")
    static let lockStateChanged = Notification.Name("TypelockLockStateChanged")
    static let settingsChanged = Notification.Name("TypelockSettingsChanged")
    static let permissionGranted = Notification.Name("TypelockPermissionGranted")
    static let permissionDenied = Notification.Name("TypelockPermissionDenied")
}

// MARK: - SwiftUI Extensions

extension View {
    /// 条件修饰符
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 条件修饰符（带 else）
    @ViewBuilder
    func `if`(
        _ condition: Bool,
        if trueTransform: (Self) -> some View,
        else falseTransform: (Self) -> some View
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
}
