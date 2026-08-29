import Foundation

/// Sends a daily anonymous check-in so we can count active installations
/// and see version distribution. No personal data is collected — just a
/// locally-generated random UUID, app version, macOS version, and license tier.
///
/// Fire-and-forget: any failure is silently ignored and never blocks the app.
class InstallationTracker {
    static let shared = InstallationTracker()

    static let analyticsEnabledKey = "AutoFocus_AnalyticsEnabled"

    private let logger = AppLogger.network
    private let userDefaults = UserDefaults.standard
    private let installationIdKey = "AutoFocus_InstallationID"
    private let lastCheckInKey = "AutoFocus_LastInstallationCheckIn"

    private let endpoint = "https://auto-focus.app/api/v1/installations/check-in"
    private let checkInIntervalHours: TimeInterval = 24

    private init() {
        if userDefaults.object(forKey: Self.analyticsEnabledKey) == nil {
            userDefaults.set(true, forKey: Self.analyticsEnabledKey)
        }
    }

    func checkInIfNeeded(isLicensed: Bool, isBeta: Bool) {
        guard isEnabled else { return }
        guard shouldCheckIn else { return }

        let payload: [String: Any] = [
            "installation_id": installationId,
            "app_version": appVersion,
            "os_version": osVersion,
            "tier": tier(isLicensed: isLicensed, isBeta: isBeta)
        ]

        Task.detached { [weak self] in
            await self?.send(payload)
        }
    }

    private func send(_ payload: [String: Any]) async {
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                userDefaults.set(Date(), forKey: lastCheckInKey)
                logger.debug("Installation check-in sent", metadata: [
                    "version": payload["app_version"] as? String ?? "?",
                    "tier": payload["tier"] as? String ?? "?"
                ])
            } else if let http = response as? HTTPURLResponse {
                logger.debug("Installation check-in non-success (ignored)", metadata: [
                    "status": String(http.statusCode)
                ])
            }
        } catch {
            logger.debug("Installation check-in failed (ignored)", metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private var isEnabled: Bool {
        userDefaults.bool(forKey: Self.analyticsEnabledKey)
    }

    private var shouldCheckIn: Bool {
        guard let last = userDefaults.object(forKey: lastCheckInKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= checkInIntervalHours * 3600
    }

    private var installationId: String {
        if let existing = userDefaults.string(forKey: installationIdKey) {
            return existing
        }
        let new = UUID().uuidString
        userDefaults.set(new, forKey: installationIdKey)
        return new
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    private func tier(isLicensed: Bool, isBeta: Bool) -> String {
        if isBeta { return "beta" }
        return isLicensed ? "licensed" : "free"
    }
}
