import Foundation

final class BrowserDomainProvider: BrowserDomainProviding {
    // Bundle identifiers
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"

    func currentDomainIfBrowserFrontmost(foregroundBundleId: String?) -> DomainResult {
        guard let foregroundBundleId else {
            return .unavailable(reason: .unknown)
        }

        if foregroundBundleId == safari {
            return domainFromSafari()
        }
        if foregroundBundleId == chrome {
            return domainFromChrome()
        }

        return .unavailable(reason: .unsupportedBrowser)
    }

    private func domainFromSafari() -> DomainResult {
        // AppleScript: URL of current tab of front window.
        let script = """
        tell application \"Safari\"
            if not (exists front window) then return \"\"
            set theURL to URL of current tab of front window
            return theURL
        end tell
        """

        return domainFromAppleScriptURL(script: script)
    }

    private func domainFromChrome() -> DomainResult {
        let script = """
        tell application \"Google Chrome\"
            if not (exists front window) then return \"\"
            set theURL to URL of active tab of front window
            return theURL
        end tell
        """

        return domainFromAppleScriptURL(script: script)
    }

    private func domainFromAppleScriptURL(script: String) -> DomainResult {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .unavailable(reason: .scriptError)
        }

        let output = appleScript.executeAndReturnError(&error)
        if error != nil {
            return .unavailable(reason: .permissionDenied)
        }

        let urlString = output.stringValue ?? ""
        if urlString.isEmpty {
            return .unavailable(reason: .noActiveTab)
        }

        guard let url = URL(string: urlString), let host = url.host?.lowercased(), !host.isEmpty else {
            return .unavailable(reason: .unknown)
        }

        return .available(host)
    }
}


