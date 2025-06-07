import Foundation

// MARK: - Session Management Protocol
protocol SessionManaging: AnyObject, ObservableObject {
    var focusSessions: [FocusSession] { get }
    var todaysSessions: [FocusSession] { get }
    var weekSessions: [FocusSession] { get }
    var monthSessions: [FocusSession] { get }
    var isSessionActive: Bool { get }

    func startSession()
    func endSession()
    func cancelCurrentSession()
    func addSampleSessions(_ sessions: [FocusSession])
    func clearAllSessions()
}

// MARK: - App Monitoring Protocol
protocol AppMonitoring: AnyObject, ObservableObject {
    var currentApp: String? { get }
    var isFocusAppActive: Bool { get }
    var delegate: AppMonitorDelegate? { get set }

    func startMonitoring()
    func stopMonitoring()
    func updateFocusApps(_ apps: [AppInfo])
}

// MARK: - Buffer Management Protocol
protocol BufferManaging: AnyObject, ObservableObject {
    var bufferTimeRemaining: TimeInterval { get }
    var isInBufferPeriod: Bool { get }
    var delegate: BufferManagerDelegate? { get set }

    func startBuffer(duration: TimeInterval)
    func cancelBuffer()
}

// MARK: - Focus Mode Control Protocol
protocol FocusModeControlling: AnyObject, ObservableObject {
    var isFocusModeEnabled: Bool { get }
    var delegate: FocusModeManagerDelegate? { get set }

    func setFocusMode(enabled: Bool)
    func checkShortcutExists() -> Bool
}

// MARK: - Persistence Protocol
protocol PersistenceManaging: AnyObject {
    func save<T: Codable>(_ value: T, forKey key: String)
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func setBool(_ value: Bool, forKey key: String)
    func getBool(forKey key: String) -> Bool
    func setDouble(_ value: Double, forKey key: String)
    func getDouble(forKey key: String) -> Double
}
