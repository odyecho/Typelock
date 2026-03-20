import XCTest
@testable import Typelock

final class EnhancedLockEngineTests: XCTestCase {
    private let settingsKey = "TypelockSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testInitialStateIsUnlocked() {
        let settings = SettingsModel()
        let engine = EnhancedLockEngine(settings: settings)

        XCTAssertFalse(engine.isLocked)
        XCTAssertFalse(engine.isPaused)
        XCTAssertNil(engine.lockedInputSource)
    }

    func testLockToInputSourceUpdatesState() {
        let settings = SettingsModel()
        let engine = EnhancedLockEngine(settings: settings)
        let target = InputSourceModel(id: "com.apple.keylayout.ABC", name: "ABC")

        engine.lockToInputSource(target)

        XCTAssertTrue(engine.isLocked)
        XCTAssertEqual(engine.lockedInputSource?.id, target.id)
    }

    func testPauseAndResumeAffectsIsLocked() {
        let settings = SettingsModel()
        let engine = EnhancedLockEngine(settings: settings)
        let target = InputSourceModel(id: "com.apple.keylayout.ABC", name: "ABC")
        engine.lockToInputSource(target)

        engine.pauseLocking()
        XCTAssertFalse(engine.isLocked)
        XCTAssertTrue(engine.isPaused)

        engine.resumeLocking()
        XCTAssertTrue(engine.isLocked)
        XCTAssertFalse(engine.isPaused)
    }

    func testUserInitiatedChangeUpdatesPreferredInputSource() {
        let settings = SettingsModel()
        let engine = EnhancedLockEngine(settings: settings)
        let initial = InputSourceModel(id: "com.apple.keylayout.ABC", name: "ABC")
        let changed = InputSourceModel(id: "com.apple.inputmethod.SCIM.ITABC", name: "简体中文")
        engine.lockToInputSource(initial)
        engine.markUserInitiatedSwitch(to: changed)

        engine.handleInputSourceChange(changed)

        XCTAssertEqual(engine.lockedInputSource?.id, changed.id)
        XCTAssertEqual(settings.preferredInputSourceId, changed.id)
    }
}
