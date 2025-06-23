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
    @Published var focusURLs: [FocusURL] = []
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

    weak var delegate: BrowserManagerDelegate?

    private let userDefaultsManager: any PersistenceManaging
    private let licenseManager: LicenseManager
    private let httpServer = HTTPServer()

    // Suppress focus activation temporarily after adding a URL
    private var suppressFocusActivationUntil: Date?
    private var connectionTimeoutTimer: Timer?
    private let connectionTimeoutInterval: TimeInterval = 90.0 // 90 seconds

    init(userDefaultsManager: any PersistenceManaging, licenseManager: LicenseManager = LicenseManager()) {
        self.userDefaultsManager = userDefaultsManager
        self.licenseManager = licenseManager

        loadFocusURLs()
        
        // Delay server startup to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.startHTTPServer()
        }
    }


    // MARK: - Focus URL Management

    func addFocusURL(_ focusURL: FocusURL) {
        // Check premium limits
        if !licenseManager.isLicensed && focusURL.isPremium {
            print("Premium license required for premium focus URLs")
            return
        }

        if !licenseManager.isLicensed && focusURLs.count >= 3 {
            print("Free tier limited to 3 focus URLs")
            return
        }

        focusURLs.append(focusURL)
        saveFocusURLs()
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func addFocusURLWithoutImmediateActivation(_ focusURL: FocusURL) {
        // Add URL but suppress focus activation for 2 seconds
        addFocusURL(focusURL)
        suppressFocusActivationUntil = Date().addingTimeInterval(2.0)
        print("BrowserManager: Suppressing focus activation for 2 seconds after adding URL")
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
        print("BrowserManager: Starting HTTP server for browser extension...")
        httpServer.setBrowserManager(self)
        httpServer.start()
        
        // Verify server started successfully after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verifyServerStartup()
        }
    }
    
    private func verifyServerStartup() {
        // Simple verification by checking if we can create a connection to our port
        // This helps detect if the server actually started successfully
        let task = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "http://localhost:8942/browser")!)) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // 404 is expected for GET request to /browser endpoint, means server is running
                    print("BrowserManager: ✅ HTTP server verified as running")
                    self.isExtensionConnected = false // Reset connection state
                } else {
                    print("BrowserManager: ❌ HTTP server verification failed - \(error?.localizedDescription ?? "unknown error")")
                    self.retryServerStartup()
                }
            }
        }
        task.resume()
    }
    
    private func retryServerStartup() {
        print("BrowserManager: Retrying HTTP server startup in 2 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.httpServer.stop()
            self.startHTTPServer()
        }
    }

    func updateFromExtension(tabInfo: BrowserTabInfo, isFocus: Bool) {
        // Ensure we're connected when receiving updates
        if !isExtensionConnected {
            print("BrowserManager: ✅ Extension connection restored via tab update")
            isExtensionConnected = true
            delegate?.browserManager(self, didChangeConnectionState: true)
        }
        
        // Reset connection timeout timer since we got an update
        resetConnectionTimeoutTimer()
        
        let previousFocusState = self.isBrowserInFocus
        self.currentBrowserTab = tabInfo

        // Check if we should suppress focus activation
        let shouldSuppressFocus = shouldSuppressFocusActivation()
        let effectiveIsFocus = shouldSuppressFocus ? false : isFocus

        if shouldSuppressFocus && isFocus {
            print("BrowserManager: Suppressing focus activation for \(tabInfo.url) (recently added as focus URL)")
        }

        // Update focus state if changed
        if self.isBrowserInFocus != effectiveIsFocus {
            print("BrowserManager: Focus state changing from \(self.isBrowserInFocus) to \(effectiveIsFocus)")
            self.isBrowserInFocus = effectiveIsFocus

            // Immediately notify delegate of focus state change
            self.delegate?.browserManager(self, didChangeFocusState: effectiveIsFocus)

            if effectiveIsFocus {
                print("BrowserManager: ✅ Browser entered focus mode for \(tabInfo.url)")
            } else {
                print("BrowserManager: ❌ Browser exited focus mode - was on \(tabInfo.url)")
            }
        }

        // Always send tab update (unless it's a browser lost focus event)
        if tabInfo.url != "about:blank" {
            self.delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
        }

        if previousFocusState != effectiveIsFocus {
            print("BrowserManager: Browser focus state updated - \(effectiveIsFocus ? "FOCUS" : "NO FOCUS") for \(tabInfo.url)")
        }
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

        print("BrowserManager: Browser state - URL: \(currentURL), Focus: \(isFocus)")

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
        focusURLs = userDefaultsManager.load([FocusURL].self, forKey: "focusURLs") ?? []

        // Add default free presets if no URLs exist
        if focusURLs.isEmpty {
            focusURLs = FocusURL.freePresets
            saveFocusURLs()
            print("BrowserManager: Loaded \(focusURLs.count) default focus URLs")
        } else {
            print("BrowserManager: Loaded \(focusURLs.count) saved focus URLs")
        }

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
            return focusURLs.count < 3 // Free tier limit
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
    
    private func resetConnectionTimeoutTimer() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeoutInterval, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout()
        }
    }
    
    private func handleConnectionTimeout() {
        if isExtensionConnected {
            print("BrowserManager: ⚠️ Connection timeout - no updates from extension for \(connectionTimeoutInterval) seconds")
            isExtensionConnected = false
            delegate?.browserManager(self, didChangeConnectionState: false)
        }
    }
}
