import AppKit
import Foundation
import SwiftUI

protocol AppMonitorDelegate: AnyObject {
    func appMonitor(_ monitor: any AppMonitoring, didDetectFocusApp isActive: Bool)
    func appMonitor(_ monitor: any AppMonitoring, didChangeToApp bundleIdentifier: String?)
}

class AppMonitor: ObservableObject, AppMonitoring {
    @Published var currentApp: String?

    private var timer: Timer?
    private let checkInterval: TimeInterval
    private var focusApps: [AppInfo] = []
    private var lastFocusAppActive = false // Track last state internally
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

        // Update current app
        currentApp = currentAppBundleId

        // Check if it's a focus app
        let isFocusApp = focusApps.contains { $0.bundleIdentifier == currentAppBundleId }

        // Notify delegate if app changed (for any app transition)
        if currentAppBundleId != previousApp {
            delegate?.appMonitor(self, didChangeToApp: currentAppBundleId)

            // Record app switch event
            if let bundleId = currentAppBundleId {
                let appName = workspace.localizedName
                let event = AppEvent(bundleIdentifier: bundleId, appName: appName)
                try? appEventRepo?.insert(event)
            }
        }

        // Only notify delegate if focus state changed
        if isFocusApp != lastFocusAppActive {
            lastFocusAppActive = isFocusApp
            delegate?.appMonitor(self, didDetectFocusApp: isFocusApp)
        }
    }

    deinit {
        stopMonitoring()
    }
}
