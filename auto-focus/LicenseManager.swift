//
//  LicenseManager.swift
//  auto-focus
//
//  Created by Jan Schill on 16/04/2025.
//

import Foundation
import CryptoKit

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
    
    private let lemonSqueezyBaseURL = "https://api.lemonsqueezy.com/v1/licenses/validate"
    private let productId = "YOUR_PRODUCT_ID" // Replace with your LemonSqueezy product ID
    
    enum LicenseStatus: String {
        case inactive
        case valid
        case expired
        case invalid
    }
    
    init() {
        loadLicense()
    }
    

    
    private func loadLicense() {
        #if DEBUG
        self.licenseStatus = .expired
//        self.licenseStatus = .valid
//        self.isLicensed = false
        self.isLicensed = true
        self.licenseOwner = "Debugger Boy"
        self.licenseEmail = "debugger-boy@janschill.de"
        return
        #endif
        
        if let licenseData = UserDefaults.standard.data(forKey: "licenseData"),
           let license = try? JSONDecoder().decode(License.self, from: licenseData) {
            // License exists, validate it
            self.licenseKey = license.licenseKey
            self.licenseOwner = license.ownerName
            self.licenseEmail = license.email
            self.licenseExpiry = license.expiryDate
            
            // Check if license is expired
            if let expiryDate = license.expiryDate, expiryDate < Date() {
                self.licenseStatus = .expired
                self.isLicensed = false
            } else {
                self.licenseStatus = .valid
                self.isLicensed = true
            }
        } else {
            // No license found
            self.licenseStatus = .inactive
            self.isLicensed = false
        }
    }
    
    func activateLicense() {
        isActivating = true
        validationError = nil
        
        // Create the validation URL
        guard let url = URL(string: lemonSqueezyBaseURL) else {
            validationError = "Invalid API URL"
            isActivating = false
            return
        }
        
        // Prepare the payload
        let payload = [
            "license_key": licenseKey,
            "instance_name": generateInstanceIdentifier()
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            validationError = "Failed to create request: \(error.localizedDescription)"
            isActivating = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isActivating = false
                
                if let error = error {
                    self.validationError = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.validationError = "No data received"
                    return
                }
                
                // Try to parse the response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let licenseData = json["license"] as? [String: Any] {
                        
                        let isValid = licenseData["valid"] as? Bool ?? false
                        
                        if isValid {
                            // License is valid, store information
                            let license = License(
                                licenseKey: self.licenseKey,
                                ownerName: licenseData["name"] as? String ?? "Unknown",
                                email: licenseData["email"] as? String ?? "",
                                expiryDate: self.parseExpiryDate(from: licenseData)
                            )
                            
                            // Save to UserDefaults
                            if let encoded = try? JSONEncoder().encode(license) {
                                UserDefaults.standard.set(encoded, forKey: "licenseData")
                            }
                            
                            self.licenseOwner = license.ownerName
                            self.licenseEmail = license.email
                            self.licenseExpiry = license.expiryDate
                            self.licenseStatus = .valid
                            self.isLicensed = true
                        } else {
                            // License is invalid
                            self.licenseStatus = .invalid
                            self.isLicensed = false
                            self.validationError = licenseData["error"] as? String ?? "Invalid license key"
                        }
                    } else {
                        self.validationError = "Unexpected response format"
                    }
                } catch {
                    self.validationError = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
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
    
    private func validateLicense() {
        // Simple format validation before sending to API
        if licenseKey.count < 8 {
            licenseStatus = .inactive
            validationError = nil
            return
        }
        
        // Reset validation error
        validationError = nil
    }
    
    func deactivateLicense() {
        UserDefaults.standard.removeObject(forKey: "licenseData")
        licenseKey = ""
        licenseOwner = ""
        licenseEmail = ""
        licenseExpiry = nil
        licenseStatus = .inactive
        isLicensed = false
    }
    
    private func generateInstanceIdentifier() -> String {
        // Create a unique identifier for this installation
        // This helps prevent license sharing across multiple devices
        let systemInfo = ProcessInfo.processInfo.hostName + SystemInfo.machineModel
        
        if let data = systemInfo.data(using: .utf8) {
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
        
        return UUID().uuidString
    }
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
