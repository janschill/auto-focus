import Combine
import Foundation
import SwiftUI

class SessionManager: ObservableObject, SessionManaging {
    @Published var focusSessions: [FocusSession] = []

    private let sessionRepo: SessionRepository
    private var currentSessionStartTime: Date?
    private var cancellable: AnyCancellable?

    init(sessionRepo: SessionRepository = SessionRepository()) {
        self.sessionRepo = sessionRepo

        // Load initial data
        focusSessions = (try? sessionRepo.fetchAll()) ?? []

        // Observe database changes → update @Published
        cancellable = sessionRepo.observeAll()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] sessions in
                    self?.focusSessions = sessions
                }
            )
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
        do {
            try sessionRepo.insert(session)
        } catch {
            AppLogger.session.error("Failed to save session", error: error)
        }

        AppLogger.session.info("Session ended", metadata: [
            "duration": String(format: "%.1f", session.duration),
            "start_time": ISO8601DateFormatter().string(from: startTime),
            "end_time": ISO8601DateFormatter().string(from: Date())
        ])

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

    // MARK: - Import Methods

    func importSessions(_ sessions: [FocusSession]) {
        for session in sessions {
            try? sessionRepo.insert(session)
        }
    }

    // MARK: - Session Editing Methods

    func updateSession(_ session: FocusSession) {
        guard focusSessions.contains(where: { $0.id == session.id }) else {
            AppLogger.session.warning("Trying to update session that doesn't exist", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        guard session.startTime < session.endTime else {
            AppLogger.session.warning("Invalid session times - start must be before end", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        let duration = session.duration
        guard duration >= 1 else {
            AppLogger.session.warning("Session duration too short", metadata: [
                "session_id": session.id.uuidString,
                "duration": String(format: "%.1f", duration)
            ])
            return
        }

        guard duration <= 24 * 60 * 60 else {
            AppLogger.session.warning("Session duration too long (exceeds 24 hours)", metadata: [
                "session_id": session.id.uuidString,
                "duration": String(format: "%.1f", duration)
            ])
            return
        }

        guard session.endTime <= Date().addingTimeInterval(60) else {
            AppLogger.session.warning("Session end time cannot be in the future", metadata: [
                "session_id": session.id.uuidString
            ])
            return
        }

        do {
            try sessionRepo.update(session)
            AppLogger.session.info("Session updated", metadata: [
                "session_id": session.id.uuidString,
                "duration": String(format: "%.1f", duration)
            ])
        } catch {
            AppLogger.session.error("Failed to update session", error: error)
        }
    }

    func deleteSession(_ session: FocusSession) {
        do {
            try sessionRepo.delete(session)
            AppLogger.session.info("Session deleted", metadata: [
                "session_id": session.id.uuidString
            ])
        } catch {
            AppLogger.session.error("Failed to delete session", error: error)
        }
    }

    // MARK: - Debug Methods

    func addSampleSessions(_ sessions: [FocusSession]) {
        #if DEBUG
        for session in sessions {
            try? sessionRepo.insert(session)
        }
        #endif
    }

    func clearAllSessions() {
        #if DEBUG
        try? sessionRepo.deleteAll()
        #endif
    }
}
