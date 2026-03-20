import XCTest
@testable import Typelock

final class SettingsModelTests: XCTestCase {
    private let settingsKey = "TypelockSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testDefaultValuesWhenNoPersistedData() {
        let settings = SettingsModel()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertFalse(settings.defaultLockState)
        XCTAssertEqual(settings.userActionThreshold, 500)
        XCTAssertEqual(settings.statusBarIconStyle, .adaptive)
        XCTAssertEqual(settings.logLevel, .info)
    }

    func testSaveAndReloadSettings() {
        let first = SettingsModel()
        first.defaultLockState = true
        first.userActionThreshold = 900
        first.preferredInputSourceId = "com.apple.keylayout.ABC"
        first.addToWhitelist("com.apple.TextEdit")
        first.addToBlacklist("com.example.input")
        first.logLevel = .debug
        first.saveSettings()

        let second = SettingsModel()

        XCTAssertTrue(second.defaultLockState)
        XCTAssertEqual(second.userActionThreshold, 900)
        XCTAssertEqual(second.preferredInputSourceId, "com.apple.keylayout.ABC")
        XCTAssertTrue(second.isInWhitelist("com.apple.TextEdit"))
        XCTAssertTrue(second.isInBlacklist("com.example.input"))
        XCTAssertEqual(second.logLevel, .debug)
    }

    func testResetToDefaultsClearsCustomizedValues() {
        let settings = SettingsModel()
        settings.defaultLockState = true
        settings.userActionThreshold = 1_000
        settings.preferredInputSourceId = "custom.input"
        settings.addToWhitelist("com.apple.Terminal")
        settings.addToBlacklist("custom.blacklist")

        settings.resetToDefaults()

        XCTAssertFalse(settings.defaultLockState)
        XCTAssertEqual(settings.userActionThreshold, 500)
        XCTAssertNil(settings.preferredInputSourceId)
        XCTAssertTrue(settings.appWhitelist.isEmpty)
        XCTAssertTrue(settings.inputMethodBlacklist.isEmpty)
        XCTAssertEqual(settings.statusBarIconStyle, .adaptive)
    }
}
