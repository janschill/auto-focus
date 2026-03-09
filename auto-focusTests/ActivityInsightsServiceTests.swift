import Foundation
import XCTest
@testable import auto_focus

#if DEBUG

final class ActivityInsightsServiceTests: XCTestCase {

    // MARK: - Empty events

    func testEmptyEventsReturnsZeroDisruptions() {
        let result = ActivityInsightsService.calculateDisruptions(
            events: [],
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 0)
        XCTAssertTrue(result.distractors.isEmpty)
    }

    func testSingleEventReturnsZeroDisruptions() {
        let event = makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode")
        let result = ActivityInsightsService.calculateDisruptions(
            events: [event],
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 0)
    }

    // MARK: - Focus to non-focus = disruption

    func testFocusToNonFocusCountsAsDisruption() {
        let events = [
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode"),
            makeAppEvent(bundleId: "com.apple.Messages", appName: "Messages", offset: 10)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 1)
        XCTAssertEqual(result.distractors.count, 1)
        XCTAssertEqual(result.distractors[0].name, "Messages")
        XCTAssertEqual(result.distractors[0].count, 1)
    }

    // MARK: - Multiple disruptions to same app aggregate

    func testMultipleDisruptionsToSameAppAggregate() {
        let events = [
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode"),
            makeAppEvent(bundleId: "com.apple.Messages", appName: "Messages", offset: 10),
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode", offset: 20),
            makeAppEvent(bundleId: "com.apple.Messages", appName: "Messages", offset: 30)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 2)
        XCTAssertEqual(result.distractors.count, 1)
        XCTAssertEqual(result.distractors[0].name, "Messages")
        XCTAssertEqual(result.distractors[0].count, 2)
    }

    // MARK: - Browser tab change within focus URLs is not a disruption

    func testBrowserTabChangeWithinFocusURLsIsNotDisruption() {
        let focusURL = FocusURL(name: "GitHub", domain: "github.com", category: .development)
        let events = [
            makeBrowserEvent(domain: "github.com", offset: 0),
            makeBrowserEvent(domain: "github.com", offset: 10)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: [],
            focusDomains: [focusURL]
        )
        XCTAssertEqual(result.totalSwitches, 0)
    }

    // MARK: - Non-focus to non-focus is not a disruption

    func testNonFocusToNonFocusIsNotDisruption() {
        let events = [
            makeAppEvent(bundleId: "com.apple.Messages", appName: "Messages"),
            makeAppEvent(bundleId: "com.apple.Mail", appName: "Mail", offset: 10)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 0)
    }

    // MARK: - Focus URL to non-focus domain is a disruption

    func testFocusDomainToNonFocusDomainIsDisruption() {
        let focusURL = FocusURL(name: "GitHub", domain: "github.com", category: .development)
        let events = [
            makeBrowserEvent(domain: "github.com", offset: 0),
            makeBrowserEvent(domain: "twitter.com", offset: 10)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: [],
            focusDomains: [focusURL]
        )
        XCTAssertEqual(result.totalSwitches, 1)
        XCTAssertEqual(result.distractors[0].name, "twitter.com")
    }

    // MARK: - Distractors sorted by count descending

    func testDistractorsSortedByCountDescending() {
        let events = [
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode"),
            makeAppEvent(bundleId: "com.apple.Mail", appName: "Mail", offset: 10),
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode", offset: 20),
            makeAppEvent(bundleId: "com.apple.Messages", appName: "Messages", offset: 30),
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode", offset: 40),
            makeAppEvent(bundleId: "com.apple.Mail", appName: "Mail", offset: 50),
            makeAppEvent(bundleId: "com.apple.Xcode", appName: "Xcode", offset: 60),
            makeAppEvent(bundleId: "com.apple.Slack", appName: "Slack", offset: 70)
        ]
        let result = ActivityInsightsService.calculateDisruptions(
            events: events,
            focusBundleIDs: ["com.apple.Xcode"],
            focusDomains: []
        )
        XCTAssertEqual(result.totalSwitches, 4)
        XCTAssertEqual(result.distractors[0].name, "Mail")
        XCTAssertEqual(result.distractors[0].count, 2)
    }

    // MARK: - Helpers

    private let baseDate = Date()

    private func makeAppEvent(bundleId: String, appName: String, offset: TimeInterval = 0) -> AppEvent {
        var event = AppEvent(bundleIdentifier: bundleId, appName: appName)
        event.timestamp = baseDate.addingTimeInterval(offset)
        return event
    }

    private func makeBrowserEvent(domain: String, offset: TimeInterval = 0) -> AppEvent {
        var event = AppEvent(
            bundleIdentifier: "com.google.Chrome",
            appName: nil,
            url: "https://\(domain)/page",
            domain: domain
        )
        event.timestamp = baseDate.addingTimeInterval(offset)
        return event
    }
}

#endif
