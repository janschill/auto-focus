import Foundation

final class MigrationManager {
    private static let migrationCompleteKey = "sqlite_migration_complete_v1"

    static func migrateIfNeeded(
        sessionRepo: SessionRepository,
        focusAppRepo: FocusAppRepository,
        focusURLRepo: FocusURLRepository,
        settingsRepo: SettingsRepository
    ) {
        guard !UserDefaults.standard.bool(forKey: migrationCompleteKey) else {
            return
        }

        AppLogger.focus.info("Starting UserDefaults to SQLite migration")

        // Track what we expect vs what landed in SQLite
        var expectedSessions = 0
        var expectedApps = 0
        var expectedURLs = 0

        do {
            // Migrate sessions
            if let sessionsData = UserDefaults.standard.data(forKey: "focusSessions") {
                do {
                    let sessions = try JSONDecoder().decode([FocusSession].self, from: sessionsData)
                    expectedSessions = sessions.count
                    for session in sessions {
                        try sessionRepo.insert(session)
                    }
                    AppLogger.focus.info("Migrated sessions", metadata: [
                        "count": String(sessions.count)
                    ])
                } catch {
                    AppLogger.focus.error("Failed to decode sessions from UserDefaults", error: error)
                }
            }

            // Migrate focus apps
            if let appsData = UserDefaults.standard.data(forKey: "focusApps") {
                do {
                    let apps = try JSONDecoder().decode([AppInfo].self, from: appsData)
                    expectedApps = apps.count
                    for app in apps {
                        try focusAppRepo.insert(app)
                    }
                    AppLogger.focus.info("Migrated focus apps", metadata: [
                        "count": String(apps.count)
                    ])
                } catch {
                    AppLogger.focus.error("Failed to decode focus apps from UserDefaults", error: error)
                }
            }

            // Migrate focus URLs
            if let urlsData = UserDefaults.standard.data(forKey: "focusURLs") {
                do {
                    let urls = try JSONDecoder().decode([FocusURL].self, from: urlsData)
                    expectedURLs = urls.count
                    for url in urls {
                        try focusURLRepo.insert(url)
                    }
                    AppLogger.focus.info("Migrated focus URLs", metadata: [
                        "count": String(urls.count)
                    ])
                } catch {
                    AppLogger.focus.error("Failed to decode focus URLs from UserDefaults", error: error)
                }
            }

            // Migrate settings
            let threshold = UserDefaults.standard.double(forKey: "focusThreshold")
            if threshold > 0 {
                try settingsRepo.setDouble(threshold, forKey: "focusThreshold")
            }

            let buffer = UserDefaults.standard.double(forKey: "focusLossBuffer")
            if buffer > 0 {
                try settingsRepo.setDouble(buffer, forKey: "focusLossBuffer")
            }

            let isPaused = UserDefaults.standard.bool(forKey: "isPaused")
            try settingsRepo.setBool(isPaused, forKey: "isPaused")

            let onboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            try settingsRepo.setBool(onboarding, forKey: "hasCompletedOnboarding")

            if let modeData = UserDefaults.standard.data(forKey: "timerDisplayMode") {
                do {
                    let mode = try JSONDecoder().decode(TimerDisplayMode.self, from: modeData)
                    try settingsRepo.setCodable(mode, forKey: "timerDisplayMode")
                } catch {
                    AppLogger.focus.error("Failed to decode timerDisplayMode from UserDefaults", error: error)
                }
            }

            // Verify: count rows in SQLite and cross-check against source data
            let actualSessions = (try? sessionRepo.fetchAll().count) ?? 0
            let actualApps = (try? focusAppRepo.fetchAll().count) ?? 0
            let actualURLs = (try? focusURLRepo.fetchAll().count) ?? 0

            AppLogger.focus.info("Migration verification", metadata: [
                "sessions": "\(actualSessions)/\(expectedSessions)",
                "apps": "\(actualApps)/\(expectedApps)",
                "urls": "\(actualURLs)/\(expectedURLs)",
            ])

            if actualSessions < expectedSessions
                || actualApps < expectedApps
                || actualURLs < expectedURLs
            {
                AppLogger.focus.error("Migration verification failed — keeping UserDefaults for retry", error: nil)
                return // Do NOT set flag, do NOT delete keys — retry next launch
            }

            // Verification passed — safe to clean up
            UserDefaults.standard.set(true, forKey: migrationCompleteKey)

            let keysToRemove = [
                "focusSessions", "focusApps", "focusURLs",
                "focusThreshold", "focusLossBuffer", "isPaused",
                "hasCompletedOnboarding", "timerDisplayMode",
            ]
            for key in keysToRemove {
                UserDefaults.standard.removeObject(forKey: key)
            }

            AppLogger.focus.info("Migration complete — UserDefaults keys removed")
        } catch {
            AppLogger.focus.error("Migration failed — will retry next launch", error: error)
            // Do NOT set flag — retry next launch
        }
    }
}
