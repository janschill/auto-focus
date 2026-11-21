@testable import auto_focus
import Foundation
import XCTest

#if DEBUG

final class FlowMonitorTests: XCTestCase {
    private let xcode = "com.apple.dt.Xcode"
    private let slack = "com.tinyspeck.slackmacgap"

    func testRefreshReadsTrailingWindowFromEventLog() throws {
        let repo = AppEventRepository(dbQueue: MockFactory.createTestDB())
        let now = Date()
        for index in 0..<24 {
            var event = AppEvent(bundleIdentifier: index.isMultiple(of: 2) ? slack : xcode)
            event.timestamp = now.addingTimeInterval(-590 + TimeInterval(index * 24))
            try repo.insert(event)
        }
        let monitor = FlowMonitor(appEventRepo: repo, focusContext: { FocusContext(bundleIDs: [self.xcode], urls: []) }, idleTime: { 0 })

        monitor.refresh(now: now)

        XCTAssertEqual(monitor.reading, FlowReading(state: .scattered, switches: 24))
    }

    func testRefreshPicksUpChangedFocusApps() throws {
        let repo = AppEventRepository(dbQueue: MockFactory.createTestDB())
        let now = Date()
        var event = AppEvent(bundleIdentifier: xcode)
        event.timestamp = now.addingTimeInterval(-900)
        try repo.insert(event)
        var focusBundleIDs: Set<String> = []
        let monitor = FlowMonitor(appEventRepo: repo, focusContext: { FocusContext(bundleIDs: focusBundleIDs, urls: []) }, idleTime: { 0 })

        monitor.refresh(now: now)
        XCTAssertEqual(monitor.reading.state, .neutral)

        focusBundleIDs = [xcode]
        monitor.refresh(now: now)
        XCTAssertEqual(monitor.reading.state, .flow)
    }

    func testLongStretchStartedBeforeWindowIsFlowWhilePresent() throws {
        let repo = AppEventRepository(dbQueue: MockFactory.createTestDB())
        let now = Date()
        var event = AppEvent(bundleIdentifier: xcode)
        event.timestamp = now.addingTimeInterval(-3600)
        try repo.insert(event)
        var idle: TimeInterval = 0
        let monitor = FlowMonitor(
            appEventRepo: repo,
            focusContext: { FocusContext(bundleIDs: [self.xcode], urls: []) },
            idleTime: { idle }
        )

        monitor.refresh(now: now)
        XCTAssertEqual(monitor.reading.state, .flow)

        idle = FlowMonitor.presenceIdleLimit
        monitor.refresh(now: now)
        XCTAssertEqual(monitor.reading.state, .neutral)
    }
}

#endif
