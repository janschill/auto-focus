import Foundation
import SwiftUI

class ConfigurationViewModel: ObservableObject {
    @Published var shortcutInstalled: Bool = false
    @Published var focusThreshold: Double
    @Published var focusLossBuffer: Double
    @Published var selectedAppId: String?
    @Published var focusApps: [AppInfo]
    @Published var isPremiumRequired: Bool

    private let focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
        self.focusThreshold = focusManager.focusThreshold
        self.focusLossBuffer = focusManager.focusLossBuffer
        self.selectedAppId = focusManager.selectedAppId
        self.focusApps = focusManager.focusApps
        self.isPremiumRequired = focusManager.isPremiumRequired
        self.shortcutInstalled = focusManager.checkShortcutExists()
    }

    func selectFocusApplication() {
        focusManager.selectFocusApplication()
        self.focusApps = focusManager.focusApps
        self.selectedAppId = focusManager.selectedAppId
    }

    func removeSelectedApp() {
        focusManager.removeSelectedApp()
        self.focusApps = focusManager.focusApps
        self.selectedAppId = focusManager.selectedAppId
    }

    func updateShortcutInstalled() {
        self.shortcutInstalled = focusManager.checkShortcutExists()
    }

    func setFocusThreshold(_ value: Double) {
        focusManager.focusThreshold = value
        self.focusThreshold = value
    }

    func setFocusLossBuffer(_ value: Double) {
        focusManager.focusLossBuffer = value
        self.focusLossBuffer = value
    }
}
