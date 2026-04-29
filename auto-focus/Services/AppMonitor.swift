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

    private var timer: Timer?
    private let checkInterval: TimeInterval
    private var focusApps: [AppInfo] = []
    private var lastFocusAppActive = false
    private let appEventRepo: AppEventRepository?

    weak var delegate: AppMonitorDelegate?

    init(checkInterval: TimeInterval = AppConfiguration.checkInterval, appEventRepo: AppEventRepository? = AppEventRepository()) {
        self.checkInterval = checkInterval
        self.appEventRepo = appEventRepo
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkActiveApp()
        }
        AppLogger.focus.info("App monitoring started", metadata: [
            "check_interval": String(format: "%.1f", checkInterval)
        ])
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        AppLogger.focus.info("App monitoring stopped")
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
    }

    func resetState() {
        lastFocusAppActive = false
        currentApp = nil
    }

    // MARK: - Private Methods

    private func checkActiveApp() {
        guard let workspace = NSWorkspace.shared.frontmostApplication else { return }
        let currentAppBundleId = workspace.bundleIdentifier
        let previousApp = currentApp

        if let bundleId = currentAppBundleId, AppConfiguration.isScreenInactiveApp(bundleId) {
            return
        }

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
