import CryptoKit
import XCTest
@testable import AutoFocus2

final class LicenseClientTests: XCTestCase {
    func testValidResponseWithGoodSignatureIsLicensed() async {
        let secret = "test-secret"
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let response = makeResponse(valid: true, message: "ok", timestamp: Int64(clock.now.timeIntervalSince1970), secret: secret)

        let session = SessionStub(
            statusCode: 200,
            body: try! JSONEncoder().encode(response)
        )

        let client = LicenseClient(
            baseURL: URL(string: "https://example.com/api/v1/licenses")!,
            session: session,
            clock: clock,
            secretProvider: StaticSecretProvider(secret: secret)
        )

        let outcome = await client.validate(licenseKey: "XXXX", appVersion: "1.0.0")
        XCTAssertEqual(outcome, .licensed(message: "ok"))
    }

    func testInvalidSignatureYieldsServiceError() async {
        let secret = "test-secret"
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        var response = makeResponse(valid: true, message: "ok", timestamp: Int64(clock.now.timeIntervalSince1970), secret: secret)
        response = LicenseValidateResponse(valid: response.valid, message: response.message, timestamp: response.timestamp, signature: "BAD")

        let session = SessionStub(statusCode: 200, body: try! JSONEncoder().encode(response))
        let client = LicenseClient(
            baseURL: URL(string: "https://example.com/api/v1/licenses")!,
            session: session,
            clock: clock,
            secretProvider: StaticSecretProvider(secret: secret)
        )

        let outcome = await client.validate(licenseKey: "XXXX", appVersion: "1.0.0")
        XCTAssertEqual(outcome, .serviceError(message: "Invalid response signature"))
    }

    func testStaleTimestampYieldsServiceError() async {
        let secret = "test-secret"
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let stale = Int64(clock.now.timeIntervalSince1970) - 10_000
        let response = makeResponse(valid: true, message: "ok", timestamp: stale, secret: secret)

        let session = SessionStub(statusCode: 200, body: try! JSONEncoder().encode(response))
        let client = LicenseClient(
            baseURL: URL(string: "https://example.com/api/v1/licenses")!,
            session: session,
            clock: clock,
            secretProvider: StaticSecretProvider(secret: secret)
        )

        let outcome = await client.validate(licenseKey: "XXXX", appVersion: "1.0.0")
        XCTAssertEqual(outcome, .serviceError(message: "Response timestamp invalid"))
    }
}

// MARK: - Test helpers

private struct StaticSecretProvider: HMACSecretProviding {
    let secret: String
    func hmacSecret() -> String { secret }
}

private func makeResponse(valid: Bool, message: String, timestamp: Int64, secret: String) -> LicenseValidateResponse {
    let payload = "\(valid)|\(message)|\(timestamp)"
    let key = SymmetricKey(data: Data(secret.utf8))
    let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
    let sig = Data(mac).base64EncodedString()
    return LicenseValidateResponse(valid: valid, message: message, timestamp: timestamp, signature: sig)
}

private struct SessionStub: URLSessioning {
    private let statusCode: Int
    private let body: Data

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (body, response)
    }
}


