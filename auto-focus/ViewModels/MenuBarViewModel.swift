import Foundation
import SwiftUI

class MenuBarViewModel: ObservableObject {
    @Published var isPaused: Bool
    @Published var isInFocusMode: Bool
    @Published var timeSpent: TimeInterval
    @Published var todaysSessions: [FocusSession]

    private let focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
        self.isPaused = focusManager.isPaused
        self.isInFocusMode = focusManager.isInFocusMode
        self.timeSpent = focusManager.timeSpent
        self.todaysSessions = focusManager.todaysSessions
    }

    func togglePause() {
        focusManager.togglePause()
        self.isPaused = focusManager.isPaused
    }
}
