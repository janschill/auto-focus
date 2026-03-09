import AppKit
import Foundation

import GRDB

struct AppInfo: Identifiable, Codable, Hashable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var bundleIdentifier: String

    static let databaseTableName = "focusApp"

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

class FocusManager: ObservableObject {
    static let shared = FocusManager()

    private let settingsRepo: SettingsRepository
    private let focusAppRepo: FocusAppRepository
    private let sessionManager: any SessionManaging
    private let appMonitor: any AppMonitoring
    private let bufferManager: any BufferManaging
    private let focusModeController: any FocusModeControlling
    private let browserManager: any BrowserManaging
    private let licenseManager: LicenseManager

    @Published var timeSpent: TimeInterval = 0
    @Published var isFocusAppActive = false
    @Published var isNotificationsEnabled: Bool = true
    @Published var isPaused: Bool = false {
        didSet {
            try? settingsRepo.setBool(isPaused, forKey: "isPaused")
        }
    }
    @Published var focusApps: [AppInfo] = [] {
        didSet {
            // Sort alphabetically by name
            let sorted = focusApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if sorted.map({ $0.id }) != focusApps.map({ $0.id }) {
                // Only update if order changed to avoid infinite recursion
                focusApps = sorted
                return // This will trigger didSet again, but with sorted array
            }
            try? focusAppRepo.save(focusApps)
            appMonitor.updateFocusApps(focusApps)
        }
    }
    @Published var focusThreshold: TimeInterval = 12 {
        didSet {
            try? settingsRepo.setDouble(focusThreshold, forKey: "focusThreshold")
        }
    }
    @Published var focusLossBuffer: TimeInterval = 2 {
        didSet {
            try? settingsRepo.setDouble(focusLossBuffer, forKey: "focusLossBuffer")
        }
    }
    @Published var timerDisplayMode: TimerDisplayMode = .full {
        didSet {
            try? settingsRepo.setCodable(timerDisplayMode, forKey: "timerDisplayMode")
        }
    }
    @Published var selectedAppId: String?
    @Published var isInFocusMode = false
    var didReachFocusThreshold = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isBrowserInFocus: Bool = false
    @Published var currentBrowserTab: BrowserTabInfo?
    @Published var isShortcutInstalled: Bool = false

    private var freeAppLimit: Int = AppConfiguration.freeAppLimit
    @Published var isPremiumUser: Bool = false

    private let focusTimer: FocusTimer
    private let checkInterval: TimeInterval = AppConfiguration.checkInterval

    // Batch update system to prevent publishing during view updates

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

    // MARK: - Shortcut Status (cached - use refreshShortcutStatus() to update)

    var monthSessions: [FocusSession] {
        return sessionManager.monthSessions
    }

    // MARK: - Session Management

    func updateSession(_ session: FocusSession) {
        sessionManager.updateSession(session)
    }

    func deleteSession(_ session: FocusSession) {
        sessionManager.deleteSession(session)
    }

    // MARK: - Current App Access
    var currentAppBundleId: String? {
        return appMonitor.currentApp
    }

    var currentAppInfo: AppInfo? {
        guard let bundleId = currentAppBundleId else { return nil }
        return focusApps.first { $0.bundleIdentifier == bundleId }
    }

    var canAddMoreApps: Bool {
        if licenseManager.isLicensed {
            // Licensed users: check their specific limit (-1 means unlimited)
            return licenseManager.maxAppsAllowed == AppConfiguration.unlimited || focusApps.count < licenseManager.maxAppsAllowed
        } else {
            // Free users: use free app limit
            return focusApps.count < freeAppLimit
        }
    }

    var isPremiumRequired: Bool {
        if licenseManager.isLicensed {
            return false // Licensed users don't need premium
        } else {
            return focusApps.count >= freeAppLimit
        }
    }

