import Combine
import Foundation

/// Persists which browsers the user has opted in to automation for, and caches the last observed
/// permission status for immediate paint on launch.
///
/// Single row in the `setting` table, key `browserEnablements`, JSON-encoded `[String: BrowserEnablement]`.
final class BrowserEnablementStore: ObservableObject {
    static let storageKey = "browserEnablements"
    static let migrationVersionKey = "browserEnablementsMigrationVersion"

    @Published private(set) var enablements: [String: BrowserEnablement]

    private let settingsRepo: SettingsRepository

    init(settingsRepo: SettingsRepository = SettingsRepository()) {
        self.settingsRepo = settingsRepo
        self.enablements = settingsRepo.getCodable(
            [String: BrowserEnablement].self,
            forKey: BrowserEnablementStore.storageKey
        ) ?? [:]
    }

    /// Initial-migration entry point: seed enablements if the key has never been written.
    /// Returns true if migration was applied.
    @discardableResult
    func runInitialMigrationIfNeeded(installedBundleIds: [String], hasExistingFocusURLs: Bool) -> Bool {
        guard settingsRepo.getString(forKey: BrowserEnablementStore.storageKey) == nil else {
            return false
        }

        var seeded: [String: BrowserEnablement] = [:]
        if hasExistingFocusURLs {
            for bundleId in installedBundleIds {
                seeded[bundleId] = BrowserEnablement(isEnabled: true, lastPermissionStatus: .unknown)
            }
        }
        enablements = seeded
        persist()
        try? settingsRepo.setString("1", forKey: BrowserEnablementStore.migrationVersionKey)
        return true
    }

    func isEnabled(_ bundleId: String) -> Bool {
        enablements[bundleId]?.isEnabled ?? false
    }

    func setEnabled(_ enabled: Bool, for bundleId: String) {
        var entry = enablements[bundleId] ?? BrowserEnablement(isEnabled: false, lastPermissionStatus: .unknown)
        entry.isEnabled = enabled
        enablements[bundleId] = entry
        persist()
    }

    func updateCachedStatus(_ status: BrowserPermissionStatus, for bundleId: String) {
        var entry = enablements[bundleId] ?? BrowserEnablement(isEnabled: false, lastPermissionStatus: .unknown)
        guard entry.lastPermissionStatus != status else { return }
        entry.lastPermissionStatus = status
        enablements[bundleId] = entry
        persist()
    }

    func allEnabledBundleIds() -> Set<String> {
        Set(enablements.filter { $0.value.isEnabled }.keys)
    }

    private func persist() {
        do {
            try settingsRepo.setCodable(enablements, forKey: BrowserEnablementStore.storageKey)
        } catch {
            AppLogger.browser.error("Failed to persist browser enablements", error: error)
        }
    }
}
