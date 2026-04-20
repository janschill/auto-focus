import AppKit
import ApplicationServices
import Foundation

/// Queries and manages macOS Automation (AppleEvents) TCC permission for browser targets.
///
/// This is the single consumer of `AEDeterminePermissionToAutomateTarget`. All browser permission
/// state in the app flows through `statuses` here.
protocol AETargetPermissionChecking {
    func checkPermission(bundleId: String, askUserIfNeeded: Bool) -> OSStatus
}

final class AutomationPermissionService: ObservableObject {
    @Published private(set) var statuses: [String: BrowserPermissionStatus] = [:]

    private let checker: AETargetPermissionChecking
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var trackedBundleIds: Set<String> = []

    init(checker: AETargetPermissionChecking = AEDetermineChecker()) {
        self.checker = checker
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.trackedBundleIds.isEmpty else { return }
            self.refreshAll(bundleIds: Array(self.trackedBundleIds))
        }
    }

    deinit {
        if let didBecomeActiveObserver = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    func status(for bundleId: String) -> BrowserPermissionStatus {
        statuses[bundleId] ?? .unknown
    }

    /// Non-prompting query. Safe to call on view appear / app foreground.
    func refreshAll(bundleIds: [String]) {
        trackedBundleIds.formUnion(bundleIds)
        var updated = statuses
        var changed = false
        for bundleId in bundleIds {
            let status = BrowserPermissionStatus.from(
                osStatus: checker.checkPermission(bundleId: bundleId, askUserIfNeeded: false)
            )
            if updated[bundleId] != status {
                updated[bundleId] = status
                changed = true
            }
        }
        if changed {
            statuses = updated
        }
    }

    /// Non-prompting query for a single browser.
    @discardableResult
    func refresh(bundleId: String) -> BrowserPermissionStatus {
        trackedBundleIds.insert(bundleId)
        let status = BrowserPermissionStatus.from(
            osStatus: checker.checkPermission(bundleId: bundleId, askUserIfNeeded: false)
        )
        if statuses[bundleId] != status {
            statuses[bundleId] = status
        }
        return status
    }

    /// Prompting query. Temporarily promotes activation policy so the TCC dialog surfaces
    /// from a menu bar (.accessory) app. Returns the resolved status.
    @discardableResult
    func requestPermission(bundleId: String) -> BrowserPermissionStatus {
        trackedBundleIds.insert(bundleId)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let result = checker.checkPermission(bundleId: bundleId, askUserIfNeeded: true)

        NSApp.setActivationPolicy(previousPolicy)

        let status = BrowserPermissionStatus.from(osStatus: result)
        if statuses[bundleId] != status {
            statuses[bundleId] = status
        }
        AppLogger.browser.info("Automation permission request completed", metadata: [
            "bundleId": bundleId,
            "status": status.rawValue,
            "osStatus": String(result)
        ])
        return status
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

/// Default wrapper around `AEDeterminePermissionToAutomateTarget`.
struct AEDetermineChecker: AETargetPermissionChecking {
    func checkPermission(bundleId: String, askUserIfNeeded: Bool) -> OSStatus {
        var bundleIdBytes = Array(bundleId.utf8)
        var target = AEAddressDesc()
        let createStatus = bundleIdBytes.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            AECreateDesc(
                AEDescType(typeApplicationBundleID),
                buffer.baseAddress,
                buffer.count,
                &target
            )
        }
        guard createStatus == noErr else {
            return createStatus
        }
        defer { AEDisposeDesc(&target) }

        // typeWildCard for event class/id is Apple's recommended pre-flight form:
        // it authorizes AppleEvents dispatch to the target without actually executing one.
        return AEDeterminePermissionToAutomateTarget(
            &target,
            AEEventClass(typeWildCard),
            AEEventID(typeWildCard),
            askUserIfNeeded
        )
    }
}