    init(
        settingsRepo: SettingsRepository = SettingsRepository(),
        focusAppRepo: FocusAppRepository = FocusAppRepository(),
        sessionManager: (any SessionManaging)? = nil,
        appMonitor: (any AppMonitoring)? = nil,
        bufferManager: (any BufferManaging)? = nil,
        focusModeController: (any FocusModeControlling)? = nil,
        browserManager: (any BrowserManaging)? = nil,
        licenseManager: LicenseManager? = nil
    ) {
        self.settingsRepo = settingsRepo
        self.focusAppRepo = focusAppRepo
        self.licenseManager = licenseManager ?? LicenseManager()

        // Create default implementations if not provided
        let checkInterval = AppConfiguration.checkInterval
        self.sessionManager = sessionManager ?? SessionManager()
        self.appMonitor = appMonitor ?? AppMonitor(checkInterval: checkInterval)
        self.bufferManager = bufferManager ?? BufferManager()
        self.focusModeController = focusModeController ?? FocusModeManager()
        self.browserManager = browserManager ?? BrowserManager()

        self.focusTimer = FocusTimer(interval: checkInterval)

        loadFocusApps()
        // Load settings from SQLite
        focusThreshold = settingsRepo.getDouble(forKey: "focusThreshold")
        if focusThreshold == 0 { focusThreshold = AppConfiguration.defaultFocusThreshold }
        focusLossBuffer = settingsRepo.getDouble(forKey: "focusLossBuffer")
        if focusLossBuffer == 0 { focusLossBuffer = AppConfiguration.defaultBufferTime }
        isPaused = settingsRepo.getBool(forKey: "isPaused")
        hasCompletedOnboarding = settingsRepo.getBool(forKey: "hasCompletedOnboarding")
        timerDisplayMode = settingsRepo.getCodable(TimerDisplayMode.self, forKey: "timerDisplayMode") ?? .full

        // Set up delegates and start monitoring
        self.appMonitor.delegate = self
        self.bufferManager.delegate = self
        self.focusModeController.delegate = self
        self.browserManager.delegate = self
        self.appMonitor.updateFocusApps(focusApps)
        self.appMonitor.startMonitoring()

        // Sync browser state
        self.isBrowserInFocus = self.browserManager.isBrowserInFocus
        self.currentBrowserTab = self.browserManager.currentBrowserTab

        self.focusTimer.onTick = { [weak self] elapsedTime in
            self?.handleTimerTick(elapsedTime: elapsedTime)
        }

        // Check shortcut status asynchronously to avoid AppleScript blocking
        refreshShortcutStatus()
    }

