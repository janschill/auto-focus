import Foundation

final class ShortcutNotificationsController: NotificationsControlling {
    /// This shortcut is assumed to toggle notification state. We prevent accidental double-toggles
    /// by only running it when we think the desired state differs from last applied state.
    private var lastApplied: NotificationsDesiredState?

    /// TODO (US1): make this configurable and persist it; for now keep a safe default name.
    private let shortcutName: String = "Toggle Do Not Disturb"

    func setNotifications(_ state: NotificationsDesiredState) async throws {
        if lastApplied == state {
            return
        }

        try runShortcutWithoutActivating(shortcutName: shortcutName)
        lastApplied = state
    }

    private func runShortcutWithoutActivating(shortcutName: String) throws {
        // Matches the working pattern in the legacy app.
        let script = """
        tell application \"System Events\"
            tell application \"Shortcuts Events\"
                run shortcut \"\(shortcutName)\" without activating
            end tell
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw ShortcutRunnerError.appleScriptError("Failed to compile AppleScript")
        }

        _ = appleScript.executeAndReturnError(&error)
        if let error {
            throw ShortcutRunnerError.appleScriptError(error.description)
        }
    }
}

enum ShortcutRunnerError: Error, LocalizedError {
    case appleScriptError(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptError(let message):
            return "AppleScript error: \(message)"
        }
    }
}


