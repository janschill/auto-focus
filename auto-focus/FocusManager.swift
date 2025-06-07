import Foundation
import AppKit

struct AppInfo: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bundleIdentifier: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

class FocusManager: ObservableObject {
    private let userDefaultsManager = UserDefaultsManager()
    private let sessionManager: SessionManager
    private let appMonitor: AppMonitor
    private let bufferManager: BufferManager

    @Published var timeSpent: TimeInterval = 0
    @Published var isFocusAppActive = false
    @Published var isNotificationsEnabled: Bool = true
    @Published var isPaused: Bool = false {
        didSet {
            userDefaultsManager.setBool(isPaused, forKey: UserDefaultsManager.Keys.isPaused)
        }
    }
    @Published var focusApps: [AppInfo] = [] {
        didSet {
            userDefaultsManager.save(focusApps, forKey: UserDefaultsManager.Keys.focusApps)
            appMonitor.updateFocusApps(focusApps)
        }
    }
    @Published var focusThreshold: TimeInterval = 12 {
        didSet {
            userDefaultsManager.setDouble(focusThreshold, forKey: UserDefaultsManager.Keys.focusThreshold)
        }
    }
    @Published var focusLossBuffer: TimeInterval = 2 {
        didSet {
            userDefaultsManager.setDouble(focusLossBuffer, forKey: UserDefaultsManager.Keys.focusLossBuffer)
        }
    }
    @Published var selectedAppId: String? = nil
    @Published var isInFocusMode = false

    private var freeAppLimit: Int = AppConfiguration.freeAppLimit
    @Published var isPremiumUser: Bool = false

    private var timeTrackingTimer: Timer?
    private let checkInterval: TimeInterval = AppConfiguration.checkInterval

    // MARK: - Buffer Access
    var bufferTimeRemaining: TimeInterval {
        return bufferManager.bufferTimeRemaining
    }

    var isInBufferPeriod: Bool {
        return bufferManager.isInBufferPeriod
    }

    // MARK: - Session Access
    var focusSessions: [FocusSession] {
        return sessionManager.focusSessions
    }

    var todaysSessions: [FocusSession] {
        return sessionManager.todaysSessions
    }

    var weekSessions: [FocusSession] {
        return sessionManager.weekSessions
    }

    var monthSessions: [FocusSession] {
        return sessionManager.monthSessions
    }

    var canAddMoreApps: Bool {
        let licenseManager = LicenseManager()
        return licenseManager.isLicensed || focusApps.count < freeAppLimit
    }

    var isPremiumRequired: Bool {
        let licenseManager = LicenseManager()
        return !licenseManager.isLicensed && focusApps.count >= freeAppLimit
    }

