import CryptoKit
import Foundation
import SwiftUI

class LicenseManager: ObservableObject {
    @Published var isLicensed: Bool = false
    @Published var licenseKey: String = "" {
        didSet {
            saveLicenseKey()
            if !licenseKey.isEmpty {
                validateLicense()
            }
        }
    }
    @Published var licenseStatus: LicenseStatus = .inactive
    @Published var licenseOwner: String = ""
    @Published var licenseEmail: String = ""
    @Published var licenseExpiry: Date?
    @Published var isActivating: Bool = false
    @Published var validationError: String?
    @Published var lastValidationDate: Date?
    @Published var appVersion: String = ""
    @Published var maxAppsAllowed: Int = 3

    private let userDefaults = UserDefaults.standard
    private let licenseKeyKey = "AutoFocus_LicenseKey"
    private let licenseDataKey = "AutoFocus_LicenseData"
    private let lastValidationKey = "AutoFocus_LastValidation"
    private let validationIntervalHours: TimeInterval = 24 // Validate once per day

    // License server configuration
    private let licenseServerURL = "https://api.auto-focus.app/v1/licenses"

    enum LicenseStatus: String, CaseIterable {
        case inactive = "inactive"
        case valid = "valid"
        case expired = "expired"
        case invalid = "invalid"
        case networkError = "network_error"

        var displayName: String {
            switch self {
            case .inactive: return "Inactive"
            case .valid: return "Active"
            case .expired: return "Expired"
            case .invalid: return "Invalid"
            case .networkError: return "Network Error"
            }
        }

        var icon: String {
            switch self {
            case .inactive: return "minus.circle"
            case .valid: return "checkmark.seal.fill"
            case .expired: return "clock.badge.exclamationmark"
            case .invalid: return "exclamationmark.triangle.fill"
            case .networkError: return "wifi.exclamationmark"
            }
        }

        var color: Color {
            switch self {
            case .inactive: return .secondary
            case .valid: return .green
            case .expired: return .orange
            case .invalid: return .red
            case .networkError: return .yellow
            }
        }
    }

