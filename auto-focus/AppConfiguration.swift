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

    // MARK: - Network Configuration
    static let serverPort: UInt16 = 8942
    static let connectionTimeoutInterval: TimeInterval = 90.0 // 90 seconds
    static let serverHealthCheckInterval: TimeInterval = 60.0 // 1 minute (reduced for better reliability)
    static let maxStartupRetries = 3
    static let serverRestartOnFailure = true // Automatically restart server if health check fails

    // MARK: - License Configuration
    static let defaultMaxAppsAllowed = 3
    static let validationIntervalHours: TimeInterval = 168 // Validate once per week (7 days)
    static let gracePeriodDays: TimeInterval = 30 // Allow 30 days offline before requiring validation

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
