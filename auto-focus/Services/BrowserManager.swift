import AppKit
import Combine
import Foundation

protocol BrowserManaging: AnyObject, ObservableObject {
    var focusURLs: [FocusURL] { get }
    var currentBrowserTab: BrowserTabInfo? { get }
    var isBrowserInFocus: Bool { get }
    var delegate: BrowserManagerDelegate? { get set }
    var canAddMoreURLs: Bool { get }
    var availablePresets: [FocusURL] { get }

    func addFocusURL(_ focusURL: FocusURL)
    func removeFocusURL(_ focusURL: FocusURL)
    func updateFocusURL(_ focusURL: FocusURL)
    func checkIfURLIsFocus(_ url: String) -> (isFocus: Bool, matchedURL: FocusURL?)
    func addPresetURLs(_ presets: [FocusURL])
    func startPolling()
    func stopPolling()
}

protocol BrowserManagerDelegate: AnyObject {
    func browserManager(_ manager: any BrowserManaging, didChangeFocusState isFocus: Bool)
    func browserManager(_ manager: any BrowserManaging, didReceiveTabUpdate tabInfo: BrowserTabInfo)
    func browserManager(_ manager: any BrowserManaging, didUpdateFocusURLs urls: [FocusURL])
}

class BrowserManager: ObservableObject, BrowserManaging {
    @Published var focusURLs: [FocusURL] = []
    @Published var currentBrowserTab: BrowserTabInfo?
    @Published var isBrowserInFocus: Bool = false

    weak var delegate: BrowserManagerDelegate?

    private let focusURLRepo: FocusURLRepository
    private let licenseManager: LicenseManager
    private let appEventRepo: AppEventRepository?
    private var urlObservationCancellable: AnyCancellable?
    private var lastRecordedURL: String?

    private var pollingTimer: Timer?
    private var deniedAutomationBrowsers: Set<String> = []

    init(focusURLRepo: FocusURLRepository = FocusURLRepository(), licenseManager: LicenseManager = LicenseManager(), appEventRepo: AppEventRepository? = AppEventRepository()) {
        self.focusURLRepo = focusURLRepo
        self.licenseManager = licenseManager
        self.appEventRepo = appEventRepo

        loadFocusURLs()

        urlObservationCancellable = focusURLRepo.observeAll()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] urls in
                    self?.focusURLs = urls
                }
            )
    }

    // MARK: - Polling

    func startPolling() {
        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollCurrentURL()
        }
        // Poll immediately on start
        pollCurrentURL()
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollCurrentURL() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              AppConfiguration.isSupportedBrowser(bundleId) else {
            return
        }

        let appName = frontApp.localizedName ?? bundleId
        let isSafari = AppConfiguration.isSafari(bundleId)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let url = self.executeURLAppleScript(appName: appName, isSafari: isSafari) else {
                return
            }

            DispatchQueue.main.async {
                self.handlePolledURL(url, appName: appName, bundleId: bundleId)
            }
        }
    }

    private func executeURLAppleScript(appName: String, isSafari: Bool) -> String? {
        let script: String
        if isSafari {
            script = "tell application \"\(appName)\" to return URL of front document"
        } else {
            script = "tell application \"\(appName)\" to return URL of active tab of front window"
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var errorInfo: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743 = not authorized (Automation permission denied)
            // -600 = app not running
            // -1728 = no front window/document
            if errorNumber == -1743 {
                if !deniedAutomationBrowsers.contains(appName) {
                    deniedAutomationBrowsers.insert(appName)
                    AppLogger.browser.warning("Automation permission denied for browser", metadata: [
                        "browser": appName
                    ])
                }
            }
            return nil
        }

        return result.stringValue
    }

    private func handlePolledURL(_ url: String, appName: String, bundleId: String) {
        let (isFocus, matchedURL) = checkIfURLIsFocus(url)

        let tabInfo = BrowserTabInfo(
            url: url,
            title: appName,
            isFocusURL: isFocus,
            matchedFocusURL: matchedURL
        )

        currentBrowserTab = tabInfo
        recordBrowserEvent(tabInfo: tabInfo, bundleId: bundleId)

        if isBrowserInFocus != isFocus {
            AppLogger.browser.stateChange(
                from: String(isBrowserInFocus),
                to: String(isFocus),
                metadata: ["url": url]
            )
            isBrowserInFocus = isFocus
            delegate?.browserManager(self, didChangeFocusState: isFocus)
        } else if isFocus && isBrowserInFocus {
            delegate?.browserManager(self, didChangeFocusState: true)
        }

        delegate?.browserManager(self, didReceiveTabUpdate: tabInfo)
    }

    private func recordBrowserEvent(tabInfo: BrowserTabInfo, bundleId: String) {
        let url = tabInfo.url
        guard url != "about:blank", url != lastRecordedURL else { return }
        lastRecordedURL = url

        let domain = AppEvent.extractDomain(from: url)
        let event = AppEvent(bundleIdentifier: bundleId, appName: tabInfo.title, url: url, domain: domain)
        do {
            try appEventRepo?.insert(event)
        } catch {
            AppLogger.browser.error("Failed to record browser event", error: error)
        }
    }

    // MARK: - Focus URL Management

    func addFocusURL(_ focusURL: FocusURL) {
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

        do {
            try focusURLRepo.insert(focusURL)
        } catch {
            AppLogger.browser.error("Failed to insert focus URL", error: error)
        }
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func removeFocusURL(_ focusURL: FocusURL) {
        do {
            try focusURLRepo.delete(focusURL)
        } catch {
            AppLogger.browser.error("Failed to delete focus URL", error: error)
        }
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func updateFocusURL(_ focusURL: FocusURL) {
        do {
            try focusURLRepo.update(focusURL)
        } catch {
            AppLogger.browser.error("Failed to update focus URL", error: error)
        }
        delegate?.browserManager(self, didUpdateFocusURLs: focusURLs)
    }

    func checkIfURLIsFocus(_ url: String) -> (isFocus: Bool, matchedURL: FocusURL?) {
        for focusURL in focusURLs where focusURL.isEnabled {
            if focusURL.matches(url) {
                return (true, focusURL)
            }
        }
        return (false, nil)
    }

    // MARK: - Persistence

    private func loadFocusURLs() {
        var loadedURLs = (try? focusURLRepo.fetchAll()) ?? []

        if loadedURLs.isEmpty {
            for preset in FocusURL.freePresets {
                try? focusURLRepo.insert(preset)
            }
            loadedURLs = (try? focusURLRepo.fetchAll()) ?? FocusURL.freePresets
            AppLogger.browser.info("Loaded default focus URLs", metadata: [
                "count": String(loadedURLs.count)
            ])
        } else {
            AppLogger.browser.info("Loaded saved focus URLs", metadata: [
                "count": String(loadedURLs.count)
            ])
        }

        focusURLs = loadedURLs

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.delegate?.browserManager(self, didUpdateFocusURLs: self.focusURLs)
        }
    }

    // MARK: - Premium Features

    var canAddMoreURLs: Bool {
        if licenseManager.isLicensed {
            return true
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
}
