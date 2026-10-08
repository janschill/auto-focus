// InsightsViewModelTests.swift
// Unit tests for InsightsViewModel snapshot computation and recompute triggers.

@testable import auto_focus
import Combine
import XCTest

#if DEBUG

final class InsightsViewModelTests: XCTestCase {
    var mockSessionManager: MockSessionManager!
    var focusManager: FocusManager!
    var appEventRepo: AppEventRepository!
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockSessionManager = mocks.sessionManager
        focusManager = MockFactory.createFocusManager(
            sessionManager: mockSessionManager
        )
        appEventRepo = AppEventRepository(dbQueue: MockFactory.createTestDB())
    }

    override func tearDown() {
        cancellables.removeAll()
        mockSessionManager.reset()
        super.tearDown()
    }

    private func makeViewModel() -> InsightsViewModel {
        InsightsViewModel(dataProvider: InsightsDataProvider(focusManager: focusManager, appEventRepo: appEventRepo))
    }

    private func todaySession(hour: Int, minutes: Int) -> FocusSession {
        let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return FocusSession(startTime: start, endTime: start.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func testRelevantSessionsCount() {
        let viewModel = makeViewModel()
        let today = Date()
        let session1 = FocusSession(startTime: today.addingTimeInterval(-100), endTime: today)
        let session2 = FocusSession(startTime: today.addingTimeInterval(-200), endTime: today)
        mockSessionManager.addSampleSessions([session1, session2])
        viewModel.selectedTimeframe = .day
        viewModel.selectedDate = today
        XCTAssertEqual(viewModel.snapshot.sessionCount, 2)
    }

    func testSnapshotComputesSessionMetrics() {
        mockSessionManager.addSampleSessions([
            todaySession(hour: 0, minutes: 30),
            todaySession(hour: 1, minutes: 10)
        ])
        let snapshot = makeViewModel().snapshot

        XCTAssertEqual(snapshot.sessionCount, 2)
        XCTAssertEqual(snapshot.totalFocusTime, 40 * 60)
        XCTAssertEqual(snapshot.longestSession?.duration, 30 * 60)
        XCTAssertEqual(snapshot.averageSessionLength, 20 * 60)
        XCTAssertEqual(snapshot.deepFocusSessions.deep, 1)
        XCTAssertEqual(snapshot.deepFocusSessions.total, 2)
        XCTAssertEqual(snapshot.displayedDateString, "Today")
        XCTAssertEqual(snapshot.weekdayAverages.count, 7)
        XCTAssertNotNil(snapshot.productiveTimeRange)
    }

    func testRefreshWithoutInputChangeDoesNotPublish() {
        let viewModel = makeViewModel()
        var publishCount = 0
        viewModel.$snapshot.dropFirst().sink { _ in publishCount += 1 }.store(in: &cancellables)

        viewModel.refresh()
        viewModel.refresh()

        XCTAssertEqual(publishCount, 0)
    }

    func testTimeframeChangeRecomputesSnapshot() {
        let viewModel = makeViewModel()
        var publishCount = 0
        viewModel.$snapshot.dropFirst().sink { _ in publishCount += 1 }.store(in: &cancellables)

        viewModel.selectedTimeframe = .week

        XCTAssertEqual(publishCount, 1)
        XCTAssertNotEqual(viewModel.snapshot.displayedDateString, "Today")
    }

    func testTimerTickDoesNotRecomputeSnapshot() {
        let viewModel = makeViewModel()
        viewModel.startObserving()
        let recomputed = expectation(description: "snapshot recomputed")
        recomputed.isInverted = true
        viewModel.$snapshot.dropFirst().sink { _ in recomputed.fulfill() }.store(in: &cancellables)

        focusManager.timeSpent += 1
        focusManager.timeSpent += 1

        wait(for: [recomputed], timeout: 0.3)
    }

    func testSessionChangeRecomputesSnapshotWhileObserving() {
        let viewModel = makeViewModel()
        viewModel.startObserving()
        XCTAssertEqual(viewModel.snapshot.sessionCount, 0)

        let recomputed = expectation(description: "snapshot recomputed")
        viewModel.$snapshot.dropFirst().sink { snapshot in
            XCTAssertEqual(snapshot.sessionCount, 1)
            recomputed.fulfill()
        }.store(in: &cancellables)

        mockSessionManager.addSampleSessions([todaySession(hour: 0, minutes: 5)])
        focusManager.timeSpent += 1

        wait(for: [recomputed], timeout: 1)
    }

    func testStopObservingIgnoresFocusManagerChanges() {
        let viewModel = makeViewModel()
        viewModel.startObserving()
        viewModel.stopObserving()

        let recomputed = expectation(description: "snapshot recomputed")
        recomputed.isInverted = true
        viewModel.$snapshot.dropFirst().sink { _ in recomputed.fulfill() }.store(in: &cancellables)

        mockSessionManager.addSampleSessions([todaySession(hour: 0, minutes: 5)])
        focusManager.timeSpent += 1

        wait(for: [recomputed], timeout: 0.3)
    }

    func testActivityComesFromAppEvents() throws {
        let start = Calendar.current.startOfDay(for: Date())
        // Durations are the gaps to the next event: one = 900s, two = 300s, last event open-ended.
        let events: [(bundleID: String, offset: TimeInterval)] = [
            ("com.example.one", 0), ("com.example.two", 900), ("com.example.one", 1200)
        ]
        for item in events {
            var event = AppEvent(bundleIdentifier: item.bundleID, appName: item.bundleID)
            event.timestamp = start.addingTimeInterval(item.offset)
            try appEventRepo.insert(event)
        }

        let snapshot = makeViewModel().snapshot

        XCTAssertEqual(snapshot.activity.otherApps.map(\.bundleIdentifier), ["com.example.one", "com.example.two"])
        XCTAssertEqual(snapshot.activity.totalAppDuration, 1200)
        XCTAssertEqual(snapshot.otherDuration, 1200)
        XCTAssertEqual(snapshot.focusDuration, 0)
    }
}

#endif
