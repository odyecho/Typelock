import XCTest
@testable import Typelock

final class AppStateManagerTests: XCTestCase {
    private let settingsKey = "TypelockSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testIsAppWhitelistedReflectsSettings() {
        let settings = SettingsModel()
        settings.addToWhitelist("com.apple.TextEdit")
        let manager = AppStateManager(settings: settings)

        XCTAssertTrue(manager.isAppWhitelisted("com.apple.TextEdit"))
        XCTAssertFalse(manager.isAppWhitelisted("com.apple.Safari"))
        manager.cleanup()
    }
}