    enum LicenseError: LocalizedError {
        case invalidFormat
        case serverError(String)
        case networkError
        case alreadyActivated
        case expired
        case invalidVersion

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "License key format is invalid"
            case .serverError(let message):
                return "Server error: \(message)"
            case .networkError:
                return "Network connection error. Please check your internet connection."
            case .alreadyActivated:
                return "This license is already activated on another device"
            case .expired:
                return "This license has expired"
            case .invalidVersion:
                return "This license is not valid for this version of Auto-Focus"
            }
        }
    }

    init() {
        loadAppVersion()
        loadLicense()

        // Check if we're in beta period
        if isInBetaPeriod {
            enableBetaAccess()
        } else if shouldValidateLicense() {
            // Validate existing license on app launch if needed
            validateLicense()
        }
    }

    private var betaExpiryDate: Date {
        // End of August 2025
        let components = DateComponents(year: 2025, month: 8, day: 31, hour: 23, minute: 59, second: 59)
        return Calendar.current.date(from: components) ?? Date.distantFuture
    }

    private var isInBetaPeriod: Bool {
        return Date() < betaExpiryDate
    }

    private func enableBetaAccess() {
        self.licenseStatus = .valid
        self.isLicensed = true
        self.licenseOwner = "Beta User"
        self.licenseEmail = "beta@auto-focus.app"
        self.licenseExpiry = betaExpiryDate
        self.maxAppsAllowed = -1 // Unlimited during beta
    }

    private func loadAppVersion() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func loadLicense() {
        // Load saved license key
        if let savedKey = userDefaults.string(forKey: licenseKeyKey), !savedKey.isEmpty {
            self.licenseKey = savedKey
        }

        // Load saved license data
        if let savedData = userDefaults.data(forKey: licenseDataKey),
           let license = try? JSONDecoder().decode(License.self, from: savedData) {
            self.licenseOwner = license.ownerName
            self.licenseEmail = license.email
            self.licenseExpiry = license.expiryDate
            self.appVersion = license.appVersion ?? appVersion
            self.maxAppsAllowed = license.maxApps ?? 3

            // Check if license is still valid
            if let expiry = license.expiryDate, expiry < Date() {
                self.licenseStatus = .expired
                self.isLicensed = false
            } else if !licenseKey.isEmpty {
                self.licenseStatus = .valid
                self.isLicensed = true
            }
        }

        // Load last validation date
        if let lastValidation = userDefaults.object(forKey: lastValidationKey) as? Date {
            self.lastValidationDate = lastValidation
        }
    }

    private func saveLicenseKey() {
        if licenseKey.isEmpty {
            userDefaults.removeObject(forKey: licenseKeyKey)
        } else {
            userDefaults.set(licenseKey, forKey: licenseKeyKey)
        }
    }

    private func saveLicenseData(_ license: License) {
        if let data = try? JSONEncoder().encode(license) {
            userDefaults.set(data, forKey: licenseDataKey)
        }
    }

    private func shouldValidateLicense() -> Bool {
        guard !licenseKey.isEmpty else { return false }
        guard let lastValidation = lastValidationDate else { return true }

        let hoursSinceLastValidation = Date().timeIntervalSince(lastValidation) / 3600
        return hoursSinceLastValidation >= validationIntervalHours
    }

    func hasValidLicense() -> Bool {
        return isLicensed && (licenseStatus == .valid || isInBetaPeriod)
    }

    func activateLicense() {
        guard !licenseKey.isEmpty else {
            validationError = "Please enter a license key"
            return
        }

        guard !isActivating else { return }

        isActivating = true
        validationError = nil

        Task {
            do {
                let license = try await validateLicenseWithServer(licenseKey)

                await MainActor.run {
                    self.licenseOwner = license.ownerName
                    self.licenseEmail = license.email
                    self.licenseExpiry = license.expiryDate
                    self.appVersion = license.appVersion ?? appVersion
                    self.maxAppsAllowed = license.maxApps ?? 3
                    self.licenseStatus = .valid
                    self.isLicensed = true
                    self.lastValidationDate = Date()
                    self.isActivating = false

                    // Save license data
                    saveLicenseData(license)
                    userDefaults.set(Date(), forKey: lastValidationKey)
                }
            } catch {
                await MainActor.run {
                    self.validationError = error.localizedDescription
                    self.licenseStatus = .invalid
                    self.isLicensed = false
                    self.isActivating = false
                }
            }
        }
    }

    func deactivateLicense() {
        Task {
            do {
                try await deactivateLicenseWithServer(licenseKey)

                await MainActor.run {
                    clearLicenseData()
                }
            } catch {
                // Even if server deactivation fails, clear local data
                await MainActor.run {
                    clearLicenseData()
                }
            }
        }
    }

    private func clearLicenseData() {
        self.licenseKey = ""
        self.licenseOwner = ""
        self.licenseEmail = ""
        self.licenseExpiry = nil
        self.licenseStatus = .inactive
        self.isLicensed = false
        self.validationError = nil
        self.lastValidationDate = nil
        self.maxAppsAllowed = 3

        // Clear saved data
        userDefaults.removeObject(forKey: licenseKeyKey)
        userDefaults.removeObject(forKey: licenseDataKey)
        userDefaults.removeObject(forKey: lastValidationKey)
    }

    private func validateLicense() {
        guard !licenseKey.isEmpty else { return }
        guard !isActivating else { return }

        Task {
            do {
                let license = try await validateLicenseWithServer(licenseKey)

                await MainActor.run {
                    if let expiry = license.expiryDate, expiry < Date() {
                        self.licenseStatus = .expired
                        self.isLicensed = false
                    } else {
                        self.licenseStatus = .valid
                        self.isLicensed = true
                        self.lastValidationDate = Date()
                        userDefaults.set(Date(), forKey: lastValidationKey)
                    }
                }
            } catch {
                await MainActor.run {
                    // Don't immediately invalidate on network errors
                    if case LicenseError.networkError = error {
                        self.licenseStatus = .networkError
                        // Keep existing license status if we just have network issues
                        if isInBetaPeriod || (licenseExpiry ?? Date.distantPast) > Date() {
                            self.isLicensed = true
                        }
                    } else {
                        self.licenseStatus = .invalid
                        self.isLicensed = false
                    }
                }
            }
        }
    }

    // MARK: - Server Communication

    private func validateLicenseWithServer(_ key: String) async throws -> License {
        // Debug license key for development
        #if DEBUG
        if key == "DEBUG-AUTOFOCUS-DEV-2025" {
            return License(
                licenseKey: key,
                ownerName: "Developer",
                email: "dev@auto-focus.app",
                expiryDate: Calendar.current.date(byAdding: .year, value: 5, to: Date()),
                appVersion: appVersion,
                maxApps: -1 // Unlimited
            )
        }
        #endif

        guard let url = URL(string: "\(licenseServerURL)/validate") else {
            throw LicenseError.serverError("Invalid server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "license_key": key,
            "instance_id": generateInstanceIdentifier(),
            "app_version": appVersion,
            "platform": "macos"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LicenseError.networkError
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LicenseError.serverError(errorMessage)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LicenseError.invalidFormat
            }

            return try parseLicenseResponse(json)

        } catch {
            if error is LicenseError {
                throw error
            } else {
                throw LicenseError.networkError
            }
        }
    }

    private func deactivateLicenseWithServer(_ key: String) async throws {
        guard let url = URL(string: "\(licenseServerURL)/deactivate") else {
            throw LicenseError.serverError("Invalid server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "license_key": key,
            "instance_id": generateInstanceIdentifier()
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LicenseError.serverError("Failed to deactivate license")
        }
    }

    private func parseLicenseResponse(_ json: [String: Any]) throws -> License {
        guard let ownerName = json["owner_name"] as? String,
              let email = json["email"] as? String else {
            throw LicenseError.invalidFormat
        }

        var expiryDate: Date?
        if let expiryString = json["expires_at"] as? String {
            let formatter = ISO8601DateFormatter()
            expiryDate = formatter.date(from: expiryString)
        }

        let appVersion = json["app_version"] as? String
        let maxApps = json["max_apps"] as? Int

        return License(
            licenseKey: licenseKey,
            ownerName: ownerName,
            email: email,
            expiryDate: expiryDate,
            appVersion: appVersion,
            maxApps: maxApps
        )
    }

    private func generateInstanceIdentifier() -> String {
        // Create a unique identifier for this installation
        let machineId = SystemInfo.machineModel
        let appId = Bundle.main.bundleIdentifier ?? "auto-focus"
        let combined = "\(machineId)-\(appId)"

        return SHA256.hash(data: combined.data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

struct License: Codable {
    let licenseKey: String
    let ownerName: String
    let email: String
    let expiryDate: Date?
    let appVersion: String?
    let maxApps: Int?

    init(licenseKey: String, ownerName: String, email: String, expiryDate: Date? = nil, appVersion: String? = nil, maxApps: Int? = nil) {
        self.licenseKey = licenseKey
        self.ownerName = ownerName
        self.email = email
        self.expiryDate = expiryDate
        self.appVersion = appVersion
        self.maxApps = maxApps
    }
}

private struct SystemInfo {
    static var machineModel: String {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
