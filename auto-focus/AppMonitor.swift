import Foundation
import AppKit
import SwiftUI

protocol AppMonitorDelegate: AnyObject {
    func appMonitor(_ monitor: any AppMonitoring, didDetectFocusApp isActive: Bool)
}

class AppMonitor: ObservableObject, AppMonitoring {
    @Published var currentApp: String?
    @Published var isFocusAppActive = false

    private var timer: Timer?
    private let checkInterval: TimeInterval
    private var focusApps: [AppInfo] = []

    weak var delegate: AppMonitorDelegate?

    init(checkInterval: TimeInterval = AppConfiguration.checkInterval) {
        self.checkInterval = checkInterval
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkActiveApp()
        }
        print("App monitoring started")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("App monitoring stopped")
    }

    func updateFocusApps(_ apps: [AppInfo]) {
        focusApps = apps
    }

    // MARK: - Private Methods

    private func checkActiveApp() {
        guard let workspace = NSWorkspace.shared.frontmostApplication else { return }
        let currentAppBundleId = workspace.bundleIdentifier

        // Update current app
        currentApp = currentAppBundleId

        // Check if it's a focus app
        let isFocusApp = focusApps.contains { $0.bundleIdentifier == currentAppBundleId }

        // Only notify delegate if focus state changed
        if isFocusApp != isFocusAppActive {
            isFocusAppActive = isFocusApp
            delegate?.appMonitor(self, didDetectFocusApp: isFocusApp)
        }
    }

    deinit {
        stopMonitoring()
    }
}
