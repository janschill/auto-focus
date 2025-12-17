import XCTest
@testable import AutoFocus2

final class FocusStateMachine_BufferTests: XCTestCase {
    func test_leavingFocusDuringActiveSession_entersBuffer_thenExitsOnTimeout() {
        let entityId = UUID()
        let machine = FocusStateMachine()
        let settings = FocusSettings(activationMinutes: 1, bufferSeconds: 10) // activation clamped to 60s
        let t0 = Date(timeIntervalSince1970: 1_000)

        _ = machine.updateContext(
            ForegroundContext(appBundleId: "com.test.app", domain: nil),
            matchedEntityId: entityId,
            settings: settings,
            now: t0
        )
        _ = machine.tick(by: 60, settings: settings, now: t0.addingTimeInterval(60))
        if case .inFocusMode = machine.state.phase { } else { XCTFail("Expected inFocusMode") }

        // Leave focus while in focus mode => buffer
        let out = machine.updateContext(
            ForegroundContext(appBundleId: "com.other", domain: nil),
            matchedEntityId: nil,
            settings: settings,
            now: t0.addingTimeInterval(61)
        )

        guard case .enteredBuffer(let until) = out else {
            return XCTFail("Expected enteredBuffer, got \(out)")
        }
        if case .buffering(_, let bufferEndsAt) = machine.state.phase {
            XCTAssertEqual(bufferEndsAt, until)
        } else {
            XCTFail("Expected buffering phase")
        }

        // Before timeout => still buffering
        let out2 = machine.tick(by: 5, settings: settings, now: t0.addingTimeInterval(66))
        XCTAssertEqual(out2, .none)

        // At/after timeout => exit focus mode
        let out3 = machine.tick(by: 5, settings: settings, now: t0.addingTimeInterval(71))
        XCTAssertEqual(out3, .exitedFocusMode)
        XCTAssertEqual(machine.state.phase, .idle)
    }

    func test_returningToFocusDuringBuffer_restoresFocusMode() {
        let entityId = UUID()
        let machine = FocusStateMachine()
        let settings = FocusSettings(activationMinutes: 1, bufferSeconds: 30)
        let t0 = Date(timeIntervalSince1970: 1_000)

        _ = machine.updateContext(
            ForegroundContext(appBundleId: "com.test.app", domain: nil),
            matchedEntityId: entityId,
            settings: settings,
            now: t0
        )
        _ = machine.tick(by: 60, settings: settings, now: t0.addingTimeInterval(60))

        _ = machine.updateContext(
            ForegroundContext(appBundleId: "com.other", domain: nil),
            matchedEntityId: nil,
            settings: settings,
            now: t0.addingTimeInterval(61)
        )
        if case .buffering = machine.state.phase { } else { XCTFail("Expected buffering") }

        // Return to focus entity => inFocusMode, no output (session preserved)
        let out = machine.updateContext(
            ForegroundContext(appBundleId: "com.test.app", domain: nil),
            matchedEntityId: entityId,
            settings: settings,
            now: t0.addingTimeInterval(62)
        )
        XCTAssertEqual(out, .none)
        if case .inFocusMode = machine.state.phase { } else { XCTFail("Expected inFocusMode") }
    }
}


