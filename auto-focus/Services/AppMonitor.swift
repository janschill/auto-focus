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
    private var lastFocusAppActive = false
    private let appEventRepo: AppEventRepository?
    private var isScreenLocked = false

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
        observeScreenLockState()
        AppLogger.focus.info("App monitoring started", metadata: [
            "check_interval": String(format: "%.1f", checkInterval)
        ])
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        removeScreenLockObservers()
        AppLogger.focus.info("App monitoring stopped")
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
    }

    func resetState() {
        lastFocusAppActive = false
        currentApp = nil
    }

    // MARK: - Screen Lock Detection

    private func observeScreenLockState() {
        let workspaceNC = NSWorkspace.shared.notificationCenter
        workspaceNC.addObserver(self, selector: #selector(handleScreenSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceNC.addObserver(self, selector: #selector(handleScreenWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleScreenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleScreenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    private func removeScreenLockObservers() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleScreenSleep() {
        isScreenLocked = true
        AppLogger.focus.info("Screen sleep detected — pausing activity tracking")
    }

    @objc private func handleScreenWake() {
        isScreenLocked = false
        AppLogger.focus.info("Screen wake detected — resuming activity tracking")
    }

    @objc private func handleScreenLocked() {
        isScreenLocked = true
        AppLogger.focus.info("Screen locked — pausing activity tracking")
    }

    @objc private func handleScreenUnlocked() {
        isScreenLocked = false
        AppLogger.focus.info("Screen unlocked — resuming activity tracking")
    }

    // MARK: - Private Methods

    private func checkActiveApp() {
        guard !isScreenLocked else { return }
        guard let workspace = NSWorkspace.shared.frontmostApplication else { return }
        let currentAppBundleId = workspace.bundleIdentifier
        let previousApp = currentApp

        if let bundleId = currentAppBundleId, AppConfiguration.isScreenInactiveApp(bundleId) {
            return
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
