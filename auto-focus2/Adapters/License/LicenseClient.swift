import CryptoKit
import Foundation

enum LicenseValidationOutcome: Equatable, Sendable {
    case licensed(message: String)
    case invalid(message: String)
    case offline
    case serviceError(message: String)
}

protocol LicenseClienting: Sendable {
    func validate(licenseKey: String, appVersion: String) async -> LicenseValidationOutcome
}

protocol URLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessioning {}

protocol HMACSecretProviding: Sendable {
    func hmacSecret() -> String
}

struct DefaultHMACSecretProvider: HMACSecretProviding {
    func hmacSecret() -> String {
        // Prefer Info.plist value if present; fallback to development secret.
        (Bundle.main.object(forInfoDictionaryKey: "HMAC_SECRET") as? String) ?? "auto-focus-hmac-secret-2025"
    }
}

final class LicenseClient: LicenseClienting {
    private let baseURL: URL
    private let session: URLSessioning
    private let clock: Clocking
    private let secretProvider: HMACSecretProviding
    private let maxTimestampSkewSeconds: Int64 = 300

    init(
        baseURL: URL = URL(string: "https://auto-focus.app/api/v1/licenses")!,
        session: URLSessioning = URLSession.shared,
        clock: Clocking,
        secretProvider: HMACSecretProviding = DefaultHMACSecretProvider()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.clock = clock
        self.secretProvider = secretProvider
    }

    func validate(licenseKey: String, appVersion: String) async -> LicenseValidationOutcome {
        let url = baseURL.appendingPathComponent("validate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "license_key": licenseKey,
            "app_version": appVersion
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .offline
            }

            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? "License validation failed"
                if (500...599).contains(http.statusCode) {
                    return .serviceError(message: msg)
                }
                return .invalid(message: msg)
            }

            let decoded = try JSONDecoder().decode(LicenseValidateResponse.self, from: data)
            guard verifySignature(response: decoded) else {
                return .serviceError(message: "Invalid response signature")
            }

            guard verifyTimestampFreshness(timestamp: decoded.timestamp) else {
                return .serviceError(message: "Response timestamp invalid")
            }

            if decoded.valid {
                return .licensed(message: decoded.message)
            } else {
                return .invalid(message: decoded.message)
            }
        } catch {
            return .offline
        }
    }

    private func verifyTimestampFreshness(timestamp: Int64) -> Bool {
        let now = Int64(clock.now.timeIntervalSince1970)
        let diff = abs(now - timestamp)
        return diff <= maxTimestampSkewSeconds
    }

    private func verifySignature(response: LicenseValidateResponse) -> Bool {
        let payload = "\(response.valid)|\(response.message)|\(response.timestamp)"
        let secret = secretProvider.hmacSecret()

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        let computed = Data(mac).base64EncodedString()

        // Constant-time-ish comparison.
        guard computed.count == response.signature.count else { return false }
        return zip(computed.utf8, response.signature.utf8).reduce(true) { $0 && ($1.0 == $1.1) }
    }
}

struct LicenseValidateResponse: Codable {
    let valid: Bool
    let message: String
    let timestamp: Int64
    let signature: String
}


