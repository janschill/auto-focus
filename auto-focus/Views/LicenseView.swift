//
//  LicenseView.swift
//  auto-focus
//

import SwiftUI

struct LicenseView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var licenseInput: String = ""
    
    var body: some View {
        Form {
            if licenseManager.isLicensed {
                // License is active - show details
                Section(header: Text("License Status").font(.headline)) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Premium License Active")
                            .font(.headline)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        LicenseInfoRow(title: "Licensed to", value: licenseManager.licenseOwner)
                        LicenseInfoRow(title: "Email", value: licenseManager.licenseEmail)
                        
                        if let expiryDate = licenseManager.licenseExpiry {
                            LicenseInfoRow(
                                title: "Expires",
                                value: expiryDateFormatted(expiryDate)
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button("Deactivate License") {
                        licenseManager.deactivateLicense()
                    }
                    .foregroundColor(.red)
                    .padding(.top, 8)
                }
            } else {
                // License activation form
                Section(header: Text("Activate Premium").font(.headline)) {
                    Text("Unlock premium features including unlimited focus apps and detailed session insights.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 12) {
                        TextField("Enter License Key", text: $licenseInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if let error = licenseManager.validationError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, -4)
                        }
                        
                        Button(action: {
                            licenseManager.licenseKey = licenseInput
                            licenseManager.activateLicense()
                        }) {
                            if licenseManager.isActivating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .frame(height: 20)
                            } else {
                                Text("Activate License")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(licenseInput.count < 8 || licenseManager.isActivating)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button("Purchase a License") {
                        if let url = URL(string: "https://yourcompany.lemonsqueezy.com/checkout/buy/your-product-id") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        PremiumFeatureRow(
                            icon: "list.bullet",
                            title: "Unlimited Focus Apps",
                            description: "Add as many focus-triggering apps as you need"
                        )
                        
                        PremiumFeatureRow(
                            icon: "chart.bar.fill",
                            title: "Advanced Insights",
                            description: "Get detailed statistics about your focus habits"
                        )
                        
                        PremiumFeatureRow(
                            icon: "arrow.clockwise",
                            title: "Free Updates",
                            description: "Access to all future premium features"
                        )
                    }
                }
            }
        }
        .padding(16)
    }
    
    private func expiryDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct LicenseInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
