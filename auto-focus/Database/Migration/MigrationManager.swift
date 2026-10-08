import Foundation

final class MigrationManager {
    private static let migrationCompleteKey = "sqlite_migration_complete_v1"

    private static let legacyKeys = [
        "focusSessions", "focusApps", "focusURLs",
        "focusThreshold", "focusLossBuffer", "isPaused",
        "hasCompletedOnboarding", "timerDisplayMode"
    ]

    /// Row counts read from UserDefaults, used to verify nothing was lost in SQLite.
    private struct ExpectedCounts {
        var sessions = 0
        var apps = 0
        var urls = 0
    }

    static func migrateIfNeeded(
        sessionRepo: SessionRepository,
        focusAppRepo: FocusAppRepository,
        focusURLRepo: FocusURLRepository,
        settingsRepo: SettingsRepository,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: migrationCompleteKey) else {
            return
        }

        AppLogger.focus.info("Starting UserDefaults to SQLite migration")

        do {
            // Sessions, apps and URLs are critical: a decode or insert failure throws to the
            // outer catch so the flag stays unset and the legacy keys are kept for retry.
            var expected = ExpectedCounts()
            expected.sessions = try migrateRecords(
                FocusSession.self, key: "focusSessions", label: "sessions", defaults: defaults, insert: sessionRepo.insert
            )
            expected.apps = try migrateRecords(
                AppInfo.self, key: "focusApps", label: "focus apps", defaults: defaults, insert: focusAppRepo.insert
            )
            expected.urls = try migrateRecords(
                FocusURL.self, key: "focusURLs", label: "focus URLs", defaults: defaults, insert: focusURLRepo.insert
            )

            try migrateSettings(defaults: defaults, settingsRepo: settingsRepo)

            guard verifyMigration(
                expected: expected,
                sessionRepo: sessionRepo,
                focusAppRepo: focusAppRepo,
                focusURLRepo: focusURLRepo
            ) else {
                AppLogger.focus.error("Migration verification failed — keeping UserDefaults for retry", error: nil)
                return // Do NOT set flag, do NOT delete keys — retry next launch
            }

            // Verification passed — safe to clean up
            defaults.set(true, forKey: migrationCompleteKey)
            for key in legacyKeys {
                defaults.removeObject(forKey: key)
            }

            AppLogger.focus.info("Migration complete — UserDefaults keys removed")
        } catch {
            AppLogger.focus.error("Migration failed — will retry next launch", error: error)
            // Do NOT set flag — retry next launch
        }
    }

    /// Decodes a JSON array stored under `key` and inserts each element. Returns the number of
    /// records read, or 0 when the key is absent.
    private static func migrateRecords<Record: Decodable>(
        _ type: Record.Type,
        key: String,
        label: String,
        defaults: UserDefaults,
        insert: (Record) throws -> Void
    ) throws -> Int {
        guard let data = defaults.data(forKey: key) else { return 0 }

        let records = try JSONDecoder().decode([Record].self, from: data)
        for record in records {
            try insert(record)
        }
        AppLogger.focus.info("Migrated \(label)", metadata: [
            "count": String(records.count)
        ])
        return records.count
    }

    private static func migrateSettings(defaults: UserDefaults, settingsRepo: SettingsRepository) throws {
        let threshold = defaults.double(forKey: "focusThreshold")
        if threshold > 0 {
            try settingsRepo.setDouble(threshold, forKey: "focusThreshold")
        }

        let buffer = defaults.double(forKey: "focusLossBuffer")
        if buffer > 0 {
            try settingsRepo.setDouble(buffer, forKey: "focusLossBuffer")
        }

        let isPaused = defaults.bool(forKey: "isPaused")
        try settingsRepo.setBool(isPaused, forKey: "isPaused")

        let onboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        try settingsRepo.setBool(onboarding, forKey: "hasCompletedOnboarding")

        if let modeData = defaults.data(forKey: "timerDisplayMode") {
            do {
                let mode = try JSONDecoder().decode(TimerDisplayMode.self, from: modeData)
                try settingsRepo.setCodable(mode, forKey: "timerDisplayMode")
            } catch {
                AppLogger.focus.error("Failed to decode timerDisplayMode from UserDefaults", error: error)
            }
        }
    }

    /// Counts rows in SQLite and cross-checks them against the source data.
    private static func verifyMigration(
        expected: ExpectedCounts,
        sessionRepo: SessionRepository,
        focusAppRepo: FocusAppRepository,
        focusURLRepo: FocusURLRepository
    ) -> Bool {
        let actualSessions = (try? sessionRepo.fetchAll().count) ?? 0
        let actualApps = (try? focusAppRepo.fetchAll().count) ?? 0
        let actualURLs = (try? focusURLRepo.fetchAll().count) ?? 0

        AppLogger.focus.info("Migration verification", metadata: [
            "sessions": "\(actualSessions)/\(expected.sessions)",
            "apps": "\(actualApps)/\(expected.apps)",
            "urls": "\(actualURLs)/\(expected.urls)"
        ])

        return actualSessions >= expected.sessions
            && actualApps >= expected.apps
            && actualURLs >= expected.urls
    }
}
