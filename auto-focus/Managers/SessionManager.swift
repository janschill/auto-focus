import Foundation
import SwiftUI

protocol SessionManagerDelegate: AnyObject {
    func sessionManager(_ manager: any SessionManaging, didStartSession session: FocusSession)
    func sessionManager(_ manager: any SessionManaging, didEndSession session: FocusSession)
}

class SessionManager: ObservableObject, SessionManaging {
    @Published var focusSessions: [FocusSession] = [] {
        didSet {
            saveSessions()
        }
    }

    private let userDefaultsManager: UserDefaultsManager
    private var currentSessionStartTime: Date?

    weak var delegate: SessionManagerDelegate?

    init(userDefaultsManager: UserDefaultsManager) {
        self.userDefaultsManager = userDefaultsManager
        loadSessions()
    }

    // MARK: - Session Management

    func startSession() {
        currentSessionStartTime = Date()
        print("Session started at: \(Date())")
    }

    func endSession() {
        guard let startTime = currentSessionStartTime else {
            print("Warning: Trying to end session but no start time found")
            return
        }

        let session = FocusSession(startTime: startTime, endTime: Date())
        focusSessions.append(session)

        print("Session ended. Duration: \(session.duration) seconds")

        // Notify delegate
        delegate?.sessionManager(self, didEndSession: session)

        // Reset current session
        currentSessionStartTime = nil
    }

    func cancelCurrentSession() {
        currentSessionStartTime = nil
        print("Current session cancelled")
    }

    var isSessionActive: Bool {
        return currentSessionStartTime != nil
    }

    // MARK: - Session Queries

    var todaysSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return focusSessions.filter { session in
            calendar.startOfDay(for: session.startTime) == today
        }
    }

    var weekSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return []
        }

        return focusSessions.filter { session in
            session.startTime >= oneWeekAgo
        }
    }

    var monthSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: today) else {
            return []
        }

        return focusSessions.filter { session in
            session.startTime >= oneMonthAgo
        }
    }

    // MARK: - Persistence

    private func saveSessions() {
        userDefaultsManager.save(focusSessions, forKey: UserDefaultsManager.Keys.focusSessions)
    }

    private func loadSessions() {
        focusSessions = userDefaultsManager.load([FocusSession].self, forKey: UserDefaultsManager.Keys.focusSessions) ?? []
    }

    // MARK: - Import Methods
    
    func importSessions(_ sessions: [FocusSession]) {
        focusSessions.append(contentsOf: sessions)
    }

    // MARK: - Session Editing Methods
    
    func updateSession(_ session: FocusSession) {
        guard let index = focusSessions.firstIndex(where: { $0.id == session.id }) else {
            print("Warning: Trying to update session that doesn't exist")
            return
        }
        
        // Validate session data
        guard session.startTime < session.endTime else {
            print("Warning: Invalid session times - start must be before end")
            return
        }
        
        // Validate reasonable duration limits
        let duration = session.duration
        guard duration >= 1 else { // At least 1 second
            print("Warning: Session duration too short")
            return
        }
        
        guard duration <= 24 * 60 * 60 else { // No more than 24 hours
            print("Warning: Session duration too long (exceeds 24 hours)")
            return
        }
        
        // Validate session is not in the future
        guard session.endTime <= Date().addingTimeInterval(60) else { // Allow 1 minute tolerance
            print("Warning: Session end time cannot be in the future")
            return
        }
        
        focusSessions[index] = session
        print("Session updated: \(session.id)")
    }
    
    func deleteSession(_ session: FocusSession) {
        focusSessions.removeAll { $0.id == session.id }
        print("Session deleted: \(session.id)")
    }

    // MARK: - Debug Methods

    func addSampleSessions(_ sessions: [FocusSession]) {
        #if DEBUG
        focusSessions.append(contentsOf: sessions)
        #endif
    }

    func clearAllSessions() {
        #if DEBUG
        focusSessions.removeAll()
        #endif
    }
}
