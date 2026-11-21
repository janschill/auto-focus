import Combine
import Foundation

protocol FocusModeManagerDelegate: AnyObject {
    func focusModeController(_ controller: any FocusModeControlling, didFailWithError error: FocusModeError)
}

enum FocusModeError: LocalizedError {
    case shortcutNotFound
    case shortcutFailed(String)

    var errorDescription: String? {
        switch self {
        case .shortcutNotFound:
            return "\(AppConfiguration.shortcutName) shortcut not found"
        case .shortcutFailed(let message):
            return "Shortcut failed: \(message)"
        }
    }

    var failureReason: String? {
        switch self {
        case .shortcutNotFound:
            return "The required shortcut '\(AppConfiguration.shortcutName)' was not found in the Shortcuts app"
        case .shortcutFailed(let message):
            return message
        }
    }
}

/// Turns Do Not Disturb on and off through the bundled "Auto-Focus Do Not Disturb" shortcut.
///
/// macOS has no public API for Focus, so the shortcut's "Set Focus" action does the work. The shortcut
/// takes an explicit "on"/"off" input and leaves a Focus the user enabled themselves untouched, so
/// Auto-Focus only turns off Do Not Disturb that it turned on.
final class FocusModeManager: ObservableObject, FocusModeControlling {
    weak var delegate: FocusModeManagerDelegate?

    private let shortcuts: any ShortcutRunning
    private let queue = DispatchQueue(label: "auto-focus.focus-mode")
    /// Whether Auto-Focus enabled the current Do Not Disturb. Only accessed on `queue`.
    private var ownsDoNotDisturb = false

    init(shortcuts: any ShortcutRunning = ShortcutsCLI()) {
        self.shortcuts = shortcuts
    }

    /// Requests Do Not Disturb on or off. Requests run in order on a background queue.
    func setFocusMode(enabled: Bool) {
        queue.async { [weak self] in
            self?.apply(enabled: enabled)
        }
    }

    /// Blocks until all queued requests have run. Used by tests.
    func waitUntilIdle() {
        queue.sync {}
    }

    private func apply(enabled: Bool) {
        guard enabled || ownsDoNotDisturb else { return }

        let input = enabled ? AppConfiguration.shortcutInputOn : AppConfiguration.shortcutInputOff
        let result: String
        do {
            result = try shortcuts.runShortcut(named: AppConfiguration.shortcutName, input: input)
        } catch {
            handleFailure(enabled: enabled, error: .shortcutFailed(error.localizedDescription))
            return
        }

        switch (enabled, result) {
        case (true, AppConfiguration.shortcutOutputEnabled):
            ownsDoNotDisturb = true
        case (true, AppConfiguration.shortcutOutputAlreadyActive):
            // A Focus was already on, possibly one Auto-Focus enabled earlier; ownership is unchanged.
            break
        case (false, AppConfiguration.shortcutOutputDisabled):
            ownsDoNotDisturb = false
        default:
            handleFailure(
                enabled: enabled,
                error: .shortcutFailed("Unexpected output '\(result)' for input '\(input)'")
            )
            return
        }

        AppLogger.focus.info("Focus mode shortcut ran", metadata: [
            "input": input,
            "result": result
        ])
    }

    private func handleFailure(enabled: Bool, error: FocusModeError) {
        guard (try? shortcuts.listShortcuts().contains(AppConfiguration.shortcutName)) == true else {
            // Nothing ran, so there is nothing to turn off later.
            ownsDoNotDisturb = false
            report(.shortcutNotFound)
            return
        }

        // The shortcut may have applied before failing. Assume Do Not Disturb could be on so a later
        // request turns it off; a failed "off" keeps ownership so it is retried.
        if enabled {
            ownsDoNotDisturb = true
        }
        report(error)
    }

    func checkShortcutExists() -> Bool {
        do {
            let exists = try shortcuts.listShortcuts().contains(AppConfiguration.shortcutName)
            if !exists {
                report(.shortcutNotFound)
            }
            return exists
        } catch {
            report(.shortcutFailed(error.localizedDescription))
            return false
        }
    }

    private func report(_ error: FocusModeError) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.focusModeController(self, didFailWithError: error)
        }
    }
}
