import Foundation

// MARK: - Export Data Models

struct AutoFocusExportData: Codable {
    let metadata: ExportMetadata
    let sessions: [FocusSession]
    let focusApps: [AppInfo]
    let settings: UserSettings
}

struct ExportMetadata: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String

    init() {
        self.version = "1.0"
        self.exportDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

struct UserSettings: Codable {
    let focusThreshold: TimeInterval
    let focusLossBuffer: TimeInterval
    let hasCompletedOnboarding: Bool
}

// MARK: - Import Result

enum ImportResult {
    case success(ImportSummary)
    case failure(ImportError)
}

struct ImportSummary {
    let sessionsImported: Int
    let focusAppsImported: Int
    let settingsImported: Bool
    let duplicatesSkipped: Int
}

enum ImportError: LocalizedError, Equatable {
    case invalidFileFormat
    case unsupportedVersion
    case corruptedData
    case readError
    case noDataFound

    var errorDescription: String? {
        switch self {
        case .invalidFileFormat:
            return "Invalid file format. Please select a valid Auto-Focus export file."
        case .unsupportedVersion:
            return "This export file was created with an unsupported version of Auto-Focus."
        case .corruptedData:
            return "The export file appears to be corrupted or incomplete."
        case .readError:
            return "Unable to read the selected file. Please check file permissions."
        case .noDataFound:
            return "No valid data found in the export file."
        }
    }
}

// MARK: - Export Options

struct ExportOptions {
    var includeSessions: Bool
    var includeSettings: Bool
    var includeFocusApps: Bool
    var dateRange: DateRange?

    static let `default` = ExportOptions(
        includeSessions: true,
        includeSettings: true,
        includeFocusApps: true,
        dateRange: nil
    )
}

struct DateRange: Codable {
    let startDate: Date
    let endDate: Date
}

// MARK: - File Operations

enum ExportFormat: String, CaseIterable {
    case json

    var fileExtension: String {
        return rawValue
    }

    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        }
    }

    var mimeType: String {
        switch self {
        case .json:
            return "application/json"
        }
    }
}
