import Foundation
import SwiftUI

class ConfigurationViewModel: ObservableObject {
    @Published var shortcutInstalled: Bool = false

    private let focusManager: FocusManager

    init(focusManager: FocusManager = FocusManager.shared) {
        self.focusManager = focusManager
        self.shortcutInstalled = focusManager.checkShortcutExists()
    }

    func updateShortcutInstalled() {
        self.shortcutInstalled = focusManager.checkShortcutExists()
    }
}
