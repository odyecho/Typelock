import XCTest
@testable import Typelock

@MainActor
final class EnhancedInputSourceManagerIntegrationTests: XCTestCase {
    private let settingsKey = "TypelockSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testWhitelistedAppPausesLockingAndNonWhitelistedAppResumes() {
        let settings = SettingsModel()
        settings.addToWhitelist("com.apple.TextEdit")
        settings.autoLockOnAppSwitch = false
        let manager = EnhancedInputSourceManager(settings: settings)
        let locked = InputSourceModel(id: "locked.input", name: "Locked")
        let whitelistedApp = AppInfo(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            processIdentifier: 1,
            isActive: true
        )
        let normalApp = AppInfo(
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            processIdentifier: 2,
            isActive: true
        )

        manager.lockToInputSource(locked)
        XCTAssertTrue(manager.isLocked)
        XCTAssertFalse(manager.debugIsLockPaused)

        manager.processAppChangeForTesting(whitelistedApp)
        XCTAssertFalse(manager.isLocked)
        XCTAssertTrue(manager.debugIsLockPaused)

        manager.processAppChangeForTesting(normalApp)
        XCTAssertTrue(manager.isLocked)
        XCTAssertFalse(manager.debugIsLockPaused)
        XCTAssertEqual(manager.lockedInputSource?.id, locked.id)
    }

    func testWhitelistedAppDoesNotTriggerAutoLockToCurrent() {
        let settings = SettingsModel()
        settings.addToWhitelist("com.apple.TextEdit")
        settings.autoLockOnAppSwitch = true
        let manager = EnhancedInputSourceManager(settings: settings)
        let locked = InputSourceModel(id: "locked.input", name: "Locked")
        let whitelistedApp = AppInfo(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            processIdentifier: 3,
            isActive: true
        )

        manager.lockToInputSource(locked)
        manager.processAppChangeForTesting(whitelistedApp)

        XCTAssertTrue(manager.debugIsLockPaused)
        XCTAssertEqual(manager.lockedInputSource?.id, locked.id)
    }

    func testNonWhitelistedAppTriggersAutoLockToProvidedInputSource() {
        let settings = SettingsModel()
        settings.autoLockOnAppSwitch = true
        let manager = EnhancedInputSourceManager(settings: settings)
        let simulatedCurrent = InputSourceModel(id: "simulated.input", name: "Simulated")
        let normalApp = AppInfo(
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            processIdentifier: 4,
            isActive: true
        )

        manager.processAppChangeForTesting(normalApp, simulatedCurrentInputSource: simulatedCurrent)

        XCTAssertTrue(manager.isLocked)
        XCTAssertFalse(manager.debugIsLockPaused)
        XCTAssertEqual(manager.lockedInputSource?.id, simulatedCurrent.id)
    }

    func testSwitchFailureTriggersCallbackChain() {
        let settings = SettingsModel()
        let manager = EnhancedInputSourceManager(settings: settings)
        let missingInputSource = InputSourceModel(
            id: "com.typelock.nonexistent.\(UUID().uuidString)",
            name: "Missing"
        )
        var callbackInputSourceId: String?
        var callbackError: Error?

        manager.onSwitchFailed = { inputSource, error in
            callbackInputSourceId = inputSource.id
            callbackError = error
        }

        let switched = manager.switchToInputSource(missingInputSource)

        XCTAssertFalse(switched)
        XCTAssertEqual(callbackInputSourceId, missingInputSource.id)
        XCTAssertNotNil(callbackError)

        let typedError = callbackError as? InputSourceError
        switch typedError {
        case .inputSourceNotFound, .systemError:
            XCTAssertTrue(true)
        default:
            XCTFail("回调错误类型不符合预期: \(String(describing: callbackError))")
        }
    }
}
