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
    @Published var shortcutRefreshTrigger: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

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

    // MARK: - Shortcut Status
    var isShortcutInstalled: Bool {
        _ = shortcutRefreshTrigger // Trigger dependency tracking
        return focusModeController.checkShortcutExists()
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

    init(
        userDefaultsManager: any PersistenceManaging = UserDefaultsManager(),
        sessionManager: (any SessionManaging)? = nil,
        appMonitor: (any AppMonitoring)? = nil,
        bufferManager: (any BufferManaging)? = nil,
        focusModeController: (any FocusModeControlling)? = nil
    ) {
        self.userDefaultsManager = userDefaultsManager

        // Create default implementations if not provided
        let checkInterval = AppConfiguration.checkInterval
        self.sessionManager = sessionManager ?? SessionManager(userDefaultsManager: userDefaultsManager as! UserDefaultsManager)
        self.appMonitor = appMonitor ?? AppMonitor(checkInterval: checkInterval)
        self.bufferManager = bufferManager ?? BufferManager()
        self.focusModeController = focusModeController ?? FocusModeManager()

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
        self.appMonitor.updateFocusApps(focusApps)
        self.appMonitor.startMonitoring()
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
        shortcutRefreshTrigger.toggle()
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaultsManager.setBool(true, forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        userDefaultsManager.setBool(false, forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
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
        let licenseManager = LicenseManager()
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
        let licenseManager = LicenseManager()
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
                sessionManager.addSampleSessions([session])
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
