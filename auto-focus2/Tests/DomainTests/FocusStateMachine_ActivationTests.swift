import XCTest
@testable import AutoFocus2

final class FocusStateMachine_ActivationTests: XCTestCase {
    func test_activation_reachesThreshold_entersFocusMode() {
        let entityId = UUID()
        let machine = FocusStateMachine()
        let settings = FocusSettings(activationMinutes: 1, bufferSeconds: 30) // clamped to >= 60s
        let t0 = Date(timeIntervalSince1970: 1_000)

        let out1 = machine.updateContext(
            ForegroundContext(appBundleId: "com.test.app", domain: nil),
            matchedEntityId: entityId,
            settings: settings,
            now: t0
        )
        XCTAssertEqual(out1, .enteredCounting)

        let out2 = machine.tick(by: 59, settings: settings, now: t0.addingTimeInterval(59))
        XCTAssertEqual(out2, .none)

        let out3 = machine.tick(by: 1, settings: settings, now: t0.addingTimeInterval(60))
        switch out3 {
        case .enteredFocusMode:
            break
        default:
            XCTFail("Expected enteredFocusMode, got \(out3)")
        }

        if case .inFocusMode = machine.state.phase {
            // ok
        } else {
            XCTFail("Expected inFocusMode phase, got \(machine.state.phase)")
        }
    }
}


