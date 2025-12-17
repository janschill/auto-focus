import Foundation

final class LicenseService: ObservableObject {
    @Published private(set) var status: LicenseStatusSnapshot
    @Published var isValidating: Bool = false

    private let client: LicenseClienting
    private let clock: Clocking
    private let keychain: KeychainStore
    private let userDefaults: UserDefaults
    private let appVersionProvider: () -> String

    private let licenseKeyAccount = "license_key"
    private let cachedStatusKey = "AutoFocus2_LicenseStatusSnapshot"

    init(
        client: LicenseClienting,
        clock: Clocking,
        keychain: KeychainStore,
        userDefaults: UserDefaults = .standard,
        appVersionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        }
    ) {
        self.client = client
        self.clock = clock
        self.keychain = keychain
        self.userDefaults = userDefaults
        self.appVersionProvider = appVersionProvider

        if let cached = Self.loadCachedStatus(from: userDefaults, key: cachedStatusKey) {
            self.status = cached
        } else {
            self.status = LicenseStatusSnapshot(
                state: .unlicensed,
                lastValidatedAt: nil,
                message: nil,
                entitlements: PremiumGating.entitlements(for: .unlicensed)
            )
        }
    }

    func currentLicenseKey() -> String {
        (try? keychain.readString(account: licenseKeyAccount)) ?? ""
    }

    func setLicenseKey(_ key: String) {
        do {
            if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try keychain.delete(account: licenseKeyAccount)
            } else {
                try keychain.writeString(key, account: licenseKeyAccount)
            }
        } catch {
            AppLog.license.error("Failed to store license key")
        }
    }

    @MainActor
    func validate() async {
        let key = currentLicenseKey().trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            status = LicenseStatusSnapshot(
                state: .unlicensed,
                lastValidatedAt: nil,
                message: nil,
                entitlements: PremiumGating.entitlements(for: .unlicensed)
            )
            Self.saveCachedStatus(status, to: userDefaults, key: cachedStatusKey)
            return
        }

        isValidating = true
        defer { isValidating = false }

        let outcome = await client.validate(licenseKey: key, appVersion: appVersionProvider())
        switch outcome {
        case .licensed(let message):
            status = LicenseStatusSnapshot(
                state: .licensed,
                lastValidatedAt: clock.now,
                message: message,
                entitlements: PremiumGating.entitlements(for: .licensed)
            )
        case .invalid(let message):
            status = LicenseStatusSnapshot(
                state: .unlicensed,
                lastValidatedAt: clock.now,
                message: message,
                entitlements: PremiumGating.entitlements(for: .unlicensed)
            )
        case .offline:
            status = LicenseStatusSnapshot(
                state: .offline,
                lastValidatedAt: clock.now,
                message: "Offline",
                entitlements: PremiumGating.entitlements(for: .unlicensed)
            )
        case .serviceError(let message):
            status = LicenseStatusSnapshot(
                state: .validationFailed,
                lastValidatedAt: clock.now,
                message: message,
                entitlements: PremiumGating.entitlements(for: .unlicensed)
            )
        }

        Self.saveCachedStatus(status, to: userDefaults, key: cachedStatusKey)
    }

    private static func loadCachedStatus(from userDefaults: UserDefaults, key: String) -> LicenseStatusSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LicenseStatusSnapshot.self, from: data)
    }

    private static func saveCachedStatus(_ snapshot: LicenseStatusSnapshot, to userDefaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: key)
        }
    }
}


