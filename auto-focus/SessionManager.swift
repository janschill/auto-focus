import Foundation
import SwiftUI

protocol SessionManagerDelegate: AnyObject {
    func sessionManager(_ manager: SessionManager, didStartSession session: FocusSession)
    func sessionManager(_ manager: SessionManager, didEndSession session: FocusSession)
}

class SessionManager: ObservableObject {
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
