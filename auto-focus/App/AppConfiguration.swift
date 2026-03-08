import AppKit
import Foundation

struct AppConfiguration {
    // MARK: - Focus Settings
    static let defaultFocusThreshold: TimeInterval = 12 // 12 minutes
    static let defaultBufferTime: TimeInterval = 2 // 2 seconds
    static let preSessionBuffer: TimeInterval = 1 // 1 second buffer before focus session starts

    // MARK: - Timer Intervals
    static let checkInterval: TimeInterval = 1.0 // Check active app every second
    static let bufferTimerInterval: TimeInterval = 1.0 // Buffer countdown interval

    // MARK: - Debug Settings
    static let debugTimeMultiplier: Double = 1.0 // Debug mode: 1 second = 1 minute
    static let productionTimeMultiplier: Double = 60.0 // Production: 60 seconds = 1 minute

    // MARK: - Free Tier Limits
    static let freeAppLimit = 3
    static let freeURLLimit = 3
    static let unlimited = -1 // Used to indicate unlimited for licensed users

    // MARK: - License Configuration
    static let defaultMaxAppsAllowed = 3
    static let validationIntervalHours: TimeInterval = 168 // Validate once per week (7 days)
    static let gracePeriodDays: TimeInterval = 30 // Allow 30 days offline before requiring validation

    // MARK: - System Integration
    static let shortcutName = "Toggle Do Not Disturb"
    static let shortcutsAppBundleIdentifier = "com.apple.shortcuts"
    static let applicationsDirectory = "/Applications"

    // MARK: - Supported Browser Bundle IDs
    static let safariBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
    ]

    static let supportedBrowserBundleIds: Set<String> = safariBundleIds.union([
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Canary",
        "com.microsoft.Edge.Beta",
        "com.microsoft.Edge.Dev",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaNext",
        "com.operasoftware.OperaDeveloper",
        "com.vivaldi.Vivaldi",
        "com.yandex.browser",
        "com.arc.Arc",
        "com.360.Chrome",
        "com.chromium.Chromium",
    ])

    static let browserDisplayNames: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Google Chrome Canary",
        "com.google.Chrome.beta": "Google Chrome Beta",
        "com.google.Chrome.dev": "Google Chrome Dev",
        "com.microsoft.Edge": "Microsoft Edge",
        "com.microsoft.Edge.Canary": "Microsoft Edge Canary",
        "com.microsoft.Edge.Beta": "Microsoft Edge Beta",
        "com.microsoft.Edge.Dev": "Microsoft Edge Dev",
        "com.brave.Browser": "Brave",
        "com.brave.Browser.beta": "Brave Beta",
        "com.operasoftware.Opera": "Opera",
        "com.operasoftware.OperaNext": "Opera Next",
        "com.operasoftware.OperaDeveloper": "Opera Developer",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "com.yandex.browser": "Yandex Browser",
        "com.arc.Arc": "Arc",
        "com.360.Chrome": "360 Browser",
        "com.chromium.Chromium": "Chromium",
    ]

    static func installedSupportedBrowsers() -> [(bundleId: String, name: String)] {
        supportedBrowserBundleIds.compactMap { bundleId in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
                return nil
            }
            let name = browserDisplayNames[bundleId] ?? bundleId
            return (bundleId: bundleId, name: name)
        }
        .sorted { $0.name < $1.name }
    }

    static func isSupportedBrowser(_ bundleId: String) -> Bool {
        supportedBrowserBundleIds.contains(bundleId)
    }

    static func isSafari(_ bundleId: String) -> Bool {
        safariBundleIds.contains(bundleId)
    }

    // MARK: - Helper Methods
    static var timeMultiplier: Double {
        #if DEBUG
        return debugTimeMultiplier
        #else
        return productionTimeMultiplier
        #endif
    }
}