    func togglePause() {
        isPaused = !isPaused
        if isPaused {
            if isFocusAppActive {
                if didReachFocusThreshold {
                    sessionManager.endSession()
                } else {
                    sessionManager.cancelCurrentSession()
                }
                resetFocusState()
                if !isNotificationsEnabled {
                    focusModeController.setFocusMode(enabled: false)
                }
            }
        } else {
            if let monitor = appMonitor as? AppMonitor {
                monitor.resetState()
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
        let loadedApps = (try? focusAppRepo.fetchAll()) ?? []
        focusApps = loadedApps
    }

    private func handleFocusAppInFront() {
        let wasInBuffer = bufferManager.isInBufferPeriod
        bufferManager.cancelBuffer()

        if !isFocusAppActive {
            let hasAccumulatedTime = timeSpent > 0 || focusTimer.currentTime > 0
            let preserveTime = isBrowserInFocus || wasInBuffer || hasAccumulatedTime
            startFocusSession(preserveTime: preserveTime)
        } else {
            if !focusTimer.isRunning && isFocusAppActive {
                focusTimer.start(preserveTime: true)
            }
            // When returning from buffer, don't overwrite timeSpent from the timer
            // as the timer was paused — the next tick will sync them naturally
            if !wasInBuffer {
                updateFocusSession()
            }
        }
    }

    private func startFocusSession(preserveTime: Bool = false) {
        isFocusAppActive = true

        if !preserveTime {
            timeSpent = 0
            focusTimer.reset()
        } else {
            if timeSpent == 0 && focusTimer.currentTime > 0 {
                timeSpent = focusTimer.currentTime
            }
        }

        if !isBrowserInFocus && !preserveTime {
            sessionManager.startSession()
        }

        focusTimer.start(preserveTime: preserveTime)
    }

    private func updateFocusSession() {
        // This is called when already tracking - just sync timeSpent with timer
        timeSpent = focusTimer.currentTime
        checkAndActivateFocusMode()
    }

    private func handleTimerTick(elapsedTime: TimeInterval) {
        timeSpent = elapsedTime
        checkAndActivateFocusMode()
    }

    private func checkAndActivateFocusMode() {
        if shouldEnterFocusMode {
            AppLogger.focus.info("Activating focus mode", metadata: [
                "time_spent": String(format: "%.1f", timeSpent),
                "threshold": String(format: "%.1f", focusThreshold * AppConfiguration.timeMultiplier)
            ])
            isInFocusMode = true
            didReachFocusThreshold = true
            focusModeController.setFocusMode(enabled: true)
        }
    }

    private var shouldEnterFocusMode: Bool {
        return isNotificationsEnabled && timeSpent >= (focusThreshold * AppConfiguration.timeMultiplier) && !isInFocusMode
    }

    // Overall focus state considering both apps and browser URLs
    var isInOverallFocus: Bool {
        return isFocusAppActive || isBrowserInFocus
    }

    private func handleNonFocusAppInFront() {
        // If browser focus is active, preserve time in browser context
        if isBrowserInFocus {
            isFocusAppActive = false
            return
        }

        if isInFocusMode {
            // In focus session - use configurable buffer to preserve session
            focusTimer.pause()
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else if timeSpent > 0 {
            // Before focus session but has accumulated time - short buffer for quick reset
            let preSessionBuffer = AppConfiguration.preSessionBuffer
            focusTimer.pause()
            bufferManager.startBuffer(duration: preSessionBuffer)
        } else {
            // No accumulated time - reset immediately
            if didReachFocusThreshold {
                sessionManager.endSession()
            } else {
                sessionManager.cancelCurrentSession()
            }
            resetFocusState()
            if !isNotificationsEnabled {
                focusModeController.setFocusMode(enabled: false)
            }
        }
    }

    private func resetFocusState() {
        isFocusAppActive = false
        isBrowserInFocus = false
        timeSpent = 0
        isInFocusMode = false
        didReachFocusThreshold = false
        focusTimer.reset()
    }

    func checkShortcutExists() -> Bool {
        return focusModeController.checkShortcutExists()
    }

    func refreshShortcutStatus() {
        // Run AppleScript check on background thread to avoid blocking UI
        // and prevent crashes from re-entrancy during SwiftUI view updates
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let exists = self.focusModeController.checkShortcutExists()
            DispatchQueue.main.async {
                self.isShortcutInstalled = exists
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        try? settingsRepo.setBool(true, forKey: "hasCompletedOnboarding")
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        try? settingsRepo.setBool(false, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Browser Management

    var focusURLs: [FocusURL] {
        return browserManager.focusURLs
    }

    func addFocusURL(_ focusURL: FocusURL) {
        browserManager.addFocusURL(focusURL)
    }

    func removeFocusURL(_ focusURL: FocusURL) {
        browserManager.removeFocusURL(focusURL)
    }

    func updateFocusURL(_ focusURL: FocusURL) {
        browserManager.updateFocusURL(focusURL)
    }

    var canAddMoreURLs: Bool {
        return browserManager.canAddMoreURLs
    }

    var availableURLPresets: [FocusURL] {
        return browserManager.availablePresets
    }

    func addPresetURLs(_ presets: [FocusURL]) {
        browserManager.addPresetURLs(presets)
    }

    // MARK: - Import Support

    func importSession(_ session: FocusSession) {
        sessionManager.importSessions([session])
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
                        // Append and let didSet handle sorting
                        self.focusApps.append(newApp)
                    }
                }
            }
        }
    }
}

// MARK: - FocusModeManagerDelegate
extension FocusManager: FocusModeManagerDelegate {
    func focusModeController(_ controller: any FocusModeControlling, didChangeFocusMode enabled: Bool) {
        // Update notifications state when focus mode changes
        self.isNotificationsEnabled = !enabled
    }

    func focusModeController(_ controller: any FocusModeControlling, didFailWithError error: FocusModeError) {
        switch error {
        case .shortcutNotFound:
            AppLogger.focus.error("Focus mode error: Toggle Do Not Disturb shortcut not found", error: error)
        case .appleScriptError(let message):
            AppLogger.focus.error("Focus mode AppleScript error", error: error, metadata: [
                "message": message
            ])
        case .shortcutsAppNotInstalled:
            AppLogger.focus.error("Focus mode error: Shortcuts app not installed", error: error)
        }
    }
}

// MARK: - BufferManagerDelegate
extension FocusManager: BufferManagerDelegate {
    func bufferManagerDidStartBuffer(_ manager: any BufferManaging) {
        // Buffer started - no action needed currently
    }

    func bufferManagerDidEndBuffer(_ manager: any BufferManaging) {
        // Buffer was cancelled (user returned to focus app) - no action needed
    }

    func bufferManagerDidTimeout(_ manager: any BufferManaging) {
        // Buffer timed out - only persist session if focus threshold was reached
        if didReachFocusThreshold {
            sessionManager.endSession()
        } else {
            sessionManager.cancelCurrentSession()
        }
        resetFocusState()
        if !isNotificationsEnabled {
            focusModeController.setFocusMode(enabled: false)
        }
    }
}

// MARK: - AppMonitorDelegate
extension FocusManager: AppMonitorDelegate {
    func appMonitor(_ monitor: any AppMonitoring, didDetectFocusApp isActive: Bool) {
        guard !isPaused else { return }

        if isActive {
            handleFocusAppInFront()
        } else if isFocusAppActive {
            // Check if a browser is currently active before ending focus session
            if let currentApp = (monitor as? AppMonitor)?.currentApp,
               AppConfiguration.isSupportedBrowser(currentApp) {
                // Browser became active - start polling and give browser manager a moment to update
                browserManager.startPolling()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !self.isBrowserInFocus {
                        self.handleNonFocusAppInFront()
                    }
                }
            } else {
                handleNonFocusAppInFront()
            }
        }
    }

    func appMonitor(_ monitor: any AppMonitoring, didChangeToApp bundleIdentifier: String?) {
        guard !isPaused else { return }

        let isBrowserApp = bundleIdentifier != nil && AppConfiguration.isSupportedBrowser(bundleIdentifier!)

        if isBrowserApp {
            browserManager.startPolling()
        } else {
            browserManager.stopPolling()
        }

        // If we're in an overall focus state and switched to a non-browser, non-focus app
        if isInOverallFocus {
            if !isBrowserApp {
                // Check if the new app is a focus app
                let isNewAppFocus = focusApps.contains { $0.bundleIdentifier == bundleIdentifier }

                if !isNewAppFocus {
                    AppLogger.focus.info("Switched from focus state to non-focus app", metadata: [
                        "app": bundleIdentifier ?? "unknown",
                        "was_browser_focus": String(isBrowserInFocus),
                        "was_app_focus": String(isFocusAppActive)
                    ])
                    if isBrowserInFocus {
                        handleBrowserFocusDeactivated()
                    } else if isFocusAppActive {
                        handleNonFocusAppInFront()
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

// MARK: - BrowserManagerDelegate
extension FocusManager: BrowserManagerDelegate {
    func browserManager(_ manager: any BrowserManaging, didChangeFocusState isFocus: Bool) {
        self.isBrowserInFocus = isFocus

        // Handle browser focus like app focus
        if isFocus {
            handleBrowserFocusActivated()
        } else {
            handleBrowserFocusDeactivated()
        }
    }

    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo) {
        self.currentBrowserTab = tabInfo
    }

    private func handleBrowserFocusActivated() {
        let wasInBuffer = bufferManager.isInBufferPeriod
        bufferManager.cancelBuffer()

        let wasTrackingInApp = isFocusAppActive && timeSpent > 0 && focusTimer.isRunning
        let hasAccumulatedTime = timeSpent > 0 || focusTimer.currentTime > 0
        let preserveTime = wasInBuffer || wasTrackingInApp || hasAccumulatedTime

        if !focusTimer.isRunning {
            if !preserveTime {
                timeSpent = 0
                focusTimer.reset()
            } else if timeSpent == 0 && focusTimer.currentTime > 0 {
                timeSpent = focusTimer.currentTime
            }

            if !isFocusAppActive && !wasInBuffer {
                sessionManager.startSession()
            }

            focusTimer.start(preserveTime: preserveTime)
        } else {
            updateFocusSession()
        }
    }

    private func handleBrowserFocusDeactivated() {
        let isChromeStillFrontmost = isSupportedBrowserFrontmost()

        if !isChromeStillFrontmost {
            let currentApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let isSwitchingToFocusApp = currentApp != nil && focusApps.contains { $0.bundleIdentifier == currentApp }

            if isSwitchingToFocusApp {
                return
            }
        }

        if isInFocusMode {
            focusTimer.pause()
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else if timeSpent > 0 {
            let preSessionBuffer = AppConfiguration.preSessionBuffer
            focusTimer.pause()
            bufferManager.startBuffer(duration: preSessionBuffer)
        } else {
            if didReachFocusThreshold {
                sessionManager.endSession()
            } else {
                sessionManager.cancelCurrentSession()
            }
            resetFocusState()
            if !isNotificationsEnabled {
                focusModeController.setFocusMode(enabled: false)
            }
        }
    }

    private func isSupportedBrowserFrontmost() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return AppConfiguration.isSupportedBrowser(bundleId)
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL]) {
        // This will trigger UI updates for focusURLs computed property
        self.objectWillChange.send()
    }

    func browserManager(_ manager: any BrowserManaging, didDenyAutomationPermissionForBrowser browserName: String) {
        showAutomationPermissionAlert(for: browserName)
    }

    private func showAutomationPermissionAlert(for browserName: String) {
        let alert = NSAlert()
        alert.messageText = "Automation Permission Required"
        alert.informativeText = "Auto-Focus needs permission to read URLs from \(browserName) to track your focus time on websites.\n\nPlease grant access in System Settings > Privacy & Security > Automation, then enable \(browserName) under Auto-Focus."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        // Make sure the app is visible for the alert
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
