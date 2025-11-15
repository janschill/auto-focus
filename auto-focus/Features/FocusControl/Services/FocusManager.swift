import AppKit
import Foundation

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
    static let shared = FocusManager()

    private let userDefaultsManager: any PersistenceManaging
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
    @Published var timerDisplayMode: TimerDisplayMode = .full {
        didSet {
            userDefaultsManager.save(timerDisplayMode, forKey: UserDefaultsManager.Keys.timerDisplayMode)
        }
    }
    @Published var selectedAppId: String?
    @Published var isInFocusMode = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isBrowserInFocus: Bool = false
    @Published var currentBrowserTab: BrowserTabInfo?
    @Published var isExtensionConnected: Bool = false
    @Published var extensionHealth: ExtensionHealth?
    @Published var connectionQuality: ConnectionQuality = .unknown

    private var freeAppLimit: Int = AppConfiguration.freeAppLimit
    @Published var isPremiumUser: Bool = false

    private let focusTimer: FocusTimer
    private let checkInterval: TimeInterval = AppConfiguration.checkInterval

    // Batch update system to prevent publishing during view updates
    private var pendingUpdates: [() -> Void] = []
    private var updateTimer: Timer?

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

    // MARK: - Shortcut Status
    var isShortcutInstalled: Bool {
        // Remove dependency trigger to prevent AttributeGraph cycles
        return focusModeController.checkShortcutExists()
    }

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
            return licenseManager.maxAppsAllowed == -1 || focusApps.count < licenseManager.maxAppsAllowed
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
        userDefaultsManager: any PersistenceManaging = UserDefaultsManager(),
        sessionManager: (any SessionManaging)? = nil,
        appMonitor: (any AppMonitoring)? = nil,
        bufferManager: (any BufferManaging)? = nil,
        focusModeController: (any FocusModeControlling)? = nil,
        browserManager: (any BrowserManaging)? = nil,
        licenseManager: LicenseManager? = nil
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.licenseManager = licenseManager ?? LicenseManager()

        // Create default implementations if not provided
        let checkInterval = AppConfiguration.checkInterval
        self.sessionManager = sessionManager ?? SessionManager(userDefaultsManager: userDefaultsManager as! UserDefaultsManager)
        self.appMonitor = appMonitor ?? AppMonitor(checkInterval: checkInterval)
        self.bufferManager = bufferManager ?? BufferManager()
        self.focusModeController = focusModeController ?? FocusModeManager()
        self.browserManager = browserManager ?? BrowserManager(userDefaultsManager: userDefaultsManager)
        
        // Initialize focus timer with callbacks
        self.focusTimer = FocusTimer(interval: checkInterval)
        self.focusTimer.onTick = { [weak self] elapsedTime in
            self?.handleTimerTick(elapsedTime: elapsedTime)
        }

        loadFocusApps()
        // Load UserDefault values using UserDefaultsManager
        focusThreshold = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold)
        if focusThreshold == 0 { focusThreshold = AppConfiguration.defaultFocusThreshold }
        focusLossBuffer = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusLossBuffer)
        if focusLossBuffer == 0 { focusLossBuffer = AppConfiguration.defaultBufferTime }
        isPaused = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.isPaused)
        hasCompletedOnboarding = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
        timerDisplayMode = userDefaultsManager.load(TimerDisplayMode.self, forKey: UserDefaultsManager.Keys.timerDisplayMode) ?? .full

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
        self.isExtensionConnected = self.browserManager.isExtensionConnected
        self.extensionHealth = self.browserManager.extensionHealth
        self.connectionQuality = self.browserManager.connectionQuality
    }

    func togglePause() {
        isPaused = !isPaused
        if isPaused {
            if isFocusAppActive {
                sessionManager.endSession()
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
        focusApps = userDefaultsManager.load([AppInfo].self, forKey: UserDefaultsManager.Keys.focusApps) ?? []
    }

    private func handleFocusAppInFront() {
        bufferManager.cancelBuffer()

        if !isFocusAppActive {
            // Check if we're already tracking time in browser focus - if so, preserve it
            // We preserve time if we're switching between focus contexts (browser ↔ app)
            // Only reset if we're truly starting fresh (not in any focus context)
            let preserveTime = isBrowserInFocus || (timeSpent > 0 && focusTimer.isRunning)
            startFocusSession(preserveTime: preserveTime)
        } else {
            // Already in app focus - continue tracking
            if !focusTimer.isRunning && isFocusAppActive {
                focusTimer.start(preserveTime: true)
            }
            updateFocusSession()
        }
    }

    private func startFocusSession(preserveTime: Bool = false) {
        isFocusAppActive = true
        // Only reset timeSpent if we're not preserving time from browser focus
        if !preserveTime {
            timeSpent = 0
            focusTimer.reset()
        }
        // Only start a new session if we're not already in one (from browser focus)
        if !isBrowserInFocus {
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
        if isInFocusMode {
            // Pause time tracking when entering buffer period
            focusTimer.pause()
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else {
            // Only reset if we're not switching to browser focus
            // If we're switching to browser focus, preserve the time - it will be handled by handleBrowserFocusActivated()
            if !isBrowserInFocus {
                resetFocusState()
                if !isNotificationsEnabled {
                    focusModeController.setFocusMode(enabled: false)
                }
            } else {
                AppLogger.focus.info("App focus deactivated but browser focus is active - preserving time", metadata: [
                    "time_spent": String(format: "%.1f", timeSpent)
                ])
                // Don't reset - we're switching to browser focus, time will be preserved
                // Just mark app focus as inactive, but keep timeSpent and timer
                isFocusAppActive = false
            }
        }
    }

    private func resetFocusState() {
        isFocusAppActive = false
        timeSpent = 0
        isInFocusMode = false
        focusTimer.reset()
    }

    func checkShortcutExists() -> Bool {
        return focusModeController.checkShortcutExists()
    }

    func refreshShortcutStatus() {
        // Defer notification to avoid triggering during view updates
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaultsManager.setBool(true, forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        userDefaultsManager.setBool(false, forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
    }

    // MARK: - Safe Update System

    private func batchUpdate(_ update: @escaping () -> Void) {
        pendingUpdates.append(update)

        // Schedule execution if not already scheduled
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { [weak self] _ in
                self?.executePendingUpdates()
            }
        }
    }

    private func executePendingUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        updateTimer?.invalidate()
        updateTimer = nil

        // Execute all pending updates in a batch
        for update in updates {
            update()
        }
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

    // MARK: - Data Export/Import

    func exportData(options: ExportOptions = .default) -> AutoFocusExportData {
        let sessions = options.includeSessions ? filterSessions(by: options.dateRange) : []
        let apps = options.includeFocusApps ? focusApps : []
        let settings = options.includeSettings ? createUserSettings() : UserSettings(focusThreshold: 0, focusLossBuffer: 0, hasCompletedOnboarding: false)

        return AutoFocusExportData(
            metadata: ExportMetadata(),
            sessions: sessions,
            focusApps: apps,
            settings: settings
        )
    }

    func exportDataToFile(options: ExportOptions = .default) {
        guard licenseManager.isLicensed else {
            AppLogger.focus.warning("Export feature requires premium subscription")
            return
        }

        let exportData = exportData(options: options)

        do {
            let jsonData = try JSONEncoder().encode(exportData)

            let savePanel = NSSavePanel()
            savePanel.title = "Export Auto-Focus Data"
            savePanel.nameFieldStringValue = "auto-focus-export-\(DateFormatter.filenameSafe.string(from: Date()))"
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true

            savePanel.begin { result in
                if result == .OK, let url = savePanel.url {
                    do {
                        try jsonData.write(to: url)
                        AppLogger.focus.info("Export successful", metadata: [
                            "file_path": url.path,
                            "options": String(describing: options)
                        ])
                    } catch {
                        AppLogger.focus.error("Export failed", error: error, metadata: [
                            "file_path": url.path
                        ])
                    }
                }
            }
        } catch {
            AppLogger.focus.error("Export encoding failed", error: error)
        }
    }

    func importDataFromFile(completion: @escaping (ImportResult) -> Void) {
        guard licenseManager.isLicensed else {
            completion(.failure(.readError))
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Import Auto-Focus Data"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                self.importData(from: url) { importResult in
                    DispatchQueue.main.async {
                        completion(importResult)
                    }
                }
            }
        }
    }

    func importData(from url: URL, completion: @escaping (ImportResult) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(AutoFocusExportData.self, from: data)

            // Validate version compatibility
            guard isVersionSupported(exportData.metadata.version) else {
                completion(.failure(.unsupportedVersion))
                return
            }

            var summary = ImportSummary(
                sessionsImported: 0,
                focusAppsImported: 0,
                settingsImported: false,
                duplicatesSkipped: 0
            )

            // Import sessions
            let (imported, skipped) = importSessions(exportData.sessions)
            summary = ImportSummary(
                sessionsImported: imported,
                focusAppsImported: summary.focusAppsImported,
                settingsImported: summary.settingsImported,
                duplicatesSkipped: skipped
            )

            // Import focus apps
            let appsImported = importFocusApps(exportData.focusApps)
            summary = ImportSummary(
                sessionsImported: summary.sessionsImported,
                focusAppsImported: appsImported,
                settingsImported: summary.settingsImported,
                duplicatesSkipped: summary.duplicatesSkipped
            )

            // Import settings
            let settingsImported = importSettings(exportData.settings)
            summary = ImportSummary(
                sessionsImported: summary.sessionsImported,
                focusAppsImported: summary.focusAppsImported,
                settingsImported: settingsImported,
                duplicatesSkipped: summary.duplicatesSkipped
            )

            completion(.success(summary))

        } catch DecodingError.dataCorrupted(_) {
            completion(.failure(.corruptedData))
        } catch DecodingError.typeMismatch(_, _) {
            completion(.failure(.invalidFileFormat))
        } catch {
            completion(.failure(.readError))
        }
    }

    // MARK: - Private Import Helpers

    private func filterSessions(by dateRange: DateRange?) -> [FocusSession] {
        guard let range = dateRange else { return focusSessions }

        return focusSessions.filter { session in
            session.startTime >= range.startDate && session.endTime <= range.endDate
        }
    }

    private func createUserSettings() -> UserSettings {
        return UserSettings(
            focusThreshold: focusThreshold,
            focusLossBuffer: focusLossBuffer,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    private func isVersionSupported(_ version: String) -> Bool {
        // For now, support version 1.0 only
        return version == "1.0"
    }

    private func importSessions(_ sessions: [FocusSession]) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0

        for session in sessions {
            // Check for duplicates based on start time and duration
            let isDuplicate = focusSessions.contains { existing in
                abs(existing.startTime.timeIntervalSince(session.startTime)) < 1.0 &&
                abs(existing.duration - session.duration) < 1.0
            }

            if !isDuplicate {
                sessionManager.importSessions([session])
                imported += 1
            } else {
                skipped += 1
            }
        }

        return (imported, skipped)
    }

    private func importFocusApps(_ apps: [AppInfo]) -> Int {
        var imported = 0

        for app in apps {
            // Check for duplicates based on bundle identifier
            let isDuplicate = focusApps.contains { existing in
                existing.bundleIdentifier == app.bundleIdentifier
            }

            if !isDuplicate {
                focusApps.append(app)
                imported += 1
            }
        }

        return imported
    }

    private func importSettings(_ settings: UserSettings) -> Bool {
        // Only import non-zero values to avoid overwriting with defaults
        if settings.focusThreshold > 0 {
            focusThreshold = settings.focusThreshold
        }

        if settings.focusLossBuffer > 0 {
            focusLossBuffer = settings.focusLossBuffer
        }

        // Note: We don't import hasCompletedOnboarding to avoid resetting user's onboarding state

        return true
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
        // Buffer timed out - end session and exit focus mode
        sessionManager.endSession()
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
               currentApp == "com.google.Chrome" || currentApp == "com.apple.Safari" || currentApp == "org.mozilla.firefox" {
                // Browser became active - let browser manager handle focus state
                AppLogger.focus.info("Browser became active during focus session - waiting for browser focus check", metadata: [
                    "browser": currentApp
                ])
                // Give browser manager a moment to update focus state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !self.isBrowserInFocus {
                        // No browser focus detected, proceed with normal non-focus handling
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

        let isBrowserApp = bundleIdentifier == "com.google.Chrome" ||
                          bundleIdentifier == "com.apple.Safari" ||
                          bundleIdentifier == "org.mozilla.firefox"

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
                    // We left both browser focus and native focus - handle appropriately
                    if isBrowserInFocus {
                        // We were in browser focus, now we're leaving
                        handleBrowserFocusDeactivated()
                    } else if isFocusAppActive {
                        // We were in native app focus, now we're leaving
                        handleNonFocusAppInFront()
                    }
                }
            } else {
                // Switched to a browser app - check if extension is connected
                if !isExtensionConnected {
                    AppLogger.focus.warning("Switched to browser without extension - ending browser focus", metadata: [
                        "browser": bundleIdentifier ?? "unknown"
                    ])
                    // No extension means we can't track browser focus, so set it to false
                    batchUpdate {
                        self.isBrowserInFocus = false
                    }
                    // If we were only in browser focus (not native app focus), end the session
                    if !isFocusAppActive {
                        handleBrowserFocusDeactivated()
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
        batchUpdate {
            self.isBrowserInFocus = isFocus

            // Handle browser focus like app focus
            if isFocus {
                self.handleBrowserFocusActivated()
            } else {
                self.handleBrowserFocusDeactivated()
            }
        }
    }

    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo) {
        batchUpdate {
            self.currentBrowserTab = tabInfo
            AppLogger.browser.info("Browser tab updated", metadata: [
                "url": tabInfo.url,
                "is_focus": String(tabInfo.isFocusURL),
                "title": tabInfo.title
            ])
        }
    }

    func browserManager(_ manager: any BrowserManaging, didChangeConnectionState isConnected: Bool) {
        batchUpdate {
            self.isExtensionConnected = isConnected
            AppLogger.browser.info("Browser extension connection state changed", metadata: [
                "connected": String(isConnected)
            ])
        }
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateExtensionHealth health: ExtensionHealth?) {
        batchUpdate {
            self.extensionHealth = health
        }
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateConnectionQuality quality: ConnectionQuality) {
        batchUpdate {
            self.connectionQuality = quality
        }
    }

    private func handleBrowserFocusActivated() {
        AppLogger.focus.info("Browser focus activated")
        // Similar to handleFocusAppInFront but for browser
        bufferManager.cancelBuffer()

        if !isFocusAppActive {
            AppLogger.focus.info("Starting focus session from browser", metadata: [
                "time_spent": String(format: "%.1f", timeSpent)
            ])
            // Check if we're switching from app focus to browser focus
            // We preserve time only if we were tracking in app focus AND Chrome is now frontmost
            // If we're just switching between browser tabs, don't preserve time
            let wasTrackingInApp = timeSpent > 0 && focusTimer.isRunning
            let isChromeFrontmost = isChromeBrowserFrontmost()
            let preserveTime = wasTrackingInApp && isChromeFrontmost
            startFocusSession(preserveTime: preserveTime)
        } else {
            AppLogger.focus.info("Continuing focus session with browser focus", metadata: [
                "time_spent": String(format: "%.1f", timeSpent)
            ])
            // Already tracking in app focus - continue tracking when browser focus activates
            if !focusTimer.isRunning && isFocusAppActive {
                focusTimer.start(preserveTime: true)
            }
            updateFocusSession()
        }

    }

    private func handleBrowserFocusDeactivated() {
        AppLogger.focus.info("Browser focus deactivated")
        // Similar to handleNonFocusAppInFront but for browser
        if isInFocusMode {
            AppLogger.focus.info("Starting buffer period after browser focus loss", metadata: [
                "buffer_duration": String(format: "%.1f", focusLossBuffer),
                "time_spent": String(format: "%.1f", timeSpent)
            ])
            focusTimer.pause()
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else {
            // Check if Chrome is still the frontmost app
            // If Chrome is still frontmost, we're just switching tabs - reset the timer
            // If Chrome is not frontmost, check if we're switching to a focus app
            let isChromeStillFrontmost = isChromeBrowserFrontmost()

            if !isChromeStillFrontmost {
                // Chrome is not frontmost - check if we're switching to a focus app
                let currentApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                let isSwitchingToFocusApp = currentApp != nil && focusApps.contains { $0.bundleIdentifier == currentApp }

                if isSwitchingToFocusApp {
                    AppLogger.focus.info("Browser focus deactivated, switching to focus app - preserving time", metadata: [
                        "target_app": currentApp ?? "unknown",
                        "time_spent": String(format: "%.1f", timeSpent)
                    ])
                    // Don't reset - we're switching to app focus, time will be preserved
                    // Just mark browser focus as inactive, but keep timeSpent and timer
                    return
                }
            }

            // Reset in all other cases (switching tabs or leaving focus entirely)
            AppLogger.focus.info("Resetting focus state after browser focus loss", metadata: [
                "chrome_frontmost": String(isChromeStillFrontmost),
                "time_spent": String(format: "%.1f", timeSpent)
            ])
            resetFocusState()
            if !isNotificationsEnabled {
                focusModeController.setFocusMode(enabled: false)
            }
        }

    }

    private func isChromeBrowserFrontmost() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let bundleId = frontmostApp.bundleIdentifier
        return bundleId == "com.google.Chrome" ||
               bundleId == "com.google.Chrome.canary" ||
               bundleId == "com.google.Chrome.beta" ||
               bundleId == "com.google.Chrome.dev"
    }

    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL]) {
        // This will trigger UI updates for focusURLs computed property
        batchUpdate {
            self.objectWillChange.send()
        }
    }
}
