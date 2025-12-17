import XCTest
@testable import AutoFocus2

final class FocusStateMachine_CountdownResetTests: XCTestCase {
    func test_leavingFocusDuringCountdown_resetsToIdle() {
        let entityId = UUID()
        let machine = FocusStateMachine()
        let settings = FocusSettings(activationMinutes: 5, bufferSeconds: 30)
        let t0 = Date(timeIntervalSince1970: 1_000)

        _ = machine.updateContext(
            ForegroundContext(appBundleId: "com.test.app", domain: nil),
            matchedEntityId: entityId,
            settings: settings,
            now: t0
        )
        XCTAssertEqual(machine.state.phase, .counting(secondsAccumulated: 0))

        _ = machine.tick(by: 20, settings: settings, now: t0.addingTimeInterval(20))
        XCTAssertEqual(machine.state.phase, .counting(secondsAccumulated: 20))

        // Leave focus entities.
        _ = machine.updateContext(
            ForegroundContext(appBundleId: "com.other.app", domain: nil),
            matchedEntityId: nil,
            settings: settings,
            now: t0.addingTimeInterval(21)
        )

        XCTAssertEqual(machine.state.phase, .idle)
        XCTAssertNil(machine.state.currentEntityId)
    }
}


