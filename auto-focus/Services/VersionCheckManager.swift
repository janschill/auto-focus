import Foundation
import SwiftUI

/// Manages version checking and update notifications for Auto-Focus.
///
/// **Version Format Consistency:**
/// The app compares versions using semantic versioning (e.g., "2025.07.31" or "1.2.3").
/// For accurate update detection, ensure `CFBundleShortVersionString` in Info.plist
/// matches the format used in `version.json` (currently date-based: YYYY.MM.DD).
/// The Makefile generates date-based versions automatically.
class VersionCheckManager: ObservableObject {
    /// Shared instance for app-wide version checking.
    /// All views should use this shared instance to ensure consistent update state.
    static let shared = VersionCheckManager()

    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var currentVersion: String = ""
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?

    private let logger = AppLogger.version
    private let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let versionCheckURL = "https://auto-focus.app/downloads/version.json"
    private let userDefaults = UserDefaults.standard
    private let lastCheckKey = "AutoFocus_LastVersionCheck"
    private let lastVersionKey = "AutoFocus_LastKnownVersion"
    private let updateAvailableKey = "AutoFocus_UpdateAvailable"
    private let downloadURLKey = "AutoFocus_DownloadURL"

    private var downloadURL: String? {
        get {
            userDefaults.string(forKey: downloadURLKey)
        }
        set {
            if let url = newValue {
                userDefaults.set(url, forKey: downloadURLKey)
            } else {
                userDefaults.removeObject(forKey: downloadURLKey)
            }
        }
    }

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        loadPersistedData()

        logger.debug("VersionCheckManager initialized", metadata: [
            "current_version": currentVersion
        ])

        // Check for updates on initialization if enough time has passed
        if shouldCheckForUpdates() {
            checkForUpdates()
        }
    }

    private func loadPersistedData() {
        lastCheckDate = userDefaults.object(forKey: lastCheckKey) as? Date
        latestVersion = userDefaults.string(forKey: lastVersionKey) ?? ""
        isUpdateAvailable = userDefaults.bool(forKey: updateAvailableKey)
        // downloadURL is loaded via its computed property
    }

    private func persistData() {
        userDefaults.set(lastCheckDate, forKey: lastCheckKey)
        userDefaults.set(latestVersion, forKey: lastVersionKey)
        userDefaults.set(isUpdateAvailable, forKey: updateAvailableKey)
    }

    func checkForUpdates() {
        guard !isChecking else {
            logger.debug("Update check already in progress, skipping")
            return
        }

        isChecking = true
        logger.info("Checking for updates", metadata: [
            "current_version": currentVersion,
            "check_url": versionCheckURL
        ])

        guard let url = URL(string: versionCheckURL) else {
            logger.error("Invalid version check URL", metadata: [
                "url": versionCheckURL
            ])
            isChecking = false
            return
        }

        // Create a URL request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10 second timeout

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleVersionResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleVersionResponse(data: Data?, response: URLResponse?, error: Error?) {
        defer {
            isChecking = false
        }

        guard let versionInfo = parseVersionResponse(data: data, response: response, error: error) else {
            lastCheckDate = Date()
            persistData()
            return
        }

        latestVersion = versionInfo.version
        if let downloadURLString = versionInfo.downloadURL {
            downloadURL = downloadURLString
            logger.debug("Download URL found in version.json", metadata: [
                "download_url": downloadURLString
            ])
        } else {
            // Fallback to default download URL if not specified
            downloadURL = "https://auto-focus.app/downloads/Auto-Focus.zip"
        }

        lastCheckDate = Date()
        let isNewer = isVersionNewer(latestVersion, than: currentVersion)
        isUpdateAvailable = isNewer
        logger.info("Version check completed", metadata: [
            "current_version": currentVersion,
            "latest_version": latestVersion,
            "update_available": String(isNewer)
        ])

        persistData()
    }

    /// Validates the version check response and extracts the version and optional download URL.
    /// Logs and returns nil on any network, HTTP or parsing failure.
    private func parseVersionResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> (version: String, downloadURL: String?)? {
        if let error = error {
            logger.error("Failed to check for updates", error: error, metadata: [
                "current_version": currentVersion
            ])
            return nil
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            logger.error("Version check returned non-200 status", metadata: [
                "status_code": String(httpResponse.statusCode),
                "current_version": currentVersion
            ])
            return nil
        }

        guard let data = data else {
            logger.error("No data received from version check", metadata: [
                "current_version": currentVersion
            ])
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let jsonString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            logger.error("Failed to parse version JSON", metadata: [
                "current_version": currentVersion,
                "data_length": String(data.count),
                "response_preview": String(jsonString.prefix(200))
            ])
            return nil
        }

        guard let versionString = json["version"] as? String else {
            logger.error("Version key not found in JSON", metadata: [
                "current_version": currentVersion,
                "json_keys": Array(json.keys).joined(separator: ", ")
            ])
            return nil
        }

        logger.debug("Successfully parsed version from JSON", metadata: [
            "version": versionString,
            "current_version": currentVersion
        ])
        return (versionString, json["download_url"] as? String)
    }

    private func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        return Date().timeIntervalSince(lastCheck) > checkInterval
    }

    private func isVersionNewer(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(newComponents.count, currentComponents.count)

        for i in 0..<maxLength {
            let newValue = i < newComponents.count ? newComponents[i] : 0
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0

            if newValue > currentValue {
                return true
            } else if newValue < currentValue {
                return false
            }
        }

        return false
    }

    func openDownloadPage() {
        // Prefer direct download URL if available, otherwise fall back to website
        let urlString = downloadURL ?? "https://auto-focus.app"

        guard let url = URL(string: urlString) else {
            logger.error("Invalid download URL", metadata: [
                "url": urlString
            ])
            // Fallback to website if URL is invalid
            if let fallbackURL = URL(string: "https://auto-focus.app") {
                NSWorkspace.shared.open(fallbackURL)
            }
            return
        }

        logger.info("Opening download URL", metadata: [
            "url": urlString,
            "latest_version": latestVersion
        ])

        NSWorkspace.shared.open(url)
    }
}
