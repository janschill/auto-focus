import Foundation
import SwiftUI

class ConfigurationViewModel: ObservableObject {
    @Published var shortcutInstalled: Bool = false

    private let focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
        // Use cached value from FocusManager (avoids synchronous AppleScript during init)
        self.shortcutInstalled = focusManager.isShortcutInstalled
    }

    func updateShortcutInstalled() {
        // Refresh the shortcut status asynchronously, then update local state
        focusManager.refreshShortcutStatus()
        // The FocusManager will update isShortcutInstalled asynchronously
        // For immediate use, we can observe focusManager.isShortcutInstalled
        self.shortcutInstalled = focusManager.isShortcutInstalled
    }
}