    init() {
        sessionManager = SessionManager(userDefaultsManager: userDefaultsManager)
        appMonitor = AppMonitor(checkInterval: checkInterval)
        bufferManager = BufferManager()

        loadFocusApps()
        // Load UserDefault values using UserDefaultsManager
        focusThreshold = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold)
        if focusThreshold == 0 { focusThreshold = AppConfiguration.defaultFocusThreshold }
        focusLossBuffer = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusLossBuffer)
        if focusLossBuffer == 0 { focusLossBuffer = AppConfiguration.defaultBufferTime }
        isPaused = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.isPaused)

        // Set up delegates and start monitoring
        appMonitor.delegate = self
        bufferManager.delegate = self
        appMonitor.updateFocusApps(focusApps)
        appMonitor.startMonitoring()
    }

    func togglePause() {
        isPaused = !isPaused
        if isPaused {
            if isFocusAppActive {
                sessionManager.endSession()
                resetFocusState()
                if !isNotificationsEnabled {
                    setFocusMode(enabled: false)
                }
            }
        }
    }

    func removeSelectedApp() {
        if let selectedId = selectedAppId {
            focusApps.removeAll { $0.id == selectedId }
            selectedAppId = nil
        }
    }

    private func loadFocusApps() {
        focusApps = userDefaultsManager.load([AppInfo].self, forKey: UserDefaultsManager.Keys.focusApps) ?? []
    }

    private func handleFocusAppInFront() {
        bufferManager.cancelBuffer()

        if !isFocusAppActive {
            startFocusSession()
        } else {
            // Resume time tracking if we were in a buffer period
            if timeTrackingTimer == nil && isFocusAppActive {
                startTimeTracking()
            }
            updateFocusSession()
        }
    }

    private func startFocusSession() {
        isFocusAppActive = true
        timeSpent = 0
        sessionManager.startSession()
        startTimeTracking()
    }

    private func updateFocusSession() {
        timeSpent += checkInterval
        if shouldEnterFocusMode {
            print("activating focus mode")
            isInFocusMode = true
            setFocusMode(enabled: true)
        }
    }

    private func startTimeTracking() {
        timeTrackingTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.updateFocusSession()
        }
    }

    private var shouldEnterFocusMode: Bool {
        return isNotificationsEnabled && timeSpent >= (focusThreshold * AppConfiguration.timeMultiplier) && !isInFocusMode
    }

    private func handleNonFocusAppInFront() {
        if isInFocusMode {
            // Pause time tracking when entering buffer period
            timeTrackingTimer?.invalidate()
            timeTrackingTimer = nil
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else {
            resetFocusState()
            if !isNotificationsEnabled {
                setFocusMode(enabled: false)
            }
        }
    }

    private func resetFocusState() {
        isFocusAppActive = false
        timeSpent = 0
        isInFocusMode = false
        timeTrackingTimer?.invalidate()
        timeTrackingTimer = nil
    }


    private func setFocusMode(enabled: Bool) {
        let toggleScript = """
        tell application "System Events"
            tell application "Shortcuts Events"
                run shortcut "\(AppConfiguration.shortcutName)" without activating
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: toggleScript) {
            scriptObject.executeAndReturnError(&error)
            if error == nil {
                self.isNotificationsEnabled = !enabled
            } else {
                print("AppleScript error: \(String(describing: error))")
            }
        }
    }

    func checkShortcutExists() -> Bool {
        let shortcutsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConfiguration.shortcutsAppBundleIdentifier)
        guard shortcutsApp != nil else { return false }

        // Use Shortcuts API to check if shortcut exists
        let script = """
        tell application "Shortcuts"
            exists shortcut "\(AppConfiguration.shortcutName)"
        end tell
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            if let result = Optional(scriptObject.executeAndReturnError(&error)) {
                return result.booleanValue
            }
        }
        return false
    }

    func selectFocusApplication() {
        if !canAddMoreApps {
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: AppConfiguration.applicationsDirectory)

        openPanel.begin { result in
            if result == .OK {
                guard let url = openPanel.url else { return }
                let bundle = Bundle(url: url)
                guard let bundleIdentifier = bundle?.bundleIdentifier,
                      let appName = bundle?.infoDictionary?["CFBundleName"] as? String else { return }

                DispatchQueue.main.async {
                    if !self.focusApps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        let newApp = AppInfo(
                            id: UUID().uuidString,
                            name: appName,
                            bundleIdentifier: bundleIdentifier
                        )
                        self.focusApps.append(newApp)
                    }
                }
            }
        }
    }
}

// MARK: - BufferManagerDelegate
extension FocusManager: BufferManagerDelegate {
    func bufferManagerDidStartBuffer(_ manager: BufferManager) {
        // Buffer started - no action needed currently
    }

    func bufferManagerDidEndBuffer(_ manager: BufferManager) {
        // Buffer was cancelled (user returned to focus app) - no action needed
    }

    func bufferManagerDidTimeout(_ manager: BufferManager) {
        // Buffer timed out - end session and exit focus mode
        sessionManager.endSession()
        resetFocusState()
        if !isNotificationsEnabled {
            setFocusMode(enabled: false)
        }
    }
}

// MARK: - AppMonitorDelegate
extension FocusManager: AppMonitorDelegate {
    func appMonitor(_ monitor: AppMonitor, didDetectFocusApp isActive: Bool) {
        guard !isPaused else { return }

        if isActive {
            handleFocusAppInFront()
        } else if isFocusAppActive {
            handleNonFocusAppInFront()
        }
    }
}

// MARK: - Debug Extensions
extension FocusManager {
    func addSampleSessions(_ sessions: [FocusSession]) {
        #if DEBUG
        sessionManager.addSampleSessions(sessions)
        #endif
    }

    func clearAllSessions() {
        #if DEBUG
        sessionManager.clearAllSessions()
        #endif
    }

    /// For debug UI - shows if we have sample data buttons available
    var canShowDebugOptions: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
