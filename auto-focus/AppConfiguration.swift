import Foundation

struct AppConfiguration {
    // MARK: - Focus Settings
    static let defaultFocusThreshold: TimeInterval = 12 // 12 minutes
    static let defaultBufferTime: TimeInterval = 2 // 2 seconds

    // MARK: - Timer Intervals
    static let checkInterval: TimeInterval = 1.0 // Check active app every second
    static let bufferTimerInterval: TimeInterval = 1.0 // Buffer countdown interval

    // MARK: - Debug Settings
    static let debugTimeMultiplier: Double = 1.0 // Debug mode: 1 second = 1 minute
    static let productionTimeMultiplier: Double = 60.0 // Production: 60 seconds = 1 minute

    // MARK: - Licensing
    static let freeAppLimit = 2

    // MARK: - System Integration
    static let shortcutName = "Toggle Do Not Disturb"
    static let shortcutsAppBundleIdentifier = "com.apple.shortcuts"
    static let applicationsDirectory = "/Applications"

    // MARK: - Helper Methods
    static var timeMultiplier: Double {
        #if DEBUG
        return debugTimeMultiplier
        #else
        return productionTimeMultiplier
        #endif
    }
}
