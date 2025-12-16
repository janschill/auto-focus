//
//  TestHelpers.swift
//  auto-focusTests
//
//  Test utilities and helpers for common test scenarios
//

import Foundation
import XCTest
@testable import auto_focus

#if DEBUG

// MARK: - Test Data Builders

struct TestDataBuilder {
    /// Creates a test FocusSession with default or custom values
    static func createFocusSession(
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil
    ) -> FocusSession {
        let finalEndTime = endTime ?? startTime.addingTimeInterval(duration ?? 3600)
        return FocusSession(startTime: startTime, endTime: finalEndTime)
    }

    /// Creates multiple test sessions for a given day
    static func createSessionsForDay(
        date: Date = Date(),
        count: Int = 3,
        duration: TimeInterval = 3600
    ) -> [FocusSession] {
        var sessions: [FocusSession] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        for i in 0..<count {
            let startTime = startOfDay.addingTimeInterval(Double(i) * duration * 1.5)
            let endTime = startTime.addingTimeInterval(duration)
            sessions.append(FocusSession(startTime: startTime, endTime: endTime))
        }

        return sessions
    }

    /// Creates test AppInfo
    static func createAppInfo(
        id: String = UUID().uuidString,
        name: String = "TestApp",
        bundleIdentifier: String = "com.test.app"
    ) -> AppInfo {
        return AppInfo(id: id, name: name, bundleIdentifier: bundleIdentifier)
    }
}

// MARK: - Test Assertions

extension XCTestCase {
    /// Asserts that two dates are equal within a tolerance
    func XCTAssertEqualDates(
        _ date1: Date?,
        _ date2: Date?,
        tolerance: TimeInterval = 1.0,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let date1 = date1, let date2 = date2 else {
            XCTFail("One or both dates are nil. \(message())", file: file, line: line)
            return
        }

        let difference = abs(date1.timeIntervalSince(date2))
        XCTAssertTrue(
            difference <= tolerance,
            "Dates differ by \(difference) seconds, which exceeds tolerance of \(tolerance) seconds. \(message())",
            file: file,
            line: line
        )
    }

    /// Asserts that a time interval is within expected range
    func XCTAssertTimeInterval(
        _ interval: TimeInterval,
        isBetween min: TimeInterval,
        and max: TimeInterval,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            interval >= min && interval <= max,
            "Time interval \(interval) is not between \(min) and \(max). \(message())",
            file: file,
            line: line
        )
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {
    /// Waits for a condition to become true with timeout
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool,
        description: String = "Condition not met"
    ) async throws {
        let startTime = Date()
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                XCTFail("Timeout waiting for condition: \(description)")
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
}

// MARK: - Mock Factory

struct MockFactory {
    /// Creates a complete set of mock dependencies for testing
    static func createMockDependencies() -> (
        persistence: MockPersistenceManager,
        sessionManager: MockSessionManager,
        appMonitor: MockAppMonitor,
        bufferManager: MockBufferManager,
        focusModeManager: MockFocusModeManager
    ) {
        return (
            persistence: MockPersistenceManager(),
            sessionManager: MockSessionManager(),
            appMonitor: MockAppMonitor(),
            bufferManager: MockBufferManager(),
            focusModeManager: MockFocusModeManager()
        )
    }

    /// Creates a FocusManager with mock dependencies
    static func createFocusManager(
        persistence: MockPersistenceManager? = nil,
        sessionManager: MockSessionManager? = nil,
        appMonitor: MockAppMonitor? = nil,
        bufferManager: MockBufferManager? = nil,
        focusModeManager: MockFocusModeManager? = nil
    ) -> FocusManager {
        let mocks = createMockDependencies()
        return FocusManager(
            userDefaultsManager: persistence ?? mocks.persistence,
            sessionManager: sessionManager ?? mocks.sessionManager,
            appMonitor: appMonitor ?? mocks.appMonitor,
            bufferManager: bufferManager ?? mocks.bufferManager,
            focusModeController: focusModeManager ?? mocks.focusModeManager
        )
    }
}

// MARK: - Date Helpers

extension Date {
    /// Returns a date at the start of today
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Returns a date N days ago
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    /// Returns a date N hours ago
    static func hoursAgo(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
    }

    /// Returns a date N minutes ago
    static func minutesAgo(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -minutes, to: Date()) ?? Date()
    }
}

#endif

