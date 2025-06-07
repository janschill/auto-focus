import Foundation
import AppKit
import SwiftUI

protocol FocusModeManagerDelegate: AnyObject {
    func focusModeController(_ controller: any FocusModeControlling, didChangeFocusMode enabled: Bool)
    func focusModeController(_ controller: any FocusModeControlling, didFailWithError error: FocusModeError)
}

enum FocusModeError: Error {
    case shortcutNotFound
    case appleScriptError(String)
    case shortcutsAppNotInstalled
}

class FocusModeManager: ObservableObject, FocusModeControlling {
    @Published private(set) var isFocusModeEnabled = false

    weak var delegate: FocusModeManagerDelegate?

    // MARK: - Focus Mode Control

    func setFocusMode(enabled: Bool) {
        let toggleScript = """
        tell application "System Events"
            tell application "Shortcuts Events"
                run shortcut "\(AppConfiguration.shortcutName)" without activating
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: toggleScript) {
            scriptObject.executeAndReturnError(&error)
            if error == nil {
                isFocusModeEnabled = enabled
                delegate?.focusModeController(self, didChangeFocusMode: enabled)
            } else {
                let errorMessage = error?.description ?? "Unknown AppleScript error"
                delegate?.focusModeController(self, didFailWithError: .appleScriptError(errorMessage))
                print("AppleScript error: \(errorMessage)")
            }
        }
    }

    // MARK: - Validation

    func checkShortcutExists() -> Bool {
        let shortcutsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConfiguration.shortcutsAppBundleIdentifier)
        guard shortcutsApp != nil else {
            delegate?.focusModeController(self, didFailWithError: .shortcutsAppNotInstalled)
            return false
        }

        // Use Shortcuts API to check if shortcut exists
        let script = """
        tell application "Shortcuts"
            exists shortcut "\(AppConfiguration.shortcutName)"
        end tell
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            if let result = Optional(scriptObject.executeAndReturnError(&error)) {
                let exists = result.booleanValue
                if !exists {
                    delegate?.focusModeController(self, didFailWithError: .shortcutNotFound)
                }
                return exists
            }
        }

        delegate?.focusModeController(self, didFailWithError: .shortcutNotFound)
        return false
    }
}
