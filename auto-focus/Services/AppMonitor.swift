import AppKit
import Foundation
import SwiftUI

protocol AppMonitorDelegate: AnyObject {
    func appMonitor(_ monitor: any AppMonitoring, didDetectFocusApp isActive: Bool)
    func appMonitor(_ monitor: any AppMonitoring, didChangeToApp bundleIdentifier: String?)
}

class AppMonitor: ObservableObject, AppMonitoring {
    @Published var currentApp: String?
    /// The last frontmost app that was not Auto-Focus itself.
    /// Used by MenuBarView to offer "Add current app" when the menu bar is clicked.
    @Published var previousNonSelfApp: String?
    @Published var previousNonSelfAppName: String?

    private var isMonitoring = false
    private var focusApps: [AppInfo] = []
    private var lastFocusAppActive = false
    /// Set on lock or sleep until an app is frontmost again; lock and sleep notifications arrive in bursts.
    private var isAway = false
    private let appEventRepo: AppEventRepository?

    weak var delegate: AppMonitorDelegate?

    init(appEventRepo: AppEventRepository? = AppEventRepository()) {
        self.appEventRepo = appEventRepo
    }

    // MARK: - Monitoring Control

    /// Starts observing app activation. Wake and unlock are observed too, because the app that
    /// was frontmost before the lock screen does not always post an activation when it returns.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let workspaceNC = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.didWakeNotification
        ] {
            workspaceNC.addObserver(self, selector: #selector(frontmostAppMayHaveChanged(_:)), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(frontmostAppMayHaveChanged(_:)),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            workspaceNC.addObserver(self, selector: #selector(userWentAway(_:)), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(userWentAway(_:)),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        checkActiveApp()
        AppLogger.focus.info("App monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        AppLogger.focus.info("App monitoring stopped")
    }

    func refresh() {
        guard isMonitoring else { return }
        checkActiveApp()
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
        // The frontmost app may have just become (or stopped being) a focus app
        refresh()
    }

    func resetState() {
        lastFocusAppActive = false
        currentApp = nil
    }

    // MARK: - Private Methods

    /// Records an away marker on lock or sleep, and forgets the current app so the frontmost app
    /// is recorded again on return — otherwise time after unlock would go unattributed.
    @objc private func userWentAway(_ notification: Notification) {
        guard !isAway else { return }
        isAway = true
        try? appEventRepo?.insert(AppEvent.awayMarker())
        currentApp = nil
    }

    @objc private func frontmostAppMayHaveChanged(_ notification: Notification) {
        // Prefer the activated app from the notification; frontmostApplication can lag behind it
        let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        checkActiveApp(activatedApp)
    }

    private func checkActiveApp(_ activatedApp: NSRunningApplication? = nil) {
        guard let workspace = activatedApp ?? NSWorkspace.shared.frontmostApplication else { return }
        let currentAppBundleId = workspace.bundleIdentifier
        let previousApp = currentApp

        if let bundleId = currentAppBundleId, AppConfiguration.isScreenInactiveApp(bundleId) {
            return
        }
        isAway = false

        if let bundleId = currentAppBundleId, bundleId != AppConfiguration.ownBundleId {
            previousNonSelfApp = bundleId
            previousNonSelfAppName = workspace.localizedName
        }

        currentApp = currentAppBundleId

        let isFocusApp = focusApps.contains { $0.bundleIdentifier == currentAppBundleId }

        if currentAppBundleId != previousApp {
            delegate?.appMonitor(self, didChangeToApp: currentAppBundleId)

            if let bundleId = currentAppBundleId {
                let appName = workspace.localizedName
                let event = AppEvent(bundleIdentifier: bundleId, appName: appName)
                try? appEventRepo?.insert(event)
            }
        }

        if isFocusApp != lastFocusAppActive {
            lastFocusAppActive = isFocusApp
            delegate?.appMonitor(self, didDetectFocusApp: isFocusApp)
        }
    }

    deinit {
        stopMonitoring()
    }
}
