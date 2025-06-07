import Foundation
import SwiftUI

class DebugViewModel: ObservableObject {
    @Published var daysToGenerate: Int = 30
    @Published var sessionsPerDay: Int = 5
    @Published var avgSessionLength: Int = 25
    @Published var showingConfirmationAlert: Bool = false
    @Published var alertType: AlertType = .clearData

    enum AlertType {
        case clearData
        case addData
    }

    private let focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
    }

    func clearAllSessions() {
        focusManager.clearAllSessions()
    }

    func generateSampleData() {
        let sessions = SampleDataGenerator.shared.generateSampleSessions(
            days: daysToGenerate,
            sessionsPerDay: sessionsPerDay,
            avgSessionLength: TimeInterval(avgSessionLength * 60)
        )
        focusManager.addSampleSessions(sessions)
    }
}
