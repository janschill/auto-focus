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

    // Ephemeral URLSession for health checks - avoids disk caching that grows over time
    private lazy var healthCheckSession: URLSession = {
        URLSession(configuration: .ephemeral)
    }()

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
        AppLogger.browser.info("Starting HTTP server for browser extension", metadata: [
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
        let task = healthCheckSession.dataTask(with: URLRequest(url: URL(string: "http://localhost:8942/browser")!)) { _, response, error in
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
        lastTabUpdateTime = Date()
        heartbeatWithoutTabUpdateCount = 0

        // Restore connection if needed
        if !isExtensionConnected {
            isExtensionConnected = true
            delegate?.browserManager(self, didChangeConnectionState: true)
        }

        resetConnectionTimeoutTimer()

        let isChromeFrontmost = isChromeBrowserFrontmost()
        let previousFocusState = self.isBrowserInFocus
        self.currentBrowserTab = tabInfo

        // Only activate focus if URL matches, not suppressed, and Chrome is frontmost
        let effectiveIsFocus = isFocus && !shouldSuppressFocusActivation() && isChromeFrontmost

        if self.isBrowserInFocus != effectiveIsFocus {
            AppLogger.browser.stateChange(
                from: String(self.isBrowserInFocus),
                to: String(effectiveIsFocus),
                metadata: ["url": tabInfo.url]
            )
            self.isBrowserInFocus = effectiveIsFocus
            self.delegate?.browserManager(self, didChangeFocusState: effectiveIsFocus)
        } else if effectiveIsFocus && self.isBrowserInFocus {
            // Already in focus - re-notify delegate to ensure timer stays running
            self.delegate?.browserManager(self, didChangeFocusState: true)
        }

        // Send tab update (unless it's a browser lost focus event)
        if tabInfo.url != "about:blank" {
            self.delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
        }
    }

    private func isChromeBrowserFrontmost() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return AppConfiguration.chromiumBrowserBundleIds.contains(bundleId)
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
        guard !isSystemSleeping else { return }

        if isChromeBrowserFrontmost() && isExtensionConnected {
            heartbeatWithoutTabUpdateCount += 1
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
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }

    private func handleSystemDidWake() {
        guard isSystemSleeping else { return }
        isSystemSleeping = false
        isExtensionConnected = false
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
        AppLogger.browser.debug("Performing server health check", metadata: [
            "extension_connected": String(isExtensionConnected),
            "connection_quality": connectionQuality.rawValue
        ])
        #endif

        let task = healthCheckSession.dataTask(with: URLRequest(url: URL(string: "http://localhost:8942/browser")!)) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // 404 is expected - server is running but GET requests aren't supported (only POST)
                    // Only log in debug builds to reduce log noise
                    #if DEBUG
                    AppLogger.browser.debug("Server health check OK (404 expected - server running)", metadata: [
                        "status_code": String(httpResponse.statusCode),
                        "note": "GET requests return 404, only POST is accepted"
                    ])
                    #endif
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode.description ?? "unknown"
                    AppLogger.browser.error("Server health check failed", error: error, metadata: [
                        "status_code": statusCode,
                        "extension_connected": String(self?.isExtensionConnected ?? false),
                        "connection_quality": self?.connectionQuality.rawValue ?? "unknown"
                    ])

                    if AppConfiguration.serverRestartOnFailure {
                        AppLogger.browser.warning("Attempting to restart server due to health check failure", metadata: [
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
