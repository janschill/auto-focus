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
        AppLogger.session.info("Session started", metadata: [
            "start_time": ISO8601DateFormatter().string(from: Date())
        ])
    }

    func endSession() {
        guard let startTime = currentSessionStartTime else {
            AppLogger.session.warning("Trying to end session but no start time found")
            return
        }

        let session = FocusSession(startTime: startTime, endTime: Date())
        focusSessions.append(session)

        AppLogger.session.info("Session ended", metadata: [
            "duration": String(format: "%.1f", session.duration),
            "start_time": ISO8601DateFormatter().string(from: startTime),
            "end_time": ISO8601DateFormatter().string(from: Date())
        ])

        // Notify delegate
        delegate?.sessionManager(self, didEndSession: session)

        // Reset current session
        currentSessionStartTime = nil
    }

    func cancelCurrentSession() {
        currentSessionStartTime = nil
        AppLogger.session.info("Current session cancelled")
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

    /// Loads focus sessions from UserDefaults.
    ///
    /// **Storage Location**: Sessions are stored in UserDefaults with key "focusSessions"
    /// under the app's bundle identifier ("auto-focus.auto-focus").
    ///
    /// **Note**: If sessions appear to be missing, possible causes:
    /// 1. App was reinstalled/updated and UserDefaults were cleared
    /// 2. Bundle identifier changed (would create a new UserDefaults domain)
    /// 3. Data corruption or encoding/decoding issues
    ///
    /// **Future**: Consider migrating to SQLite for more robust persistence and
    /// better handling of large datasets.
    private func loadSessions() {
        focusSessions = userDefaultsManager.load([FocusSession].self, forKey: UserDefaultsManager.Keys.focusSessions) ?? []

        // Debug: Log session count on load
        #if DEBUG
        AppLogger.session.debug("Loaded sessions from UserDefaults", metadata: [
            "count": String(focusSessions.count)
        ])
        #endif
    }

    private func saveSessions() {
        userDefaultsManager.save(focusSessions, forKey: UserDefaultsManager.Keys.focusSessions)

        // Debug: Log session count on save
        #if DEBUG
        AppLogger.session.debug("Saved sessions to UserDefaults", metadata: [
            "count": String(focusSessions.count)
        ])
        #endif
    }

    // MARK: - Import Methods

    func importSessions(_ sessions: [FocusSession]) {
        focusSessions.append(contentsOf: sessions)
    }

    // MARK: - Session Editing Methods

    func updateSession(_ session: FocusSession) {
        guard let index = focusSessions.firstIndex(where: { $0.id == session.id }) else {
            AppLogger.session.warning("Trying to update session that doesn't exist", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        // Validate session data
        guard session.startTime < session.endTime else {
            AppLogger.session.warning("Invalid session times - start must be before end", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        // Validate reasonable duration limits
        let duration = session.duration
        guard duration >= 1 else { // At least 1 second
            AppLogger.session.warning("Session duration too short", metadata: [
                "session_id": session.id.uuidString,
                "duration": String(format: "%.1f", duration)
            ])
            return
        }

        guard duration <= 24 * 60 * 60 else { // No more than 24 hours
            AppLogger.session.warning("Session duration too long (exceeds 24 hours)", metadata: [
                "session_id": session.id.uuidString,
                "duration": String(format: "%.1f", duration)
            ])
            return
        }

        // Validate session is not in the future
        guard session.endTime <= Date().addingTimeInterval(60) else { // Allow 1 minute tolerance
            AppLogger.session.warning("Session end time cannot be in the future", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        focusSessions[index] = session
        AppLogger.session.info("Session updated", metadata: [
            "session_id": session.id.uuidString,
            "duration": String(format: "%.1f", duration)
        ])
    }

    func deleteSession(_ session: FocusSession) {
        focusSessions.removeAll { $0.id == session.id }
        AppLogger.session.info("Session deleted", metadata: [
            "session_id": session.id.uuidString
        ])
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
