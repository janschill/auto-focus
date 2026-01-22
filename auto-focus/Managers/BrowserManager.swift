import AppKit
import Combine
import Foundation

protocol BrowserManaging: AnyObject, ObservableObject {
    var focusURLs: [FocusURL] { get }
    var currentBrowserTab: BrowserTabInfo? { get }
    var isBrowserInFocus: Bool { get }
    var isExtensionConnected: Bool { get }
    var extensionHealth: ExtensionHealth? { get }
    var connectionQuality: ConnectionQuality { get }
    var delegate: BrowserManagerDelegate? { get set }
    var canAddMoreURLs: Bool { get }
    var availablePresets: [FocusURL] { get }
    var isSystemSleeping: Bool { get }

    func addFocusURL(_ focusURL: FocusURL)
    func removeFocusURL(_ focusURL: FocusURL)
    func updateFocusURL(_ focusURL: FocusURL)
    func checkIfURLIsFocus(_ url: String) -> (isFocus: Bool, matchedURL: FocusURL?)
    func addPresetURLs(_ presets: [FocusURL])
}

protocol BrowserManagerDelegate: AnyObject {
    func browserManager(_ manager: any BrowserManaging, didChangeFocusState isFocus: Bool)
    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo)
    func browserManager(_ manager: any BrowserManaging, didChangeConnectionState isConnected: Bool)
    func browserManager(_ manager: any BrowserManaging, didUpdateExtensionHealth health: ExtensionHealth?)
    func browserManager(_ manager: any BrowserManaging, didUpdateConnectionQuality quality: ConnectionQuality)
    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL])
}

