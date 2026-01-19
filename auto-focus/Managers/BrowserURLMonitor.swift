import AppKit
import ApplicationServices
import Foundation

/// Monitors browser URL using macOS Accessibility API
/// Requires Accessibility permissions to function
class BrowserURLMonitor: ObservableObject {
    @Published var currentURL: String?
    @Published var currentTitle: String?
    @Published var hasAccessibilityPermission: Bool = false
    
    private var timer: Timer?
    private let checkInterval: TimeInterval
    private var lastURL: String?
    private var lastProcessedBrowserPID: pid_t?
    
    weak var delegate: BrowserURLMonitorDelegate?
    
    // Supported browser bundle identifiers
    private let supportedBrowsers: [String] = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Canary",
        "com.microsoft.Edge.Beta",
        "com.microsoft.Edge.Dev",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaNext",
        "com.operasoftware.OperaDeveloper",
        "com.vivaldi.Vivaldi",
        "com.arc.Arc"
    ]
    
    init(checkInterval: TimeInterval = 2.0) {
        self.checkInterval = checkInterval
        self.hasAccessibilityPermission = checkAccessibilityPermission()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard hasAccessibilityPermission else {
            AppLogger.browser.warning("Cannot start browser monitoring - no Accessibility permission")
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkBrowserURL()
        }
        
        AppLogger.browser.info("Browser URL monitoring started using Accessibility API", metadata: [
            "check_interval": String(format: "%.1f", checkInterval)
        ])
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        AppLogger.browser.info("Browser URL monitoring stopped")
    }
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        return trusted
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        if !trusted {
            AppLogger.browser.info("Requesting Accessibility permission for browser monitoring")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkBrowserURL() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier,
              supportedBrowsers.contains(bundleId) else {
            // Not a supported browser, clear state if needed
            if currentURL != nil {
                DispatchQueue.main.async {
                    self.currentURL = nil
                    self.currentTitle = nil
                    self.delegate?.browserURLMonitor(self, didUpdateURL: nil, title: nil)
                }
            }
            return
        }
        
        let pid = frontmostApp.processIdentifier
        
        // Get browser URL using Accessibility API
        if let urlString = getBrowserURL(pid: pid, bundleId: bundleId) {
            // Only notify if URL changed
            if urlString != lastURL {
                lastURL = urlString
                DispatchQueue.main.async {
                    self.currentURL = urlString
                    self.currentTitle = self.getBrowserTitle(pid: pid, bundleId: bundleId)
                    self.delegate?.browserURLMonitor(self, didUpdateURL: urlString, title: self.currentTitle)
                }
                
                AppLogger.browser.info("Browser URL changed", metadata: [
                    "url": urlString,
                    "browser": bundleId
                ])
            }
        }
    }
    
    private func getBrowserURL(pid: pid_t, bundleId: String) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        
        // Different browsers expose URLs differently
        // Try multiple strategies
        
        // Strategy 1: Try to get URL from focused window/element
        if let url = getURLFromFocusedElement(appElement, bundleId: bundleId) {
            return url
        }
        
        // Strategy 2: Try to get URL from windows
        if let url = getURLFromWindows(appElement, bundleId: bundleId) {
            return url
        }
        
        return nil
    }
    
    private func getURLFromFocusedElement(_ appElement: AXUIElement, bundleId: String) -> String? {
        var focusedElement: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard error == .success, let focused = focusedElement else {
            return nil
        }
        
        // Try to get URL directly from focused element
        if let url = getURLAttribute(focused as! AXUIElement) {
            return url
        }
        
        // For Chrome-based browsers, try to navigate to address bar
        if bundleId.contains("Chrome") || bundleId.contains("Edge") || bundleId.contains("Brave") || bundleId.contains("Arc") {
            // Chrome exposes URL through the address bar (AXTextField with specific role)
            if let url = getChromeBasedURL(appElement) {
                return url
            }
        }
        
        // For Safari, try document attribute
        if bundleId.contains("Safari") {
            if let url = getSafariURL(appElement) {
                return url
            }
        }
        
        return nil
    }
    
    private func getURLFromWindows(_ appElement: AXUIElement, bundleId: String) -> String? {
        var windowList: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        guard error == .success,
              let windows = windowList as? [AXUIElement],
              !windows.isEmpty else {
            return nil
        }
        
        // Try main window first
        if let mainWindow = windows.first {
            if let url = getURLFromWindow(mainWindow, bundleId: bundleId) {
                return url
            }
        }
        
        return nil
    }
    
    private func getURLFromWindow(_ window: AXUIElement, bundleId: String) -> String? {
        // Try to get URL attribute directly
        if let url = getURLAttribute(window) {
            return url
        }
        
        // Try to navigate through window hierarchy
        // Different browsers have different hierarchies
        var children: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children)
        
        guard error == .success, let childElements = children as? [AXUIElement] else {
            return nil
        }
        
        // Search through children for URL
        for child in childElements {
            if let url = searchElementForURL(child, depth: 0, maxDepth: 3) {
                return url
            }
        }
        
        return nil
    }
    
    private func searchElementForURL(_ element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }
        
        // Try to get URL from current element
        if let url = getURLAttribute(element) {
            return url
        }
        
        // Try to get value if it's a text field and looks like a URL
        var value: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if valueError == .success, let stringValue = value as? String {
            if stringValue.starts(with: "http://") || stringValue.starts(with: "https://") {
                return stringValue
            }
        }
        
        // Recurse into children
        var children: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if error == .success, let childElements = children as? [AXUIElement] {
            for child in childElements {
                if let url = searchElementForURL(child, depth: depth + 1, maxDepth: maxDepth) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func getChromeBasedURL(_ appElement: AXUIElement) -> String? {
        // Chrome-based browsers typically have the URL in an address bar text field
        // Look for AXTextField with subrole AXSearchField
        var children: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &children)
        
        guard error == .success, let childElements = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childElements {
            if let url = findAddressBar(child, depth: 0, maxDepth: 5) {
                return url
            }
        }
        
        return nil
    }
    
    private func findAddressBar(_ element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }
        
        // Check if this element is an address bar
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String, roleString == kAXTextFieldRole as String {
            // This might be an address bar, try to get its value
            var value: CFTypeRef?
            let valueError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            
            if valueError == .success, let stringValue = value as? String {
                // Check if it looks like a URL
                if stringValue.starts(with: "http://") || stringValue.starts(with: "https://") || stringValue.contains(".") {
                    return stringValue.starts(with: "http") ? stringValue : "https://\(stringValue)"
                }
            }
        }
        
        // Recurse into children
        var children: CFTypeRef?
        let childError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if childError == .success, let childElements = children as? [AXUIElement] {
            for child in childElements {
                if let url = findAddressBar(child, depth: depth + 1, maxDepth: maxDepth) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func getSafariURL(_ appElement: AXUIElement) -> String? {
        // Safari exposes URL through AXDocument attribute
        var windows: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        guard error == .success,
              let windowList = windows as? [AXUIElement],
              let mainWindow = windowList.first else {
            return nil
        }
        
        // Try to get document from window
        var document: CFTypeRef?
        let docError = AXUIElementCopyAttributeValue(mainWindow, "AXDocument" as CFString, &document)
        
        if docError == .success, let urlString = document as? String {
            return urlString
        }
        
        // Alternative: look for URL attribute
        return getURLAttribute(mainWindow)
    }
    
    private func getURLAttribute(_ element: AXUIElement) -> String? {
        var urlValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlValue)
        
        if error == .success {
            if let url = urlValue as? URL {
                return url.absoluteString
            } else if let urlString = urlValue as? String {
                return urlString
            }
        }
        
        return nil
    }
    
    private func getBrowserTitle(pid: pid_t, bundleId: String) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        
        var windows: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        guard error == .success,
              let windowList = windows as? [AXUIElement],
              let mainWindow = windowList.first else {
            return nil
        }
        
        var title: CFTypeRef?
        let titleError = AXUIElementCopyAttributeValue(mainWindow, kAXTitleAttribute as CFString, &title)
        
        if titleError == .success, let titleString = title as? String {
            return titleString
        }
        
        return nil
    }
    
    deinit {
        stopMonitoring()
    }
}

protocol BrowserURLMonitorDelegate: AnyObject {
    func browserURLMonitor(_ monitor: BrowserURLMonitor, didUpdateURL url: String?, title: String?)
}
