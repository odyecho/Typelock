import XCTest
@testable import Typelock

final class InputSourceModelTests: XCTestCase {
    func testChineseInputMethodDetection() {
        let model = InputSourceModel(
            id: "com.apple.inputmethod.SCIM.ITABC",
            name: "简体中文",
            category: "input"
        )

        XCTAssertTrue(model.isChineseInputMethod)
        XCTAssertEqual(model.typeDescription, "中文输入法")
        XCTAssertEqual(model.iconName, "character.textbox")
    }

    func testEnglishInputMethodDetection() {
        let model = InputSourceModel(
            id: "com.apple.keylayout.ABC",
            name: "ABC",
            category: "layout"
        )

        XCTAssertTrue(model.isEnglishInputMethod)
        XCTAssertEqual(model.typeDescription, "英文输入法")
        XCTAssertEqual(model.iconName, "abc")
    }

    func testSimplifiedNameRemovesKnownPrefixAndSuffix() {
        let model = InputSourceModel(
            id: "com.apple.inputmethod.Pinyin",
            name: "Apple 拼音 输入法",
            category: "input"
        )

        XCTAssertEqual(model.getSimplifiedName(), "拼音")
    }

    func testIsSameAsComparesOnlyIdentifier() {
        let first = InputSourceModel(id: "a.b.c", name: "One")
        let second = InputSourceModel(id: "a.b.c", name: "Two")
        let third = InputSourceModel(id: "x.y.z", name: "Three")

        XCTAssertTrue(first.isSameAs(second))
        XCTAssertFalse(first.isSameAs(third))
    }
}
