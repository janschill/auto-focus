// FocusModeManagerTests.swift
// Tests that Do Not Disturb is set explicitly and only turned off when Auto-Focus turned it on.

@testable import auto_focus
import XCTest

#if DEBUG

private struct ShortcutFailure: Error {}

private final class FakeShortcutRunner: ShortcutRunning {
    var installedShortcuts: [String] = [AppConfiguration.shortcutName]
    var outputs: [String: [String]] = [
        AppConfiguration.shortcutInputOn: [AppConfiguration.shortcutOutputEnabled],
        AppConfiguration.shortcutInputOff: [AppConfiguration.shortcutOutputDisabled]
    ]
    var failingInputs: Set<String> = []
    var failsListing = false
    private(set) var runs: [(name: String, input: String)] = []

    func listShortcuts() throws -> [String] {
        if failsListing { throw ShortcutFailure() }
        return installedShortcuts
    }

    func runShortcut(named name: String, input: String) throws -> String {
        runs.append((name, input))
        if failingInputs.contains(input) { throw ShortcutFailure() }
        // Replies are consumed in order; the last one repeats.
        guard var replies = outputs[input], let reply = replies.first else { return "" }
        if replies.count > 1 {
            replies.removeFirst()
            outputs[input] = replies
        }
        return reply
    }
}

private final class RecordingDelegate: FocusModeManagerDelegate {
    var onError: ((FocusModeError) -> Void)?

    func focusModeController(_ controller: any FocusModeControlling, didFailWithError error: FocusModeError) {
        onError?(error)
    }
}

final class FocusModeManagerTests: XCTestCase {
    private var runner: FakeShortcutRunner!
    private var manager: FocusModeManager!

    override func setUp() {
        super.setUp()
        runner = FakeShortcutRunner()
        manager = FocusModeManager(shortcuts: runner)
    }

    private var inputs: [String] {
        runner.runs.map(\.input)
    }

    func testEnableThenDisableRunsShortcutWithExplicitInputs() {
        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "off"])
        XCTAssertTrue(runner.runs.allSatisfy { $0.name == AppConfiguration.shortcutName })
    }

    func testDisableWithoutEnableDoesNotRunShortcut() {
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertTrue(runner.runs.isEmpty)
    }

    func testFocusTheUserAlreadyEnabledIsLeftOn() {
        runner.outputs[AppConfiguration.shortcutInputOn] = [AppConfiguration.shortcutOutputAlreadyActive]

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on"])
    }

    func testRepeatedEnableKeepsOwnership() {
        runner.outputs[AppConfiguration.shortcutInputOn] = [
            AppConfiguration.shortcutOutputEnabled,
            AppConfiguration.shortcutOutputAlreadyActive
        ]

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "on", "off"])
    }

    func testMissingShortcutClaimsNoOwnership() {
        runner.installedShortcuts = []
        runner.failingInputs = [AppConfiguration.shortcutInputOn]
        let delegate = RecordingDelegate()
        manager.delegate = delegate
        let reported = expectation(description: "not found reported")
        delegate.onError = { error in
            if case .shortcutNotFound = error { reported.fulfill() }
        }

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on"])
        wait(for: [reported], timeout: 1.0)
    }

    func testUnexpectedOutputIsReportedAndCleanedUpLater() {
        runner.outputs[AppConfiguration.shortcutInputOn] = [AppConfiguration.shortcutOutputDisabled]
        let delegate = RecordingDelegate()
        manager.delegate = delegate
        let reported = expectation(description: "unexpected output reported")
        delegate.onError = { error in
            if case .shortcutFailed = error { reported.fulfill() }
        }

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "off"])
        wait(for: [reported], timeout: 1.0)
    }

    func testRepeatedDisableRunsShortcutOnce() {
        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "off"])
    }

    func testFailedEnableStillTurnsOffLater() {
        runner.failingInputs = [AppConfiguration.shortcutInputOn]

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "off"])
    }

    func testFailedDisableIsRetried() {
        runner.failingInputs = [AppConfiguration.shortcutInputOff]

        manager.setFocusMode(enabled: true)
        manager.setFocusMode(enabled: false)
        manager.setFocusMode(enabled: false)
        manager.waitUntilIdle()

        XCTAssertEqual(inputs, ["on", "off", "off"])
    }

    func testShortcutFailureIsReportedToDelegate() {
        runner.failingInputs = [AppConfiguration.shortcutInputOn]
        let delegate = RecordingDelegate()
        manager.delegate = delegate
        let reported = expectation(description: "error reported")
        delegate.onError = { error in
            XCTAssertTrue(Thread.isMainThread)
            if case .shortcutFailed = error { reported.fulfill() }
        }

        manager.setFocusMode(enabled: true)

        wait(for: [reported], timeout: 1.0)
    }

    func testCheckShortcutExists() {
        let cases: [(name: String, installed: [String], failsListing: Bool, expected: Bool)] = [
            ("installed", [AppConfiguration.shortcutName, "Other"], false, true),
            ("not installed", ["Toggle Do Not Disturb"], false, false),
            ("listing fails", [AppConfiguration.shortcutName], true, false)
        ]

        for testCase in cases {
            runner.installedShortcuts = testCase.installed
            runner.failsListing = testCase.failsListing
            XCTAssertEqual(manager.checkShortcutExists(), testCase.expected, testCase.name)
        }
    }
}

#endif
