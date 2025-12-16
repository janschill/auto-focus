import Combine
import Foundation

#if DEBUG

// MARK: - Mock Session Manager
class MockSessionManager: ObservableObject, SessionManaging {
    func importSessions(_ sessions: [FocusSession]) {
        focusSessions.append(contentsOf: sessions)
    }

    @Published var focusSessions: [FocusSession] = []
    @Published var isSessionActive: Bool = false

    // Test configuration
    var shouldFailStartSession = false
    var shouldFailEndSession = false
    private var currentSessionStartTime: Date?

    var todaysSessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return focusSessions.filter { calendar.isDate($0.startTime, inSameDayAs: today) }
    }

    var weekSessions: [FocusSession] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return focusSessions.filter { $0.startTime >= weekAgo }
    }

    var monthSessions: [FocusSession] {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return focusSessions.filter { $0.startTime >= monthAgo }
    }

    func startSession() {
        guard !shouldFailStartSession else { return }
        isSessionActive = true
        currentSessionStartTime = Date()
    }

    func endSession() {
        guard !shouldFailEndSession else { return }
        isSessionActive = false
        if let startTime = currentSessionStartTime {
            let session = FocusSession(startTime: startTime, endTime: Date())
            focusSessions.append(session)
        } else {
            // Fallback: create session with default duration
            let session = FocusSession(startTime: Date().addingTimeInterval(-60), endTime: Date())
            focusSessions.append(session)
        }
        currentSessionStartTime = nil
    }

    func cancelCurrentSession() {
        isSessionActive = false
        currentSessionStartTime = nil
    }

    func addSampleSessions(_ sessions: [FocusSession]) {
        focusSessions.append(contentsOf: sessions)
    }

    func clearAllSessions() {
        focusSessions.removeAll()
        isSessionActive = false
        currentSessionStartTime = nil
    }

    func updateSession(_ session: FocusSession) {
        guard let index = focusSessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }
        focusSessions[index] = session
    }

    func deleteSession(_ session: FocusSession) {
        focusSessions.removeAll { $0.id == session.id }
    }

    // Test helpers
    func reset() {
        clearAllSessions()
        shouldFailStartSession = false
        shouldFailEndSession = false
    }
}

// MARK: - Mock App Monitor
class MockAppMonitor: ObservableObject, AppMonitoring {
    @Published var currentApp: String?

    weak var delegate: AppMonitorDelegate?

    private var focusApps: [AppInfo] = []
    private var isMonitoring = false

    // Test configuration
    var shouldFailMonitoring = false
    var monitoringInterval: TimeInterval = 2.0

    func startMonitoring() {
        guard !shouldFailMonitoring else { return }
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
    }

    func resetState() {
        currentApp = nil
    }

    // Test helper methods
    func simulateFocusAppActive() {
        if let firstApp = focusApps.first {
            currentApp = firstApp.bundleIdentifier
        } else {
            currentApp = "com.test.focusapp"
        }
        delegate?.appMonitor(self, didDetectFocusApp: true)
    }

    func simulateFocusAppInactive() {
        currentApp = "com.test.other"
        delegate?.appMonitor(self, didDetectFocusApp: false)
    }

    func simulateAppSwitch(to bundleId: String, isFocusApp: Bool) {
        currentApp = bundleId
        delegate?.appMonitor(self, didDetectFocusApp: isFocusApp)
    }

    // Test helpers
    func reset() {
        stopMonitoring()
        resetState()
        focusApps.removeAll()
        shouldFailMonitoring = false
    }
}

// MARK: - Mock Buffer Manager
class MockBufferManager: ObservableObject, BufferManaging {
    @Published private(set) var bufferTimeRemaining: TimeInterval = 0
    @Published private(set) var isInBufferPeriod: Bool = false

    weak var delegate: BufferManagerDelegate?

    private var bufferTimer: Timer?
    private var bufferDuration: TimeInterval = 0

    // Test configuration
    var shouldFailBuffer = false
    var autoTimeoutEnabled = false

    func startBuffer(duration: TimeInterval) {
        guard !shouldFailBuffer else { return }
        isInBufferPeriod = true
        bufferTimeRemaining = duration
        bufferDuration = duration

        // Auto-timeout for testing
        if autoTimeoutEnabled {
            bufferTimer?.invalidate()
            bufferTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.simulateBufferTimeout()
            }
        }

        delegate?.bufferManagerDidStartBuffer(self)
    }

    func cancelBuffer() {
        bufferTimer?.invalidate()
        bufferTimer = nil
        isInBufferPeriod = false
        bufferTimeRemaining = 0
        bufferDuration = 0
        delegate?.bufferManagerDidEndBuffer(self)
    }

    // Test helper methods
    func simulateBufferTimeout() {
        bufferTimer?.invalidate()
        bufferTimer = nil
        isInBufferPeriod = false
        bufferTimeRemaining = 0
        bufferDuration = 0
        delegate?.bufferManagerDidTimeout(self)
    }

    // Test helpers
    func reset() {
        cancelBuffer()
        shouldFailBuffer = false
        autoTimeoutEnabled = false
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

    // Test configuration
    var shouldFailSave = false
    var shouldFailLoad = false

    func save<T: Codable>(_ value: T, forKey key: String) {
        guard !shouldFailSave else { return }
        storage[key] = value
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard !shouldFailLoad else { return nil }
        return storage[key] as? T
    }

    func setBool(_ value: Bool, forKey key: String) {
        guard !shouldFailSave else { return }
        storage[key] = value
    }

    func getBool(forKey key: String) -> Bool {
        guard !shouldFailLoad else { return false }
        return storage[key] as? Bool ?? false
    }

    func setDouble(_ value: Double, forKey key: String) {
        guard !shouldFailSave else { return }
        storage[key] = value
    }

    func getDouble(forKey key: String) -> Double {
        guard !shouldFailLoad else { return 0.0 }
        return storage[key] as? Double ?? 0.0
    }

    // Test helper methods
    func clearStorage() {
        storage.removeAll()
    }

    func reset() {
        clearStorage()
        shouldFailSave = false
        shouldFailLoad = false
    }

    // Test inspection
    func hasValue(forKey key: String) -> Bool {
        return storage[key] != nil
    }

    func getAllKeys() -> [String] {
        return Array(storage.keys)
    }
}

#endif
