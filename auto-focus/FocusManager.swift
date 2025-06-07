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
    @Published private(set) var bufferTimeRemaining: TimeInterval = 0
    @Published private(set) var isInBufferPeriod = false

    private var freeAppLimit: Int = AppConfiguration.freeAppLimit
    @Published var isPremiumUser: Bool = false

    private var focusLossTimer: Timer?
    private var remainingBufferTime: TimeInterval = 0
    private var timer: Timer?
    private let checkInterval: TimeInterval = AppConfiguration.checkInterval

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
        loadFocusApps()
        // Load UserDefault values using UserDefaultsManager
        focusThreshold = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold)
        if focusThreshold == 0 { focusThreshold = AppConfiguration.defaultFocusThreshold }
        focusLossBuffer = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusLossBuffer)
        if focusLossBuffer == 0 { focusLossBuffer = AppConfiguration.defaultBufferTime }
        isPaused = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.isPaused)
        startMonitoring()
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

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkActiveApp()
        }
    }

    private func checkActiveApp() {
        if isPaused {
            return
        }

        guard let workspace = NSWorkspace.shared.frontmostApplication else { return }
        let currentApp = workspace.bundleIdentifier
        let isFocusAppInFront = focusApps.contains { $0.bundleIdentifier == currentApp }

        if isFocusAppInFront {
            handleFocusAppInFront()
        } else if isFocusAppActive {
            handleNonFocusAppInFront()
        }
    }

    private func handleFocusAppInFront() {
        focusLossTimer?.invalidate()
        focusLossTimer = nil

        if !isFocusAppActive {
            startFocusSession()
        } else {
            updateFocusSession()
        }
    }

    private func startFocusSession() {
        isFocusAppActive = true
        timeSpent = 0
        sessionManager.startSession()
    }

    private func updateFocusSession() {
        timeSpent += checkInterval
        if shouldEnterFocusMode {
            print("activating focus mode")
            isInFocusMode = true
            setFocusMode(enabled: true)
        }
    }

    private var shouldEnterFocusMode: Bool {
        return isNotificationsEnabled && timeSpent >= (focusThreshold * AppConfiguration.timeMultiplier) && !isInFocusMode
    }

    private func handleNonFocusAppInFront() {

        if focusLossTimer != nil {
            return
        }

        if isInFocusMode {
            startBufferTimer()
        } else {
            resetFocusState()

            if !isNotificationsEnabled {
                setFocusMode(enabled: false)
            }
        }

    }

    private func startBufferTimer() {
        isInBufferPeriod = true
        remainingBufferTime = focusLossBuffer
        bufferTimeRemaining = remainingBufferTime
        focusLossTimer?.invalidate()

        focusLossTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.bufferTimerInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.remainingBufferTime -= 1
            self.bufferTimeRemaining = self.remainingBufferTime

            if self.remainingBufferTime <= 0 {
                self.sessionManager.endSession()
                self.resetFocusState()
                if !self.isNotificationsEnabled {
                    self.setFocusMode(enabled: false)
                }
                timer.invalidate()
                self.focusLossTimer = nil
                self.isInBufferPeriod = false
            }
        }

        RunLoop.current.add(focusLossTimer!, forMode: .common)
    }

    private func resetFocusState() {
        isFocusAppActive = false
        timeSpent = 0
        isInFocusMode = false
        focusLossTimer?.invalidate()
        focusLossTimer = nil
        isInBufferPeriod = false
        bufferTimeRemaining = 0
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
