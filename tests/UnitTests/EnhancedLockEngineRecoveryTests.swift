import XCTest
@testable import Typelock

final class EnhancedLockEngineRecoveryTests: XCTestCase {
    private let settingsKey = "TypelockSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testSystemSwitchKeepsRestoreAttemptsAfterMaxConsecutiveLimit() {
        let settings = SettingsModel()
        settings.preferredInputSourceId = "locked.input"
        let engine = EnhancedLockEngine(settings: settings)
        let locked = InputSourceModel(id: "locked.input", name: "Locked")
        let autoSwitched = InputSourceModel(id: "auto.input", name: "Auto")
        engine.lockToInputSource(locked)
        engine.updateUserActionThreshold(0)

        for _ in 0..<5 {
            engine.handleInputSourceChange(autoSwitched)
        }

        XCTAssertEqual(engine.lockedInputSource?.id, locked.id)
        XCTAssertEqual(settings.preferredInputSourceId, "locked.input")
        XCTAssertEqual(engine.debugConsecutiveAutoSwitches, 5)
        XCTAssertEqual(engine.debugRestoreAttempts, 5)
    }

    func testUnlockResetsRecoveryCounters() {
        let settings = SettingsModel()
        let engine = EnhancedLockEngine(settings: settings)
        let locked = InputSourceModel(id: "locked.input", name: "Locked")
        let autoSwitched = InputSourceModel(id: "auto.input", name: "Auto")
        engine.lockToInputSource(locked)
        engine.updateUserActionThreshold(0)
        engine.handleInputSourceChange(autoSwitched)
        engine.handleInputSourceChange(autoSwitched)

        XCTAssertEqual(engine.debugConsecutiveAutoSwitches, 2)
        XCTAssertEqual(engine.debugRestoreAttempts, 2)

        engine.setLocked(false)

        XCTAssertEqual(engine.debugConsecutiveAutoSwitches, 0)
        XCTAssertEqual(engine.debugRestoreAttempts, 0)
        XCTAssertNil(engine.lockedInputSource)
    }
}
