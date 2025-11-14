// InsightsViewModelTests.swift
// Unit tests for InsightsViewModel

@testable import auto_focus
import XCTest

#if DEBUG

final class InsightsViewModelTests: XCTestCase {
    var mockSessionManager: MockSessionManager!
    var focusManager: FocusManager!
    var dataProvider: InsightsDataProvider!
    var viewModel: InsightsViewModel!

    override func setUp() {
        super.setUp()
        let mocks = MockFactory.createMockDependencies()
        mockSessionManager = mocks.sessionManager
        focusManager = MockFactory.createFocusManager(
            sessionManager: mockSessionManager
        )
        dataProvider = InsightsDataProvider(focusManager: focusManager)
        viewModel = InsightsViewModel(dataProvider: dataProvider)
    }

    override func tearDown() {
        mockSessionManager.reset()
        super.tearDown()
    }

    func testRelevantSessionsCount() {
        // Add two sessions for today
        let today = Date()
        let session1 = FocusSession(startTime: today.addingTimeInterval(-100), endTime: today)
        let session2 = FocusSession(startTime: today.addingTimeInterval(-200), endTime: today)
        mockSessionManager.addSampleSessions([session1, session2])
        viewModel.selectedTimeframe = .day
        viewModel.selectedDate = today
        XCTAssertEqual(viewModel.relevantSessions.count, 2)
    }
}

#endif
