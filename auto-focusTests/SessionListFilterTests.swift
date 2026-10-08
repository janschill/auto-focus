// SessionListFilterTests.swift
// Verifies duration filtering and sort order of the session list.

@testable import auto_focus
import XCTest

#if DEBUG

final class SessionListFilterTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func session(startOffset: TimeInterval, duration: TimeInterval) -> FocusSession {
        let start = base.addingTimeInterval(startOffset)
        return FocusSession(startTime: start, endTime: start.addingTimeInterval(duration))
    }

    func testFilterAndSort() {
        let veryShort = session(startOffset: 0, duration: 30)
        let short = session(startOffset: 100, duration: 5 * 60)
        let medium = session(startOffset: 200, duration: 30 * 60)
        let long = session(startOffset: 300, duration: 2 * 3600)
        let sessions = [medium, veryShort, long, short]

        let cases: [(filter: SessionDurationFilter, sort: SessionSortOrder, expected: [FocusSession])] = [
            (.all, .newest, [long, medium, short, veryShort]),
            (.all, .oldest, [veryShort, short, medium, long]),
            (.all, .shortest, [veryShort, short, medium, long]),
            (.all, .longest, [long, medium, short, veryShort]),
            (.veryShort, .newest, [veryShort]),
            (.short, .newest, [short]),
            (.medium, .newest, [medium]),
            (.long, .newest, [long])
        ]

        for testCase in cases {
            XCTAssertEqual(
                SessionListView.filterAndSort(sessions, filter: testCase.filter, sortOrder: testCase.sort),
                testCase.expected,
                "\(testCase.filter) / \(testCase.sort)"
            )
        }
    }
}

#endif
