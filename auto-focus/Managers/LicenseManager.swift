import CryptoKit
import Foundation

class LicenseManager: ObservableObject {
    @Published var isLicensed: Bool = true
    @Published var licenseKey: String = "" {
        didSet {
            #if !DEBUG
            validateLicense()
            #endif
        }
    }
    @Published var licenseStatus: LicenseStatus = .inactive
    @Published var licenseOwner: String = ""
    @Published var licenseEmail: String = ""
    @Published var licenseExpiry: Date?
    @Published var isActivating: Bool = false
    @Published var validationError: String?

    enum LicenseStatus: String {
        case inactive
        case valid
        case expired
        case invalid
    }

    init() {
        #if DEBUG
        self.licenseStatus = .valid
        self.isLicensed = true
        self.licenseOwner = "Beta User"
        self.licenseEmail = "beta@auto-focus.app"
        self.licenseExpiry = betaExpiryDate
        return
        #else
        if isInBetaPeriod {
            self.licenseStatus = .valid
            self.isLicensed = true
            self.licenseOwner = "Beta User"
            self.licenseEmail = ""
            self.licenseExpiry = betaExpiryDate
            return
        }
        loadLicense()
        #endif
    }

    private var betaExpiryDate: Date {
        // July 1, 2025
        let components = DateComponents(year: 2025, month: 7, day: 1)
        return Calendar.current.date(from: components) ?? Date.distantFuture
    }

    private var isInBetaPeriod: Bool {
        return Date() < betaExpiryDate
    }

    private func loadLicense() {
    }

    func hasValidLicense() -> Bool {
        return true
//        return isLicensed && licenseStatus == .valid
    }

    private func parseExpiryDate(from licenseData: [String: Any]) -> Date? {
        // Handle expiry date based on LemonSqueezy response format
        // This is just a placeholder - adjust based on actual API response
        if let expiresAt = licenseData["expires_at"] as? String {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: expiresAt)
        }
        return nil
    }

    func activateLicense() {}

    func deactivateLicense() {}

    private func validateLicense() {}

    private func generateInstanceIdentifier() {}
}

struct License: Codable {
    let licenseKey: String
    let ownerName: String
    let email: String
    let expiryDate: Date?
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
