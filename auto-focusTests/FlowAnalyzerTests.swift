@testable import auto_focus
import Foundation
import XCTest

#if DEBUG

final class FlowAnalyzerTests: XCTestCase {
    private let xcode = "com.apple.dt.Xcode"
    private let ghostty = "com.mitchellh.ghostty"
    private let slack = "com.tinyspeck.slackmacgap"
    private let chrome = "com.google.Chrome"
    private let baseDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var context: FocusContext {
        FocusContext(bundleIDs: [xcode, ghostty], urls: [FocusURL(name: "GitHub", domain: "github.com")])
    }

    // MARK: - Classification

    func testClassify() {
        let cases: [(name: String, switches: Int, share: Double, expected: FlowState)] = [
            ("few switches, almost all focus", 2, 0.95, .flow),
            ("flow boundary", 6, 0.8, .flow),
            ("one switch too many for flow", 7, 0.9, .focused),
            ("mostly focus", 10, 0.6, .focused),
            ("rapid switching even inside focus apps", 20, 1.0, .scattered),
            ("rapid switching outside focus", 30, 0.1, .scattered),
            ("calm but outside focus", 3, 0.2, .neutral)
        ]
        for testCase in cases {
            XCTAssertEqual(
                FlowAnalyzer.classify(switches: testCase.switches, focusShare: testCase.share),
                testCase.expected,
                testCase.name
            )
        }
    }

    // MARK: - Spans

    func testBrowserActivationInheritsLastDomainOfThatBrowser() {
        let events = [
            tabEvent(domain: "github.com", at: 0),
            appEvent(slack, at: 60),
            appEvent(chrome, at: 120)
        ]

        let spans = FlowAnalyzer.spans(events: events, context: context, until: date(180))

        XCTAssertEqual(spans.map(\.isFocus), [true, false, true])
    }

    func testBrowserActivationWithoutKnownDomainIsNotFocus() {
        let spans = FlowAnalyzer.spans(events: [appEvent(chrome, at: 0)], context: context, until: date(60))

        XCTAssertEqual(spans.map(\.isFocus), [false])
    }

    func testLongSpanWithoutActivityIsDropped() {
        let events = [appEvent(xcode, at: 0), appEvent(slack, at: 3 * 3600)]

        let spans = FlowAnalyzer.spans(events: events, context: context, until: date(3 * 3600 + 60))

        XCTAssertEqual(spans.map(\.duration), [60])
    }

    func testOngoingLongSpanIsKeptWhenRequested() {
        let spans = FlowAnalyzer.spans(events: [appEvent(xcode, at: 0)], context: context, until: date(3600), keepOngoingSpan: true)

        XCTAssertEqual(spans.map(\.duration), [3600])
    }

    func testAwayMarkerEndsSpanAndIsNotASwitch() {
        var away = AppEvent.awayMarker()
        away.timestamp = date(300)
        let events = [appEvent(xcode, at: 0), away, appEvent(xcode, at: 360)]

        let reading = FlowAnalyzer.currentReading(events: events, context: context, now: date(600), userIsPresent: true)

        XCTAssertEqual(reading, FlowReading(state: .flow, switches: 2))
        XCTAssertEqual(FlowAnalyzer.spans(events: events, context: context, until: date(600)).map(\.duration), [300, 240])
    }

    func testScreenInactiveEventsProduceNoSpan() {
        let events = [appEvent(xcode, at: 0), appEvent("com.apple.loginwindow", at: 60), appEvent(xcode, at: 600)]

        let spans = FlowAnalyzer.spans(events: events, context: context, until: date(660))

        XCTAssertEqual(spans.map(\.duration), [60, 60])
    }

    // MARK: - Summary

    func testCalmFocusWorkCountsAsFlow() {
        // 30 minutes alternating Xcode and Ghostty every 10 minutes
        let events = [appEvent(xcode, at: 0), appEvent(ghostty, at: 600), appEvent(xcode, at: 1200)]

        let summary = FlowAnalyzer.summary(events: events, context: context, from: date(0), to: date(1800))

        XCTAssertEqual(summary.flowTime, 1800)
        XCTAssertEqual(summary.scatteredTime, 0)
    }

    func testRapidSwitchingCountsAsScattered() {
        // 10 minutes bouncing between Ghostty and Slack every 20 seconds
        let events = (0..<30).map { appEvent($0.isMultiple(of: 2) ? ghostty : slack, at: TimeInterval($0 * 20)) }

        let summary = FlowAnalyzer.summary(events: events, context: context, from: date(0), to: date(600))

        XCTAssertEqual(summary.scatteredTime, 600)
        XCTAssertEqual(summary.flowTime, 0)
    }

    func testWindowsWithTooLittleActivityAreIgnored() {
        let events = [appEvent(xcode, at: 0)]

        let summary = FlowAnalyzer.summary(events: events, context: context, from: date(0), to: date(120))

        XCTAssertEqual(summary.flowTime + summary.focusedTime + summary.scatteredTime, 0)
    }

    func testLongestFocusStretchSpansFocusAppsAndIgnoresBlips() {
        let events = [
            appEvent(xcode, at: 0),
            appEvent(ghostty, at: 300),
            appEvent("com.apple.dock", at: 600), // 2s blip does not break the stretch
            appEvent(xcode, at: 602),
            appEvent(slack, at: 900), // a real visit breaks it
            appEvent(xcode, at: 960)
        ]

        let summary = FlowAnalyzer.summary(events: events, context: context, from: date(0), to: date(1020))

        XCTAssertEqual(summary.longestFocusStretch, 898)
    }

    // MARK: - Live state

    func testCurrentStateLooksAtTrailingWindow() {
        // Calm Xcode work long ago, then rapid switching in the last 10 minutes
        var events = [appEvent(xcode, at: 0)]
        events += (0..<25).map { appEvent($0.isMultiple(of: 2) ? slack : xcode, at: 1200 + TimeInterval($0 * 24)) }

        XCTAssertEqual(
            FlowAnalyzer.currentReading(events: events, context: context, now: date(1800), userIsPresent: true),
            FlowReading(state: .scattered, switches: 25)
        )
        XCTAssertEqual(
            FlowAnalyzer.currentReading(events: events, context: context, now: date(900), userIsPresent: true),
            FlowReading(state: .flow, switches: 0)
        )
    }

    func testCurrentStateCountsContextStartedBeforeWindow() {
        let events = [appEvent(xcode, at: 0)]

        XCTAssertEqual(FlowAnalyzer.currentReading(events: events, context: context, now: date(1500), userIsPresent: true).state, .flow)
    }

    func testCurrentStateCreditsLongStretchOnlyWhilePresent() {
        let events = [appEvent(xcode, at: 0)]

        XCTAssertEqual(FlowAnalyzer.currentReading(events: events, context: context, now: date(3600), userIsPresent: true).state, .flow)
        XCTAssertEqual(FlowAnalyzer.currentReading(events: events, context: context, now: date(3600), userIsPresent: false).state, .neutral)
    }

    // MARK: - Helpers

    private func date(_ offset: TimeInterval) -> Date {
        baseDate.addingTimeInterval(offset)
    }

    private func appEvent(_ bundleId: String, at offset: TimeInterval) -> AppEvent {
        var event = AppEvent(bundleIdentifier: bundleId)
        event.timestamp = date(offset)
        return event
    }

    private func tabEvent(domain: String, at offset: TimeInterval) -> AppEvent {
        var event = AppEvent(bundleIdentifier: chrome, url: "https://\(domain)/", domain: domain)
        event.timestamp = date(offset)
        return event
    }
}

#endif
