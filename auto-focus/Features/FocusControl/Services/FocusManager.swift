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

    private var timeTrackingTimer: Timer?
    private let checkInterval: TimeInterval = AppConfiguration.checkInterval
    
    // Sleep/wake detection
    private var isSystemAsleep = false
    
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

        loadFocusApps()
        // Load UserDefault values using UserDefaultsManager
        focusThreshold = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusThreshold)
        if focusThreshold == 0 { focusThreshold = AppConfiguration.defaultFocusThreshold }
        focusLossBuffer = userDefaultsManager.getDouble(forKey: UserDefaultsManager.Keys.focusLossBuffer)
        if focusLossBuffer == 0 { focusLossBuffer = AppConfiguration.defaultBufferTime }
        isPaused = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.isPaused)
        hasCompletedOnboarding = userDefaultsManager.getBool(forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)

        // Set up delegates and start monitoring
        self.appMonitor.delegate = self
        self.bufferManager.delegate = self
        self.focusModeController.delegate = self
        self.browserManager.delegate = self
        self.appMonitor.updateFocusApps(focusApps)
        self.appMonitor.startMonitoring()
        
        // Set up sleep/wake notifications
        setupSleepWakeNotifications()

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
        // Don't increment time if system is asleep
        guard !isSystemAsleep else { return }
        
        timeSpent += checkInterval
        if shouldEnterFocusMode {
            print("activating focus mode")
            isInFocusMode = true
            focusModeController.setFocusMode(enabled: true)
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

    // Overall focus state considering both apps and browser URLs
    var isInOverallFocus: Bool {
        return isFocusAppActive || isBrowserInFocus
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
                focusModeController.setFocusMode(enabled: false)
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
    
    // MARK: - Sleep/Wake Detection
    
    private func setupSleepWakeNotifications() {
        // Listen for system sleep notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWillSleep()
        }
        
        // Listen for system wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemDidWake()
        }
    }
    
    private func handleSystemWillSleep() {
        isSystemAsleep = true
        
        // Pause the timer if it's running, but don't end the session
        if timeTrackingTimer != nil {
            timeTrackingTimer?.invalidate()
            timeTrackingTimer = nil
            print("System going to sleep - pausing time tracking")
        }
    }
    
    private func handleSystemDidWake() {
        isSystemAsleep = false
        
        // Resume the timer if we have an active focus session
        if isFocusAppActive && timeTrackingTimer == nil {
            startTimeTracking()
            print("System woke up - resuming time tracking")
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
            print("Export feature requires premium subscription")
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
                        print("Export successful: \(url.path)")
                    } catch {
                        print("Export failed: \(error)")
                    }
                }
            }
        } catch {
            print("Export encoding failed: \(error)")
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
            print("Focus mode error: Toggle Do Not Disturb shortcut not found")
        case .appleScriptError(let message):
            print("Focus mode AppleScript error: \(message)")
        case .shortcutsAppNotInstalled:
            print("Focus mode error: Shortcuts app not installed")
        }
    }
    
    deinit {
        // Clean up notification observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timeTrackingTimer?.invalidate()
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
                print("Browser became active during focus session - waiting for browser focus check")
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
                    print("FocusManager: Switched from focus state to non-focus app: \(bundleIdentifier ?? "unknown")")
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
                    print("FocusManager: Switched to browser without extension - ending browser focus")
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
            print("Browser tab updated: \(tabInfo.url) (Focus: \(tabInfo.isFocusURL))")
        }
    }

    func browserManager(_ manager: any BrowserManaging, didChangeConnectionState isConnected: Bool) {
        batchUpdate {
            self.isExtensionConnected = isConnected
            print("Browser extension connection: \(isConnected ? "connected" : "disconnected")")
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
        print("FocusManager: handleBrowserFocusActivated called")
        // Similar to handleFocusAppInFront but for browser
        bufferManager.cancelBuffer()

        if !isFocusAppActive {
            print("FocusManager: Starting focus session from browser")
            startFocusSession()
        } else {
            print("FocusManager: Continuing focus session with browser focus")
            if timeTrackingTimer == nil && isFocusAppActive {
                startTimeTracking()
            }
            updateFocusSession()
        }

    }

    private func handleBrowserFocusDeactivated() {
        print("FocusManager: handleBrowserFocusDeactivated called")
        // Similar to handleNonFocusAppInFront but for browser
        if isInFocusMode {
            print("FocusManager: Starting buffer period after browser focus loss")
            timeTrackingTimer?.invalidate()
            timeTrackingTimer = nil
            bufferManager.startBuffer(duration: focusLossBuffer)
        } else {
            print("FocusManager: Resetting focus state after browser focus loss")
            resetFocusState()
            if !isNotificationsEnabled {
                focusModeController.setFocusMode(enabled: false)
            }
        }

    }

    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL]) {
        // This will trigger UI updates for focusURLs computed property
        batchUpdate {
            self.objectWillChange.send()
        }
    }
}
