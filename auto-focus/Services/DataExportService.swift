import AppKit
import Foundation

class DataExportService {
    private let focusManager: FocusManager
    private let licenseManager: LicenseManager

    init(focusManager: FocusManager, licenseManager: LicenseManager = LicenseManager()) {
        self.focusManager = focusManager
        self.licenseManager = licenseManager
    }

    func exportData(options: ExportOptions = .default) -> AutoFocusExportData {
        let sessions = options.includeSessions ? filterSessions(by: options.dateRange) : []
        let apps = options.includeFocusApps ? focusManager.focusApps : []
        let settings = options.includeSettings ? createUserSettings() : UserSettings(focusThreshold: 0, focusLossBuffer: 0, hasCompletedOnboarding: false)

        return AutoFocusExportData(
            metadata: ExportMetadata(),
            sessions: sessions,
            focusApps: apps,
            settings: settings
        )
    }

    func exportDataToFile(options: ExportOptions = .default) {
        guard licenseManager.isLicensed else {
            AppLogger.focus.warning("Export feature requires premium subscription")
            return
        }

        let data = exportData(options: options)

        do {
            let jsonData = try JSONEncoder().encode(data)

            let savePanel = NSSavePanel()
            savePanel.title = "Export Auto-Focus Data"
            savePanel.nameFieldStringValue = "auto-focus-export-\(DateFormatter.filenameSafe.string(from: Date()))"
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true

            savePanel.begin { result in
                if result == .OK, let url = savePanel.url {
                    do {
                        try jsonData.write(to: url)
                        AppLogger.focus.info("Export successful", metadata: [
                            "file_path": url.path,
                            "options": String(describing: options)
                        ])
                    } catch {
                        AppLogger.focus.error("Export failed", error: error, metadata: [
                            "file_path": url.path
                        ])
                    }
                }
            }
        } catch {
            AppLogger.focus.error("Export encoding failed", error: error)
        }
    }

    func importDataFromFile(completion: @escaping (ImportResult) -> Void) {
        guard licenseManager.isLicensed else {
            completion(.failure(.readError))
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Import Auto-Focus Data"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                self.importData(from: url) { importResult in
                    DispatchQueue.main.async {
                        completion(importResult)
                    }
                }
            }
        }
    }

    func importData(from url: URL, completion: @escaping (ImportResult) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(AutoFocusExportData.self, from: data)

            guard isVersionSupported(exportData.metadata.version) else {
                completion(.failure(.unsupportedVersion))
                return
            }

            let (sessionsImported, duplicatesSkipped) = importSessions(exportData.sessions)
            let appsImported = importFocusApps(exportData.focusApps)
            let settingsImported = importSettings(exportData.settings)

            let summary = ImportSummary(
                sessionsImported: sessionsImported,
                focusAppsImported: appsImported,
                settingsImported: settingsImported,
                duplicatesSkipped: duplicatesSkipped
            )

            completion(.success(summary))

        } catch DecodingError.dataCorrupted(_) {
            completion(.failure(.corruptedData))
        } catch DecodingError.typeMismatch(_, _) {
            completion(.failure(.invalidFileFormat))
        } catch {
            completion(.failure(.readError))
        }
    }

    // MARK: - Private Helpers

    private func filterSessions(by dateRange: DateRange?) -> [FocusSession] {
        guard let range = dateRange else { return focusManager.focusSessions }

        return focusManager.focusSessions.filter { session in
            session.startTime >= range.startDate && session.endTime <= range.endDate
        }
    }

    private func createUserSettings() -> UserSettings {
        return UserSettings(
            focusThreshold: focusManager.focusThreshold,
            focusLossBuffer: focusManager.focusLossBuffer,
            hasCompletedOnboarding: focusManager.hasCompletedOnboarding
        )
    }

    private func isVersionSupported(_ version: String) -> Bool {
        return version == "1.0"
    }

    private func importSessions(_ sessions: [FocusSession]) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0

        for session in sessions {
            let isDuplicate = focusManager.focusSessions.contains { existing in
                abs(existing.startTime.timeIntervalSince(session.startTime)) < 1.0 &&
                abs(existing.duration - session.duration) < 1.0
            }

            if !isDuplicate {
                focusManager.importSession(session)
                imported += 1
            } else {
                skipped += 1
            }
        }

        return (imported, skipped)
    }

    private func importFocusApps(_ apps: [AppInfo]) -> Int {
        var imported = 0

        for app in apps {
            let isDuplicate = focusManager.focusApps.contains { existing in
                existing.bundleIdentifier == app.bundleIdentifier
            }

            if !isDuplicate {
                focusManager.focusApps.append(app)
                imported += 1
            }
        }

        return imported
    }

    private func importSettings(_ settings: UserSettings) -> Bool {
        if settings.focusThreshold > 0 {
            focusManager.focusThreshold = settings.focusThreshold
        }

        if settings.focusLossBuffer > 0 {
            focusManager.focusLossBuffer = settings.focusLossBuffer
        }

        return true
    }
}