class BrowserManager: ObservableObject, BrowserManaging {
    @Published var focusURLs: [FocusURL] = [] {
        didSet {
            // Sort alphabetically by name
            let sorted = focusURLs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if sorted.map({ $0.id }) != focusURLs.map({ $0.id }) {
                // Only update if order changed to avoid infinite recursion
                focusURLs = sorted
                return // This will trigger didSet again, but with sorted array
            }
        }
    }
    @Published var currentBrowserTab: BrowserTabInfo?
    @Published var isBrowserInFocus: Bool = false
    @Published var isExtensionConnected: Bool = false
    @Published var extensionHealth: ExtensionHealth? {
        didSet {
            // Defer delegate call to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.browserManager(self, didUpdateExtensionHealth: self.extensionHealth)
            }
        }
    }
    @Published var connectionQuality: ConnectionQuality = .unknown {
        didSet {
            // Defer delegate call to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.browserManager(self, didUpdateConnectionQuality: self.connectionQuality)
            }
        }
    }
    @Published var isSystemSleeping: Bool = false

    weak var delegate: BrowserManagerDelegate?

    private let userDefaultsManager: any PersistenceManaging
    private let licenseManager: LicenseManager
    private let httpServer = HTTPServer()

    // Suppress focus activation temporarily after adding a URL
    private var suppressFocusActivationUntil: Date?
    private var connectionTimeoutTimer: Timer?
    private let connectionTimeoutInterval: TimeInterval = AppConfiguration.connectionTimeoutInterval
    private var serverHealthTimer: Timer?
    private let serverHealthCheckInterval: TimeInterval = AppConfiguration.serverHealthCheckInterval
    private var lastTabUpdateTime: Date?
    private var heartbeatWithoutTabUpdateCount: Int = 0

    init(userDefaultsManager: any PersistenceManaging, licenseManager: LicenseManager = LicenseManager()) {
        self.userDefaultsManager = userDefaultsManager
        self.licenseManager = licenseManager

        loadFocusURLs()

        // Set up sleep/wake notifications
        setupSleepWakeNotifications()

        // Delay server startup to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.startHTTPServer()
        }
    }


    // MARK: - Focus URL Management

    func addFocusURL(_ focusURL: FocusURL) {
        // Check premium limits
        if !licenseManager.isLicensed && focusURL.isPremium {
            AppLogger.browser.warning("Premium license required for premium focus URLs", metadata: [
                "url": focusURL.domain
            ])
            return
        }

        if !licenseManager.isLicensed && focusURLs.count >= 3 {
            AppLogger.browser.warning("Free tier limited to 3 focus URLs", metadata: [
                "current_count": String(focusURLs.count)
            ])
            return
        }

        // Append and let didSet handle sorting
        focusURLs.append(focusURL)
        saveFocusURLs()
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func addFocusURLWithoutImmediateActivation(_ focusURL: FocusURL) {
        // Add URL but suppress focus activation for 2 seconds
        addFocusURL(focusURL)
        suppressFocusActivationUntil = Date().addingTimeInterval(2.0)
        AppLogger.browser.info("Suppressing focus activation for 2 seconds after adding URL", metadata: [
            "url": focusURL.domain
        ])
    }

    func removeFocusURL(_ focusURL: FocusURL) {
        focusURLs.removeAll { $0.id == focusURL.id }
        saveFocusURLs()
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func updateFocusURL(_ focusURL: FocusURL) {
        if let index = focusURLs.firstIndex(where: { $0.id == focusURL.id }) {
            focusURLs[index] = focusURL
            saveFocusURLs()
            delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
        }
    }

    func checkIfURLIsFocus(_ url: String) -> (isFocus: Bool, matchedURL: FocusURL?) {
        for focusURL in focusURLs where focusURL.isEnabled {
            if focusURL.matches(url) {
                return (true, focusURL)
            }
        }
        return (false, nil)
    }

    // MARK: - HTTP Server

    private func startHTTPServer() {
        AppLogger.browser.infoToFile("Starting HTTP server for browser extension", metadata: [
            "port": String(AppConfiguration.serverPort)
        ])
        httpServer.setBrowserManager(self)
        httpServer.start()

        // Verify server started successfully after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verifyServerStartup()
        }

        // Start periodic health checks
        startServerHealthMonitoring()
    }

    private func verifyServerStartup() {
        // Simple verification by checking if we can create a connection to our port
        // This helps detect if the server actually started successfully
        let task = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "http://localhost:8942/browser")!)) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // 404 is expected for GET request to /browser endpoint, means server is running
                    AppLogger.browser.info("HTTP server verified as running")
                    self.isExtensionConnected = false // Reset connection state
                } else {
                    AppLogger.browser.error("HTTP server verification failed", error: error, metadata: [
                        "status_code": (response as? HTTPURLResponse)?.statusCode.description ?? "unknown"
                    ])
                    self.retryServerStartup()
                }
            }
        }
        task.resume()
    }

    private func retryServerStartup() {
        AppLogger.browser.info("Retrying HTTP server startup in 2 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.httpServer.stop()
            self.startHTTPServer()
        }
    }

    func updateFromExtension(tabInfo: BrowserTabInfo, isFocus: Bool) {
        // Track when we last received a tab update
        lastTabUpdateTime = Date()
        heartbeatWithoutTabUpdateCount = 0

        AppLogger.browser.infoToFile("📥 BrowserManager: Received update from extension", metadata: [
            "url": tabInfo.url,
            "is_focus": String(isFocus),
            "was_connected": String(isExtensionConnected),
            "current_browser_focus_state": String(self.isBrowserInFocus),
            "matched_url": tabInfo.matchedFocusURL?.name ?? "none",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Ensure we're connected when receiving updates
        if !isExtensionConnected {
            AppLogger.browser.infoToFile("Extension connection restored via tab update", metadata: [
                "url": tabInfo.url
            ])
            isExtensionConnected = true
            delegate?.browserManager(self, didChangeConnectionState: true)
        }

        // Reset connection timeout timer since we got an update
        resetConnectionTimeoutTimer()

        // Check if a Chromium browser is the frontmost application (authoritative check via NSWorkspace)
        // This is the single source of truth - we don't rely on the extension's focus detection
        let isChromeFrontmost = isChromeBrowserFrontmost()

        let previousFocusState = self.isBrowserInFocus
        self.currentBrowserTab = tabInfo

        // Check if we should suppress focus activation
        let shouldSuppressFocus = shouldSuppressFocusActivation()

        AppLogger.browser.infoToFile("🔍 BrowserManager: Evaluating focus conditions", metadata: [
            "url": tabInfo.url,
            "is_focus": String(isFocus),
            "should_suppress": String(shouldSuppressFocus),
            "chrome_frontmost": String(isChromeFrontmost),
            "previous_focus_state": String(previousFocusState)
        ])

        // Only activate focus if:
        // 1. URL matches a focus domain
        // 2. We're not suppressing activation (recently added URL)
        // 3. Chrome is actually the frontmost app (double-check)
        let effectiveIsFocus = isFocus && !shouldSuppressFocus && isChromeFrontmost

        AppLogger.browser.infoToFile("🔍 BrowserManager: Effective focus calculation", metadata: [
            "url": tabInfo.url,
            "is_focus": String(isFocus),
            "!should_suppress": String(!shouldSuppressFocus),
            "chrome_frontmost": String(isChromeFrontmost),
            "effective_is_focus": String(effectiveIsFocus),
            "calculation": "isFocus(\(isFocus)) && !shouldSuppress(\(!shouldSuppressFocus)) && chromeFrontmost(\(isChromeFrontmost)) = \(effectiveIsFocus)"
        ])

        if isFocus && !isChromeFrontmost {
            AppLogger.browser.infoToFile("⚠️ BrowserManager: Focus URL detected but Chrome is not frontmost - suppressing focus activation", metadata: [
                "url": tabInfo.url
            ])
        }

        if shouldSuppressFocus && isFocus {
            AppLogger.browser.infoToFile("⚠️ BrowserManager: Suppressing focus activation for recently added URL", metadata: [
                "url": tabInfo.url
            ])
        }

        // Update focus state if changed
        if self.isBrowserInFocus != effectiveIsFocus {
            AppLogger.browser.infoToFile("🔄 BrowserManager: Focus state CHANGING", metadata: [
                "url": tabInfo.url,
                "from": String(self.isBrowserInFocus),
                "to": String(effectiveIsFocus),
                "previous_state": String(self.isBrowserInFocus),
                "new_state": String(effectiveIsFocus)
            ])

            AppLogger.browser.stateChange(
                from: String(self.isBrowserInFocus),
                to: String(effectiveIsFocus),
                metadata: ["url": tabInfo.url]
            )
            self.isBrowserInFocus = effectiveIsFocus

            AppLogger.browser.infoToFile("📤 BrowserManager: Notifying delegate of focus state change", metadata: [
                "url": tabInfo.url,
                "new_focus_state": String(effectiveIsFocus),
                "delegate_exists": String(self.delegate != nil)
            ])

            // Immediately notify delegate of focus state change
            self.delegate?.browserManager(self, didChangeFocusState: effectiveIsFocus)

            if effectiveIsFocus {
                AppLogger.browser.infoToFile("Browser entered focus mode", metadata: [
                    "url": tabInfo.url,
                    "matched_url": tabInfo.matchedFocusURL?.name ?? "none"
                ])
            } else {
                AppLogger.browser.infoToFile("Browser exited focus mode", metadata: [
                    "url": tabInfo.url
                ])
            }
        } else if effectiveIsFocus && self.isBrowserInFocus {
            // State is already true and we're still on a focus URL
            // Ensure delegate is notified to restart timer if needed
            // This handles the case where timer was stopped but we're still in focus
            AppLogger.browser.infoToFile("✅ BrowserManager: Browser focus already active, ensuring timer is running", metadata: [
                "url": tabInfo.url,
                "matched_url": tabInfo.matchedFocusURL?.name ?? "none",
                "current_state": String(self.isBrowserInFocus),
                "effective_focus": String(effectiveIsFocus)
            ])
            // Notify delegate to ensure timer is running
            AppLogger.browser.infoToFile("📤 BrowserManager: Notifying delegate to ensure timer running", metadata: [
                "url": tabInfo.url,
                "delegate_exists": String(self.delegate != nil)
            ])
            self.delegate?.browserManager(self, didChangeFocusState: true)
        } else {
            // Log when state doesn't change but we received a focus URL
            if isFocus && !effectiveIsFocus {
                AppLogger.browser.infoToFile("Focus URL detected but state unchanged", metadata: [
                    "url": tabInfo.url,
                    "current_state": String(self.isBrowserInFocus),
                    "effective_focus": String(effectiveIsFocus),
                    "is_focus": String(isFocus),
                    "should_suppress": String(shouldSuppressFocus),
                    "chrome_frontmost": String(isChromeFrontmost)
                ])
            }
        }

        // Always send tab update (unless it's a browser lost focus event)
        if tabInfo.url != "about:blank" {
            self.delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
        }

        if previousFocusState != effectiveIsFocus {
            AppLogger.browser.info("Browser focus state updated", metadata: [
                "state": effectiveIsFocus ? "FOCUS" : "NO FOCUS",
                "url": tabInfo.url
            ])
        }
    }

    // Check if a Chromium-based browser is currently the frontmost application
    private func isChromiumBrowserFrontmost() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let bundleId = frontmostApp.bundleIdentifier
        // Check for common Chromium-based browser bundle identifiers
        return bundleId == "com.google.Chrome" ||
               bundleId == "com.google.Chrome.canary" ||
               bundleId == "com.google.Chrome.beta" ||
               bundleId == "com.google.Chrome.dev" ||
               bundleId == "com.microsoft.Edge" ||
               bundleId == "com.microsoft.Edge.Canary" ||
               bundleId == "com.microsoft.Edge.Beta" ||
               bundleId == "com.microsoft.Edge.Dev" ||
               bundleId == "com.brave.Browser" ||
               bundleId == "com.brave.Browser.beta" ||
               bundleId == "com.operasoftware.Opera" ||
               bundleId == "com.operasoftware.OperaNext" ||
               bundleId == "com.operasoftware.OperaDeveloper" ||
               bundleId == "com.vivaldi.Vivaldi" ||
               bundleId == "com.yandex.browser" ||
               bundleId == "com.arc.Arc" ||
               bundleId == "com.360.Chrome" ||
               bundleId == "com.chromium.Chromium"
    }

    // Legacy method name for backward compatibility
    private func isChromeBrowserFrontmost() -> Bool {
        return isChromiumBrowserFrontmost()
    }

    private func shouldSuppressFocusActivation() -> Bool {
        guard let suppressUntil = suppressFocusActivationUntil else { return false }

        if Date() < suppressUntil {
            return true
        } else {
            // Clear the suppression flag if time has passed
            suppressFocusActivationUntil = nil
            return false
        }
    }

    private func checkBrowserState() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.janschill.auto-focus") ?? UserDefaults.standard

        guard let currentURL = sharedDefaults.string(forKey: "currentBrowserURL") else {
            return
        }

        let isFocus = sharedDefaults.bool(forKey: "isBrowserInFocus")
        let lastUpdate = sharedDefaults.double(forKey: "lastBrowserUpdate")

        // Only process if this is a recent update (within last 5 seconds)
        guard Date().timeIntervalSince1970 - lastUpdate < 5.0 else {
            return
        }

        AppLogger.browser.info("Browser state updated", metadata: [
            "url": currentURL,
            "is_focus": String(isFocus)
        ])

        let tabInfo = BrowserTabInfo(
            url: currentURL,
            title: "",
            isFocusURL: isFocus,
            matchedFocusURL: nil
        )

        DispatchQueue.main.async {
            self.currentBrowserTab = tabInfo

            // Update focus state if changed
            if self.isBrowserInFocus != isFocus {
                self.isBrowserInFocus = isFocus
                self.isExtensionConnected = true // Mark as connected when we get updates
                self.delegate?.browserManager(self, didChangeFocusState: isFocus)
            }

            self.delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
        }
    }


    // MARK: - Persistence

    private func saveFocusURLs() {
        userDefaultsManager.save(focusURLs, forKey: "focusURLs")
    }

    private func loadFocusURLs() {
        var loadedURLs = userDefaultsManager.load([FocusURL].self, forKey: "focusURLs") ?? []

        // Add default free presets if no URLs exist
        if loadedURLs.isEmpty {
            loadedURLs = FocusURL.freePresets
            saveFocusURLs()
            AppLogger.browser.info("Loaded default focus URLs", metadata: [
                "count": String(loadedURLs.count)
            ])
        } else {
            AppLogger.browser.info("Loaded saved focus URLs", metadata: [
                "count": String(loadedURLs.count)
            ])
        }

        // Sort alphabetically by name
        focusURLs = loadedURLs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Notify delegate of initial URLs (after delegate is set)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.delegate?.browserManager(self, didUpdateFocusURLs: self.focusURLs)
        }
    }

    // MARK: - Premium Features

    var canAddMoreURLs: Bool {
        if licenseManager.isLicensed {
            return true // Unlimited for premium users
        } else {
            return focusURLs.count < AppConfiguration.freeURLLimit
        }
    }

    var availablePresets: [FocusURL] {
        if licenseManager.isLicensed {
            return FocusURL.commonPresets
        } else {
            return FocusURL.freePresets
        }
    }

    func addPresetURLs(_ presets: [FocusURL]) {
        for preset in presets where !focusURLs.contains(where: { $0.domain == preset.domain }) {
            addFocusURL(preset)
        }
    }

    // MARK: - Connection Timeout Management

    func resetConnectionTimeoutTimer() {
        // Don't reset timer if system is sleeping
        guard !isSystemSleeping else {
            AppLogger.browser.debug("Skipping connection timeout reset - system is sleeping")
            return
        }

        // Check if we're receiving heartbeats but no tab_changed messages
        // This indicates the extension might not be sending tab updates
        let isChromeFrontmost = isChromeBrowserFrontmost()
        if isChromeFrontmost && isExtensionConnected {
            heartbeatWithoutTabUpdateCount += 1

            if let lastUpdate = lastTabUpdateTime {
                let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
                if timeSinceLastUpdate > 5.0 { // More than 5 seconds since last tab update
                    AppLogger.browser.infoToFile("⚠️ BrowserManager: Chrome is frontmost but no tab_changed messages received", metadata: [
                        "time_since_last_update": String(format: "%.1f", timeSinceLastUpdate),
                        "heartbeat_count_without_update": String(heartbeatWithoutTabUpdateCount),
                        "chrome_frontmost": String(isChromeFrontmost),
                        "extension_connected": String(isExtensionConnected),
                        "current_browser_focus": String(isBrowserInFocus)
                    ])
                }
            } else {
                // Never received a tab update
                if heartbeatWithoutTabUpdateCount >= 3 {
                    AppLogger.browser.infoToFile("⚠️ BrowserManager: Extension connected but NEVER sent tab_changed messages", metadata: [
                        "heartbeat_count_without_update": String(heartbeatWithoutTabUpdateCount),
                        "chrome_frontmost": String(isChromeFrontmost),
                        "extension_connected": String(isExtensionConnected),
                        "current_browser_focus": String(isBrowserInFocus),
                        "message": "Extension may not be detecting tab changes properly"
                    ])
                }
            }
        }

        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeoutInterval, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout()
        }
    }

    private func handleConnectionTimeout() {
        if isExtensionConnected {
            AppLogger.browser.warning("Connection timeout - no updates from extension", metadata: [
                "timeout_interval": String(format: "%.1f", connectionTimeoutInterval)
            ])
            isExtensionConnected = false
            delegate?.browserManager(self, didChangeConnectionState: false)
        }
    }

    // MARK: - Sleep/Wake Management

    private func setupSleepWakeNotifications() {
        let workspace = NSWorkspace.shared

        // Listen for sleep notifications
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWillSleep()
        }

        // Listen for wake notifications
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemDidWake()
        }

        // Also listen for screen sleep (lid closed on laptops)
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWillSleep()
        }

        // Listen for screen wake
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemDidWake()
        }
    }

    private func handleSystemWillSleep() {
        guard !isSystemSleeping else { return }

        isSystemSleeping = true
        AppLogger.browser.infoToFile("System going to sleep - pausing heartbeat processing", metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Stop connection timeout timer
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil

        // Mark connection as inactive (but don't disconnect completely)
        // The extension will reconnect when system wakes
    }

    private func handleSystemDidWake() {
        guard isSystemSleeping else { return }

        isSystemSleeping = false
        AppLogger.browser.infoToFile("System woke up - resuming heartbeat processing", metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Reset connection state - extension will reconnect via handshake/heartbeat
        isExtensionConnected = false

        // Restart connection timeout timer
        resetConnectionTimeoutTimer()
    }

    // MARK: - Server Health Monitoring

    private func startServerHealthMonitoring() {
        serverHealthTimer = Timer.scheduledTimer(withTimeInterval: serverHealthCheckInterval, repeats: true) { [weak self] _ in
            self?.performServerHealthCheck()
        }
    }

    private func performServerHealthCheck() {
        // Only log health check start in debug builds to reduce noise
        #if DEBUG
        AppLogger.browser.debugToFile("Performing server health check", metadata: [
            "extension_connected": String(isExtensionConnected),
            "connection_quality": connectionQuality.rawValue
        ])
        #endif

        let task = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "http://localhost:8942/browser")!)) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // 404 is expected - server is running but GET requests aren't supported (only POST)
                    // Only log in debug builds to reduce log noise
                    #if DEBUG
                    AppLogger.browser.debugToFile("Server health check OK (404 expected - server running)", metadata: [
                        "status_code": String(httpResponse.statusCode),
                        "note": "GET requests return 404, only POST is accepted"
                    ])
                    #endif
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode.description ?? "unknown"
                    AppLogger.browser.errorToFile("Server health check failed", error: error, metadata: [
                        "status_code": statusCode,
                        "extension_connected": String(self?.isExtensionConnected ?? false),
                        "connection_quality": self?.connectionQuality.rawValue ?? "unknown"
                    ])

                    if AppConfiguration.serverRestartOnFailure {
                        AppLogger.browser.warningToFile("Attempting to restart server due to health check failure", metadata: [
                            "status_code": statusCode
                        ])
                        self?.httpServer.stop()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self?.httpServer.start()
                        }
                    }
                }
            }
        }
        task.resume()
    }
}
