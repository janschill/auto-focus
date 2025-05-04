import SwiftUI

struct LicensedView : View {
    @ObservedObject var licenseManager: LicenseManager
    
    var body: some View {
        Form {
            if licenseManager.isLicensed {
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
                GroupBox() {
                    VStack(spacing: 8) {
                        Text("Auto Focus+")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Debugger Boy")
                            .font(.title2)
                        Text("debugger@janschill.de")
                            .font(.title2)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                }
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

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}
