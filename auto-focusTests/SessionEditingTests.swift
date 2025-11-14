//
//  SessionEditingTests.swift
//  auto-focusTests
//
//  Created by Jan Schill on 27/01/2025.
//

@testable import auto_focus
import XCTest

#if DEBUG

final class SessionEditingTests: XCTestCase {
    var mockSessionManager: MockSessionManager!
    var focusManager: FocusManager!
    
    override func setUp() {
        super.setUp()
        mockSessionManager = MockSessionManager()
        focusManager = FocusManager(sessionManager: mockSessionManager)
    }
    
    // MARK: - FocusSession Model Tests
    
    func testFocusSessionEquatable() {
        let session1 = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let session2 = session1 // Same ID
        var session3 = session1
        session3.startTime = Date().addingTimeInterval(-100) // Different times, same ID
        
        XCTAssertEqual(session1, session2)
        XCTAssertEqual(session1, session3) // Should be equal based on ID
    }
    
    func testFocusSessionMutableProperties() {
        var session = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let originalStartTime = session.startTime
        let originalEndTime = session.endTime
        
        // Test that we can modify start and end times
        session.startTime = Date().addingTimeInterval(-100)
        session.endTime = Date().addingTimeInterval(3700)
        
        XCTAssertNotEqual(session.startTime, originalStartTime)
        XCTAssertNotEqual(session.endTime, originalEndTime)
        
        // Duration should be recalculated
        XCTAssertEqual(session.duration, 3800, accuracy: 1.0)
    }
    
    // MARK: - SessionManager Tests
    
    func testUpdateSession() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        mockSessionManager.addSampleSessions([originalSession])
        
        var updatedSession = originalSession
        updatedSession.startTime = Date().addingTimeInterval(-100)
        updatedSession.endTime = Date().addingTimeInterval(3700)
        
        mockSessionManager.updateSession(updatedSession)
        
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        let retrievedSession = mockSessionManager.focusSessions.first!
        XCTAssertEqual(retrievedSession.id, originalSession.id)
        XCTAssertEqual(retrievedSession.duration, 3800, accuracy: 1.0)
    }
    
    func testUpdateNonExistentSession() {
        let session = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        
        // Try to update a session that doesn't exist
        mockSessionManager.updateSession(session)
        
        // Should not add the session
        XCTAssertEqual(mockSessionManager.focusSessions.count, 0)
    }
    
    func testDeleteSession() {
        let session1 = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let session2 = FocusSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600))
        
        mockSessionManager.addSampleSessions([session1, session2])
        XCTAssertEqual(mockSessionManager.focusSessions.count, 2)
        
        mockSessionManager.deleteSession(session1)
        
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        XCTAssertEqual(mockSessionManager.focusSessions.first?.id, session2.id)
    }
    
    func testDeleteNonExistentSession() {
        let existingSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let nonExistentSession = FocusSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600))
        
        mockSessionManager.addSampleSessions([existingSession])
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        
        mockSessionManager.deleteSession(nonExistentSession)
        
        // Should still have the existing session
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        XCTAssertEqual(mockSessionManager.focusSessions.first?.id, existingSession.id)
    }
    
    // MARK: - FocusManager Integration Tests
    
    func testFocusManagerUpdateSession() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        focusManager.addSampleSessions([originalSession])
        
        var updatedSession = originalSession
        updatedSession.endTime = Date().addingTimeInterval(1800) // Shorter session
        
        focusManager.updateSession(updatedSession)
        
        XCTAssertEqual(focusManager.focusSessions.count, 1)
        let retrievedSession = focusManager.focusSessions.first!
        XCTAssertEqual(retrievedSession.duration, 1800, accuracy: 1.0)
    }
    
    func testFocusManagerDeleteSession() {
        let session1 = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let session2 = FocusSession(startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600))
        
        focusManager.addSampleSessions([session1, session2])
        XCTAssertEqual(focusManager.focusSessions.count, 2)
        
        focusManager.deleteSession(session2)
        
        XCTAssertEqual(focusManager.focusSessions.count, 1)
        XCTAssertEqual(focusManager.focusSessions.first?.id, session1.id)
    }
    
    // MARK: - Edge Case Tests
    
    func testSessionWithZeroDuration() {
        let startTime = Date()
        let endTime = startTime // Same time = zero duration
        
        let session = FocusSession(startTime: startTime, endTime: endTime)
        XCTAssertEqual(session.duration, 0, accuracy: 0.1)
    }
    
    func testSessionWithVeryLongDuration() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(24 * 60 * 60) // 24 hours
        
        let session = FocusSession(startTime: startTime, endTime: endTime)
        XCTAssertEqual(session.duration, 24 * 60 * 60, accuracy: 1.0)
    }
    
    func testMultipleSessionEdits() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        mockSessionManager.addSampleSessions([originalSession])
        
        // First edit
        var editedSession = originalSession
        editedSession.endTime = Date().addingTimeInterval(1800)
        mockSessionManager.updateSession(editedSession)
        
        // Second edit
        editedSession.startTime = Date().addingTimeInterval(-300)
        mockSessionManager.updateSession(editedSession)
        
        XCTAssertEqual(mockSessionManager.focusSessions.count, 1)
        let finalSession = mockSessionManager.focusSessions.first!
        XCTAssertEqual(finalSession.duration, 2100, accuracy: 1.0) // 35 minutes
    }
    
    // MARK: - Validation Tests
    
    func testUpdateSessionWithInvalidTimes() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        mockSessionManager.addSampleSessions([originalSession])
        
        // Try to update with end time before start time
        var invalidSession = originalSession
        invalidSession.endTime = originalSession.startTime.addingTimeInterval(-100)
        
        // Mock validation should prevent this update
        let sessionManager = SessionManager(userDefaultsManager: MockPersistenceManager())
        sessionManager.focusSessions = [originalSession]
        
        sessionManager.updateSession(invalidSession)
        
        // Original session should remain unchanged
        XCTAssertEqual(sessionManager.focusSessions.first?.endTime, originalSession.endTime)
    }
    
    func testUpdateSessionWithVeryShortDuration() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let sessionManager = SessionManager(userDefaultsManager: MockPersistenceManager())
        sessionManager.focusSessions = [originalSession]
        
        // Try to update with duration less than 1 second
        var invalidSession = originalSession
        invalidSession.endTime = originalSession.startTime.addingTimeInterval(0.5)
        
        sessionManager.updateSession(invalidSession)
        
        // Original session should remain unchanged
        XCTAssertEqual(sessionManager.focusSessions.first?.duration, 3600, accuracy: 1.0)
    }
    
    func testUpdateSessionWithVeryLongDuration() {
        let originalSession = FocusSession(startTime: Date(), endTime: Date().addingTimeInterval(3600))
        let sessionManager = SessionManager(userDefaultsManager: MockPersistenceManager())
        sessionManager.focusSessions = [originalSession]
        
        // Try to update with duration longer than 24 hours
        var invalidSession = originalSession
        invalidSession.endTime = originalSession.startTime.addingTimeInterval(25 * 60 * 60)
        
        sessionManager.updateSession(invalidSession)
        
        // Original session should remain unchanged
        XCTAssertEqual(sessionManager.focusSessions.first?.duration, 3600, accuracy: 1.0)
    }
}

#endif