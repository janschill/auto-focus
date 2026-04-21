import AppKit

struct BundleNameMapper {
    private static let friendlyNames: [String: String] = [
        "com.apple.loginwindow": "Lock Screen",
        "com.apple.finder": "Finder",
        "com.apple.systempreferences": "System Settings",
        "com.apple.SystemPreferences": "System Settings",
        "com.apple.Safari": "Safari",
        "com.apple.Terminal": "Terminal",
        "com.apple.dt.Xcode": "Xcode",
        "com.apple.mail": "Mail",
        "com.apple.iCal": "Calendar",
        "com.apple.Notes": "Notes",
        "com.apple.MobileSMS": "Messages",
        "com.apple.FaceTime": "FaceTime",
        "com.apple.Preview": "Preview",
        "com.apple.ActivityMonitor": "Activity Monitor",
        "com.apple.ScreenSaver.Engine": "Screen Saver",
        "com.apple.dock": "Dock",
        "com.apple.Spotlight": "Spotlight",
    ]

    static func displayName(bundleIdentifier: String, appName: String?) -> String {
        if let friendly = friendlyNames[bundleIdentifier] {
            return friendly
        }
        if let name = appName, !name.isEmpty {
            return name
        }
        let components = bundleIdentifier.split(separator: ".")
        return components.last.map(String.init) ?? bundleIdentifier
    }

    static func appIcon(for bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
