// ProductiveTimeRangeTests.swift
// Verifies hourly bucketing for the productive time range, including sessions crossing midnight.

@testable import auto_focus
import XCTest

#if DEBUG

final class ProductiveTimeRangeTests: XCTestCase {
    var mockSessionManager: MockSessionManager!
    var dataProvider: InsightsDataProvider!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockSessionManager = mocks.sessionManager
        let focusManager = MockFactory.createFocusManager(sessionManager: mockSessionManager)
        dataProvider = InsightsDataProvider(
            focusManager: focusManager,
            appEventRepo: AppEventRepository(dbQueue: MockFactory.createTestDB())
        )
    }

    override func tearDown() {
        mockSessionManager.reset()
        super.tearDown()
    }

    private func date(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    func testSessionCrossingMidnightSplitsAcrossHours() throws {
        let session = FocusSession(
            startTime: date(dayOffset: -2, hour: 23, minute: 30),
            endTime: date(dayOffset: -1, hour: 0, minute: 30)
        )
        mockSessionManager.addSampleSessions([session])

        let range = try XCTUnwrap(dataProvider.calculateProductiveTimeRange())

        XCTAssertEqual(range.startHour, 23)
        XCTAssertEqual(range.endHour, 24)
        XCTAssertEqual(range.duration, 3600, accuracy: 1, "23:30–00:30 is one hour total, not ~24.5h")
    }

    func testSessionWithinSingleHour() throws {
        let session = FocusSession(
            startTime: date(dayOffset: -1, hour: 10, minute: 0),
            endTime: date(dayOffset: -1, hour: 10, minute: 45)
        )
        mockSessionManager.addSampleSessions([session])

        let range = try XCTUnwrap(dataProvider.calculateProductiveTimeRange())

        XCTAssertEqual(range.startHour, 9, "First max window containing hour 10 is 9–10")
        XCTAssertEqual(range.duration, 45 * 60, accuracy: 1)
    }

    func testSessionSpanningSeveralHoursBucketsFullHours() throws {
        let session = FocusSession(
            startTime: date(dayOffset: -1, hour: 13, minute: 30),
            endTime: date(dayOffset: -1, hour: 16, minute: 15)
        )
        mockSessionManager.addSampleSessions([session])

        let range = try XCTUnwrap(dataProvider.calculateProductiveTimeRange())

        XCTAssertEqual(range.startHour, 14)
        XCTAssertEqual(range.duration, 2 * 3600, accuracy: 1)
    }

    func testNoSessionsReturnsNil() {
        XCTAssertNil(dataProvider.calculateProductiveTimeRange())
    }
}

#endif
