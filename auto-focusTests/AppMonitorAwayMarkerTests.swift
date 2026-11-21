import AppKit
@testable import auto_focus
import XCTest

#if DEBUG

final class AppMonitorAwayMarkerTests: XCTestCase {
    private var repo: AppEventRepository!
    private var monitor: AppMonitor!

    override func setUp() {
        super.setUp()
        repo = AppEventRepository(dbQueue: MockFactory.createTestDB())
        monitor = AppMonitor(appEventRepo: repo)
        monitor.startMonitoring()
    }

    override func tearDown() {
        monitor.stopMonitoring()
        monitor = nil
        super.tearDown()
    }

    func testLockAndSleepBurstRecordsOneAwayMarker() throws {
        postSleep()
        postSleep()

        XCTAssertEqual(try awayMarkerCount(), 1)
    }

    func testReturningRecordsFrontmostAppAndRearmsMarker() throws {
        let activationsBefore = try events().filter { $0.eventType == "activate" }.count
        postSleep()

        monitor.refresh()
        postSleep()

        XCTAssertEqual(try events().filter { $0.eventType == "activate" }.count, activationsBefore + 1)
        XCTAssertEqual(try awayMarkerCount(), 2)
    }

    private func postSleep() {
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    }

    private func events() throws -> [AppEvent] {
        try repo.fetchEvents(since: .distantPast, until: .distantFuture)
    }

    private func awayMarkerCount() throws -> Int {
        try events().filter { $0.eventType == "away" }.count
    }
}

#endif
