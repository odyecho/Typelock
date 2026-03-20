import Foundation

/// 输入法数据模型
struct InputSourceModel: Identifiable, Equatable, Codable {
    /// 输入法唯一标识符
    let id: String

    /// 输入法显示名称
    let name: String

    /// 输入法类别
    let category: String

    /// 是否可选择
    let isSelectable: Bool

    /// 是否已启用
    let isEnabled: Bool

    /// 创建时间
    let createdAt: Date

    // MARK: - Initialization

    init(id: String, name: String, category: String = "", isSelectable: Bool = true, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.category = category
        self.isSelectable = isSelectable
        self.isEnabled = isEnabled
        createdAt = Date()
    }

    // MARK: - Computed Properties

    /// 是否为中文输入法
    var isChineseInputMethod: Bool {
        name.contains("中文") ||
            name.contains("Chinese") ||
            id.contains("com.apple.inputmethod.SCIM") ||
            id.contains("com.sogou") ||
            id.contains("com.baidu")
    }

    /// 是否为英文输入法
    var isEnglishInputMethod: Bool {
        name.contains("ABC") ||
            name.contains("English") ||
            id.contains("com.apple.keylayout.ABC")
    }

    /// 是否为日文输入法
    var isJapaneseInputMethod: Bool {
        name.contains("日本") ||
            name.contains("Japanese") ||
            id.contains("com.apple.inputmethod.Kotoeri")
    }

    /// 输入法类型描述
    var typeDescription: String {
        if isChineseInputMethod {
            return "中文输入法"
        } else if isEnglishInputMethod {
            return "英文输入法"
        } else if isJapaneseInputMethod {
            return "日文输入法"
        } else {
            return "其他输入法"
        }
    }

    /// 输入法图标名称（SF Symbols）
    var iconName: String {
        if isChineseInputMethod {
            return "character.textbox"
        } else if isEnglishInputMethod {
            return "abc"
        } else if isJapaneseInputMethod {
            return "character.ja"
        } else {
            return "globe"
        }
    }

    // MARK: - Methods

    /// 获取简化的显示名称
    /// - Returns: 简化后的名称
    func getSimplifiedName() -> String {
        // 移除常见的前缀和后缀
        var simplifiedName = name

        // 移除常见前缀
        let prefixesToRemove = ["Apple ", "macOS ", "系统 "]
        for prefix in prefixesToRemove where simplifiedName.hasPrefix(prefix) {
            simplifiedName = String(simplifiedName.dropFirst(prefix.count))
        }

        // 移除常见后缀
        let suffixesToRemove = [" Input Method", " 输入法", " - 简体中文"]
        for suffix in suffixesToRemove where simplifiedName.hasSuffix(suffix) {
            simplifiedName = String(simplifiedName.dropLast(suffix.count))
        }

        return simplifiedName.isEmpty ? name : simplifiedName
    }

    /// 检查是否与另一个输入法相同
    /// - Parameter other: 另一个输入法模型
    /// - Returns: 是否相同
    func isSameAs(_ other: InputSourceModel) -> Bool {
        id == other.id
    }
}

// MARK: - CustomStringConvertible

extension InputSourceModel: CustomStringConvertible {
    var description: String {
        "InputSource(id: \(id), name: \(name), type: \(typeDescription))"
    }
}

// MARK: - Hashable

extension InputSourceModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
