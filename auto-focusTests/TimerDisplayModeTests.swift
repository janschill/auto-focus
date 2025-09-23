// TimerDisplayModeTests.swift
// Unit tests for TimerDisplayMode enum

@testable import auto_focus
import XCTest

#if DEBUG

final class TimerDisplayModeTests: XCTestCase {
    
    func testTimerDisplayModeDisplayNames() {
        XCTAssertEqual(TimerDisplayMode.hidden.displayName, "Hidden")
        XCTAssertEqual(TimerDisplayMode.full.displayName, "Full (00:00)")
        XCTAssertEqual(TimerDisplayMode.simplified.displayName, "Simplified (0m)")
    }
    
    func testTimerDisplayModeDescriptions() {
        XCTAssertEqual(TimerDisplayMode.hidden.description, "Don't show timer in menu bar")
        XCTAssertEqual(TimerDisplayMode.full.description, "Show timer with seconds (e.g. 12:34)")
        XCTAssertEqual(TimerDisplayMode.simplified.description, "Show timer in minutes only (e.g. 12m)")
    }
    
    func testTimerDisplayModeRawValues() {
        XCTAssertEqual(TimerDisplayMode.hidden.rawValue, "hidden")
        XCTAssertEqual(TimerDisplayMode.full.rawValue, "full")
        XCTAssertEqual(TimerDisplayMode.simplified.rawValue, "simplified")
    }
    
    func testTimerDisplayModeAllCases() {
        let allCases = TimerDisplayMode.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.hidden))
        XCTAssertTrue(allCases.contains(.full))
        XCTAssertTrue(allCases.contains(.simplified))
    }
    
    func testTimerDisplayModeCodable() throws {
        // Test encoding
        let mode = TimerDisplayMode.simplified
        let encoded = try JSONEncoder().encode(mode)
        
        // Test decoding
        let decoded = try JSONDecoder().decode(TimerDisplayMode.self, from: encoded)
        XCTAssertEqual(decoded, mode)
    }
    
    func testDefaultTimerDisplayModeInFocusManager() {
        let mockPersistence = MockPersistenceManager()
        let focusManager = FocusManager(userDefaultsManager: mockPersistence)
        
        // Default should be .full when no stored preference exists
        XCTAssertEqual(focusManager.timerDisplayMode, .full)
    }
    
    func testTimerDisplayModePersistence() {
        let mockPersistence = MockPersistenceManager()
        let focusManager = FocusManager(userDefaultsManager: mockPersistence)
        
        // Set a new mode
        focusManager.timerDisplayMode = .hidden
        
        // Verify it was saved to persistence
        let savedMode = mockPersistence.load(TimerDisplayMode.self, forKey: UserDefaultsManager.Keys.timerDisplayMode)
        XCTAssertEqual(savedMode, .hidden)
    }
}

#endif