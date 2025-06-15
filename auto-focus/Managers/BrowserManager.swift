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
    func notifyFocusSessionStarted()
    func notifyFocusSessionEnded()
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
            delegate?.browserManager(self, didUpdateExtensionHealth: extensionHealth)
        }
    }
    @Published var connectionQuality: ConnectionQuality = .unknown {
        didSet {
            delegate?.browserManager(self, didUpdateConnectionQuality: connectionQuality)
        }
    }

    weak var delegate: BrowserManagerDelegate?

    private let userDefaultsManager: any PersistenceManaging
    private let licenseManager: LicenseManager
    private var nativeMessagingTask: Process?
    private var messageQueue: [NativeMessage] = []
    private let nativeHost = NativeMessagingHost.shared

    private let httpServer = HTTPServer()

    // Suppress focus activation temporarily after adding a URL
    private var suppressFocusActivationUntil: Date?

    init(userDefaultsManager: any PersistenceManaging, licenseManager: LicenseManager = LicenseManager()) {
        self.userDefaultsManager = userDefaultsManager
        self.licenseManager = licenseManager

        loadFocusURLs()
        startHTTPServer()
    }

    deinit {
        stopNativeMessagingHost()
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
        sendFocusURLsToExtension()
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
        sendFocusURLsToExtension()
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func updateFocusURL(_ focusURL: FocusURL) {
        if let index = focusURLs.firstIndex(where: { $0.id == focusURL.id }) {
            focusURLs[index] = focusURL
            saveFocusURLs()
            sendFocusURLsToExtension()
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

    // MARK: - Native Messaging

    private func startHTTPServer() {
        print("BrowserManager: Starting HTTP server for browser extension")
        httpServer.setBrowserManager(self)
        httpServer.start()
    }

    func updateFromExtension(tabInfo: BrowserTabInfo, isFocus: Bool) {
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
            self.isExtensionConnected = true

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

    private func stopNativeMessagingHost() {
        nativeMessagingTask?.terminate()
        nativeMessagingTask = nil
        isExtensionConnected = false
    }

    private func sendMessageToExtension(_ message: NativeMessage) {
        if isExtensionConnected {
            // Send via native messaging host
            let messageDict: [String: Any] = [
                "command": message.command,
                "data": message.data?.mapValues { $0.value } ?? [:],
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
            nativeHost.sendMessage(messageDict)
            print("Sent to extension: \(message.command)")
        } else {
            // Queue messages for when extension connects
            messageQueue.append(message)
            print("Queued message for extension: \(message.command)")
        }
    }

    private func sendFocusURLsToExtension() {
        let message = NativeMessage(
            command: "update_focus_urls",
            data: [
                "urls": focusURLs.map { url in
                    [
                        "id": url.id.uuidString,
                        "domain": url.domain,
                        "name": url.name,
                        "matchType": url.matchType.rawValue,
                        "isEnabled": url.isEnabled,
                        "category": url.category.rawValue
                    ]
                }
            ]
        )
        sendMessageToExtension(message)
    }

    // MARK: - Message Handling (from Extension)

    func handleNativeMessage(_ message: NativeMessage) {
        switch message.command {
        case "handshake":
            handleHandshake(message)
        case "tab_changed":
            handleTabChanged(message)
        case "extension_state":
            handleExtensionState(message)
        default:
            print("Unknown message from extension: \(message.command)")
        }
    }

    private func handleHandshake(_ message: NativeMessage) {
        print("BrowserManager: Received handshake from extension")
        isExtensionConnected = true
        delegate?.browserManager(self, didChangeConnectionState: true)

        // Send response
        let response = NativeMessage(
            command: "handshake_response",
            data: ["status": "connected", "version": "1.0.0"]
        )
        sendMessageToExtension(response)

        // Send queued messages
        for queuedMessage in messageQueue {
            sendMessageToExtension(queuedMessage)
        }
        messageQueue.removeAll()

        print("BrowserManager: Extension connected, ready to receive tab updates")
    }

    private func handleTabChanged(_ message: NativeMessage) {
        guard let data = message.data else { return }

        let url = data["url"]?.value as? String ?? ""
        let title = data["title"]?.value as? String ?? ""

        print("BrowserManager: Tab changed to \(url)")

        let (isFocus, matchedURL) = checkIfURLIsFocus(url)

        let tabInfo = BrowserTabInfo(
            url: url,
            title: title,
            isFocusURL: isFocus,
            matchedFocusURL: matchedURL
        )

        DispatchQueue.main.async {
            self.currentBrowserTab = tabInfo

            // Update focus state if changed
            if self.isBrowserInFocus != isFocus {
                self.isBrowserInFocus = isFocus
                self.delegate?.browserManager(self, didChangeFocusState: isFocus)

                // Send focus state back to extension
                let response = NativeMessage(
                    command: "focus_state_changed",
                    data: ["isFocusActive": isFocus]
                )
                self.sendMessageToExtension(response)
            }

            self.delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
        }

        print("BrowserManager: URL \(url) is \(isFocus ? "FOCUS" : "NOT FOCUS")")
    }

    private func handleExtensionState(_ message: NativeMessage) {
        // Handle extension state updates
        print("Extension state update received")
    }

    // MARK: - Session Management Integration

    func notifyFocusSessionStarted() {
        let message = NativeMessage(
            command: "focus_session_started",
            data: ["timestamp": Date().timeIntervalSince1970]
        )
        sendMessageToExtension(message)
    }

    func notifyFocusSessionEnded() {
        let message = NativeMessage(
            command: "focus_session_ended",
            data: ["timestamp": Date().timeIntervalSince1970]
        )
        sendMessageToExtension(message)
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
        for preset in presets {
            if !focusURLs.contains(where: { $0.domain == preset.domain }) {
                addFocusURL(preset)
            }
        }
    }
}
