import Foundation

final class AppleEventsPermissionProbe {
    enum Target {
        case systemEvents
        case shortcutsEvents
        case safari
        case chrome

        var appName: String {
            switch self {
            case .systemEvents: return "System Events"
            case .shortcutsEvents: return "Shortcuts Events"
            case .safari: return "Safari"
            case .chrome: return "Google Chrome"
            }
        }

        var checkScript: String {
            // Minimal Apple Event that still targets the app.
            // (Avoid keystroke so we don't depend on Accessibility.)
            "tell application \"\(appName)\" to get name"
        }
    }

    /// Silent check using NSAppleScript (does not reliably show the TCC prompt on first run).
    func checkSilently(_ target: Target) -> PermissionState {
        let source = target.checkScript
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .notGranted(reason: "Failed to compile AppleScript.")
        }

        _ = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -1743 {
                return .notGranted(reason: "Automation not allowed. Enable in System Settings → Privacy & Security → Automation.")
            }
            return .notGranted(reason: "AppleScript error (\(code)).")
        }

        return .granted
    }

    /// Best-effort prompt: executes `osascript` which reliably triggers the Automation prompt.
    func requestPrompt(_ target: Target) async -> PermissionState {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", target.checkScript]

        let stderr = Pipe()
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .notGranted(reason: "Failed to run osascript.")
        }

        // After user responds, re-check silently for definitive status.
        return checkSilently(target)
    }
}


