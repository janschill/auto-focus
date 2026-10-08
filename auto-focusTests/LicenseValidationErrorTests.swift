// LicenseValidationErrorTests.swift
// Verifies transient validation failures map to network errors (grace period) while
// genuine rejections still de-license.

import CommonCrypto
@testable import auto_focus
import XCTest

#if DEBUG

final class LicenseValidationErrorTests: XCTestCase {
    // Matches LicenseManager's DEBUG HMAC secret
    private let debugSecret = "auto-focus-hmac-secret-2025"

    private func isNetworkError(_ error: Error) -> Bool {
        if case LicenseManager.LicenseError.networkError = error { return true }
        return false
    }

    private func isServerError(_ error: Error) -> Bool {
        if case LicenseManager.LicenseError.serverError = error { return true }
        return false
    }

    private func signedResponse(valid: Bool, message: String, timestamp: Int64) -> [String: Any] {
        let payload = Data("\(valid)|\(message)|\(timestamp)".utf8)
        let secret = Data(debugSecret.utf8)
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        secret.withUnsafeBytes { secretBytes in
            payload.withUnsafeBytes { payloadBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), secretBytes.baseAddress, secret.count,
                       payloadBytes.baseAddress, payload.count, &mac)
            }
        }
        return [
            "valid": valid,
            "message": message,
            "timestamp": timestamp,
            "signature": Data(mac).base64EncodedString()
        ]
    }

    func testStatusCodeMapping() {
        let cases: [(statusCode: Int, expectNetworkError: Bool)] = [
            (500, true), (502, true), (503, true), (504, true), (408, true), (429, true),
            (400, false), (401, false), (403, false), (404, false), (422, false)
        ]

        for testCase in cases {
            let error = LicenseManager.validationError(forStatusCode: testCase.statusCode, message: "msg")
            if testCase.expectNetworkError {
                XCTAssertTrue(isNetworkError(error), "HTTP \(testCase.statusCode) should map to networkError")
            } else {
                XCTAssertTrue(isServerError(error), "HTTP \(testCase.statusCode) should map to serverError")
            }
        }
    }

    func testTimestampSkewIsTreatedAsNetworkError() {
        let manager = LicenseManager()
        let now = Date()
        let staleTimestamp = Int64(now.timeIntervalSince1970) - 3600
        let json = signedResponse(valid: true, message: "ok", timestamp: staleTimestamp)

        XCTAssertThrowsError(try manager.parseLicenseResponse(json, licenseKey: "KEY", now: now)) { error in
            XCTAssertTrue(isNetworkError(error), "Timestamp skew should map to networkError, got \(error)")
        }
    }

    func testInvalidLicenseAnswerStillRejects() {
        let manager = LicenseManager()
        let now = Date()
        let json = signedResponse(valid: false, message: "License not found", timestamp: Int64(now.timeIntervalSince1970))

        XCTAssertThrowsError(try manager.parseLicenseResponse(json, licenseKey: "KEY", now: now)) { error in
            XCTAssertTrue(isServerError(error), "valid=false should map to serverError, got \(error)")
        }
    }

    func testValidFreshResponseParses() throws {
        let manager = LicenseManager()
        let now = Date()
        let json = signedResponse(valid: true, message: "ok", timestamp: Int64(now.timeIntervalSince1970))

        let license = try manager.parseLicenseResponse(json, licenseKey: "KEY", now: now)
        XCTAssertEqual(license.licenseKey, "KEY")
    }
}

#endif
