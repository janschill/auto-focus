import Combine
import Foundation

#if DEBUG

// MARK: - Mock Session Manager
class MockSessionManager: ObservableObject, SessionManaging {
    @Published var focusSessions: [FocusSession] = []
    @Published var isSessionActive: Bool = false

    var todaysSessions: [FocusSession] { focusSessions }
    var weekSessions: [FocusSession] { focusSessions }
    var monthSessions: [FocusSession] { focusSessions }

    func startSession() {
        isSessionActive = true
    }

    func endSession() {
        isSessionActive = false
        let session = FocusSession(startTime: Date().addingTimeInterval(-60), endTime: Date())
        focusSessions.append(session)
    }

    func cancelCurrentSession() {
        isSessionActive = false
    }

    func addSampleSessions(_ sessions: [FocusSession]) {
        focusSessions.append(contentsOf: sessions)
    }

    func clearAllSessions() {
        focusSessions.removeAll()
    }
}

// MARK: - Mock App Monitor
class MockAppMonitor: ObservableObject, AppMonitoring {
    @Published var currentApp: String?
    @Published var isFocusAppActive: Bool = false

    weak var delegate: AppMonitorDelegate?

    private var focusApps: [AppInfo] = []

    func startMonitoring() {
        // Mock implementation
    }

    func stopMonitoring() {
        // Mock implementation
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
    }

    // Test helper methods
    func simulateFocusAppActive() {
        isFocusAppActive = true
        delegate?.appMonitor(self, didDetectFocusApp: true)
    }

    func simulateFocusAppInactive() {
        isFocusAppActive = false
        delegate?.appMonitor(self, didDetectFocusApp: false)
    }
}

// MARK: - Mock Buffer Manager
class MockBufferManager: ObservableObject, BufferManaging {
    @Published private(set) var bufferTimeRemaining: TimeInterval = 0
    @Published private(set) var isInBufferPeriod: Bool = false

    weak var delegate: BufferManagerDelegate?

    func startBuffer(duration: TimeInterval) {
        isInBufferPeriod = true
        bufferTimeRemaining = duration
        delegate?.bufferManagerDidStartBuffer(self)
    }

    func cancelBuffer() {
        isInBufferPeriod = false
        bufferTimeRemaining = 0
        delegate?.bufferManagerDidEndBuffer(self)
    }

    // Test helper methods
    func simulateBufferTimeout() {
        isInBufferPeriod = false
        bufferTimeRemaining = 0
        delegate?.bufferManagerDidTimeout(self)
    }
}

// MARK: - Mock Focus Mode Controller
class MockFocusModeManager: ObservableObject, FocusModeControlling {
    @Published private(set) var isFocusModeEnabled: Bool = false

    weak var delegate: FocusModeManagerDelegate?

    var shouldFailShortcutCheck = false
    var shouldFailFocusMode = false

    func setFocusMode(enabled: Bool) {
        if shouldFailFocusMode {
            delegate?.focusModeController(self, didFailWithError: .appleScriptError("Mock error"))
            return
        }

        isFocusModeEnabled = enabled
        delegate?.focusModeController(self, didChangeFocusMode: enabled)
    }

    func checkShortcutExists() -> Bool {
        if shouldFailShortcutCheck {
            delegate?.focusModeController(self, didFailWithError: .shortcutNotFound)
            return false
        }
        return true
    }
}

// MARK: - Mock Persistence Manager
class MockPersistenceManager: PersistenceManaging {
    private var storage: [String: Any] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) {
        storage[key] = value
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        return storage[key] as? T
    }

    func setBool(_ value: Bool, forKey key: String) {
        storage[key] = value
    }

    func getBool(forKey key: String) -> Bool {
        return storage[key] as? Bool ?? false
    }

    func setDouble(_ value: Double, forKey key: String) {
        storage[key] = value
    }

    func getDouble(forKey key: String) -> Double {
        return storage[key] as? Double ?? 0.0
    }

    // Test helper methods
    func clearStorage() {
        storage.removeAll()
    }
}

#endif
