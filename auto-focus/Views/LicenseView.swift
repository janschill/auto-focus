import SwiftUI

struct LicensedView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var showingCopyAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header section based on license status
            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: licenseManager.licenseStatus == .valid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(licenseManager.licenseStatus == .valid ? .green : .orange)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading) {
                            Text(licenseManager.licenseStatus == .valid ? "Beta Acccess Valid" : "License Expired")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            if licenseManager.licenseStatus == .expired {
                                Text("Your license has expired. Please renew to continue using Auto-Focus+ features.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if licenseManager.licenseStatus == .expired {
                        Divider().padding(.vertical, 6)
                        
                        LicenseInputView(licenseManager: licenseManager)
                    }
                    
                }
                .padding()
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        LicenseInfoRow(title: "Licensed to", value: licenseManager.licenseOwner)
                        LicenseInfoRow(title: "Email address", value: licenseManager.licenseEmail)
                        
                        if let expiryDate = licenseManager.licenseExpiry {
                            LicenseInfoRow(
                                title: "Expires",
                                value: expiryDateFormatted(expiryDate)
                            )
                        }
                        
                        if !licenseManager.licenseKey.isEmpty {
                            LicenseInfoRowWithCopy(title: "License key", value: maskedLicenseKey(licenseManager.licenseKey)) {
                                copyLicenseKey()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Divider().padding(.vertical, 8)
                    
//                    HStack {
//                        Spacer()
//                        
//                        Button("Deactivate License") {
//                            licenseManager.deactivateLicense()
//                        }
//                        .foregroundColor(.red)
//                    }
                    
                    LicenseBenefitsView()
                }
                .padding()
            }
            
            Spacer()
        }
        .padding(16)
        .alert("License Key Copied", isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your license key has been copied to the clipboard.")
        }
    }
    
    private func expiryDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func maskedLicenseKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
    
    private func copyLicenseKey() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(licenseManager.licenseKey, forType: .string)
        showingCopyAlert = true
    }
}

struct LicenseInfoRowWithCopy: View {
    let title: String
    let value: String
    let onCopy: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy license key")
        }
    }
}

struct LicenseInputView: View {
    @State private var licenseInput: String = ""
    @ObservedObject var licenseManager: LicenseManager
    
    var body: some View {
        VStack(spacing: 10) {
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
                    Text("Activate")
                }
            }
            .disabled(licenseInput.count < 8 || licenseManager.isActivating)
            .buttonStyle(.borderedProminent)
            
            Link("Don't have a license key? Purchase one.",
                 destination: URL(string: "https://auto-focus.app/license")!)
        }
        .frame(maxWidth: 300)
    }
}

struct LicenseBenefitsView: View {
    var body: some View {
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
                icon: "cloud",
                title: "Data Synchronization",
                description: "Keep your data synchronized across Macs"
            )
            
            PremiumFeatureRow(
                icon: "arrow.clockwise",
                title: "Free Updates",
                description: "Access to all future premium features"
            )
            
            PremiumFeatureRow(
                icon: "cup.and.heat.waves",
                title: "Support Indie Developer",
                description: "Buy us a cup of coffee"
            )
        }
    }
}

struct UnlicensedView: View {
    @ObservedObject var licenseManager: LicenseManager
    
    var body: some View {
        GroupBox() {
            VStack() {
                Text("Join Auto-Focus+").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Unlimited focus apps, advanced insights and more.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                
                LicenseInputView(licenseManager: licenseManager)
                
                Divider().padding(16)
                
                LicenseBenefitsView()
                
            }
            .padding(.horizontal, 40)
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
    }
}

struct LicenseView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    
    var body: some View {
        VStack(spacing: 10) {
            if licenseManager.isLicensed {
                LicensedView(licenseManager: licenseManager)
            } else {
                UnlicensedView(licenseManager: licenseManager)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct LicenseInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
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

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}
