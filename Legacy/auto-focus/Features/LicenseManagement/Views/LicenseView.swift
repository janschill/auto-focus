import SwiftUI

struct LicensedView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var showingCopyAlert = false
    @State private var showingDeactivateAlert = false

    var body: some View {
        VStack(spacing: 16) {
            // Header section based on license status
            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: licenseManager.licenseStatus.icon)
                            .foregroundColor(licenseManager.licenseStatus.color)
                            .font(.largeTitle)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle)
                                .font(.headline)
                                .fontWeight(.bold)

                            Text(statusDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // Show license input for expired, invalid, or beta users
                    if licenseManager.licenseStatus == .expired || licenseManager.licenseStatus == .invalid || isBetaLicense {
                        Divider().padding(.vertical, 6)

                        if isBetaLicense {
                            BetaUpgradeView(licenseManager: licenseManager)
                        } else {
                            LicenseInputView(licenseManager: licenseManager)
                        }
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

                    // Action buttons based on license type
                    if licenseManager.licenseStatus == .valid && !isBetaLicense {
                        HStack {
                            Spacer()

                            Button("Deactivate License") {
                                showingDeactivateAlert = true
                            }
                            .foregroundColor(.red)
                            .buttonStyle(.bordered)
                        }
                        .padding(.bottom, 8)
                    } else if isBetaLicense {
                        VStack(spacing: 12) {
                            Text("Upgrade to Full License")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("While you enjoy beta access, you can upgrade to a full Auto-Focus+ license for continued access after August 31, 2025.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 8)
                    }

                    LicenseBenefitsView()
                }
                .padding()
            }

            Spacer()
        }
        .padding(16)
        .alert("License Key Copied", isPresented: $showingCopyAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Your license key has been copied to the clipboard.")
        })
        .alert("Deactivate License", isPresented: $showingDeactivateAlert, actions: {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                licenseManager.deactivateLicense()
            }
        }, message: {
            Text("Are you sure you want to deactivate this license? You can reactivate it later on this or another device.")
        })
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

    private var isBetaLicense: Bool {
        return licenseManager.licenseOwner == "Beta User"
    }

    private var statusTitle: String {
        switch licenseManager.licenseStatus {
        case .valid:
            return isBetaLicense ? "Beta Access Active" : "Auto-Focus+ Active"
        case .expired:
            return "License Expired"
        case .invalid:
            return "Invalid License"
        case .inactive:
            return "No License"
        case .networkError:
            return "Connection Error"
        }
    }

    private var statusDescription: String {
        switch licenseManager.licenseStatus {
        case .valid:
            if isBetaLicense {
                return "You have beta access until August 31, 2025. All premium features are unlocked."
            } else {
                return "Your Auto-Focus+ license is active. All premium features are unlocked."
            }
        case .expired:
            return "Your license has expired. Please renew to continue using Auto-Focus+ features."
        case .invalid:
            return "The entered license key is invalid. Please check and try again."
        case .inactive:
            return "No active license found."
        case .networkError:
            return "Unable to verify license due to network issues. Premium features remain available."
        }
    }

    private func lastValidationFormatted(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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

            Link("Don't have a license key? Get Auto-Focus+",
                 destination: URL(string: "https://auto-focus.app")!)
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
                icon: "globe",
                title: "Unlimited Focus Websites",
                description: "Track unlimited websites with browser integration"
            )

            PremiumFeatureRow(
                icon: "chart.bar.fill",
                title: "Advanced Insights",
                description: "Get detailed statistics about your focus habits"
            )

            PremiumFeatureRow(
                icon: "externaldrive",
                title: "Data Export & Import",
                description: "Backup and transfer your focus data"
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
        GroupBox {
            VStack {
                Text("Join Auto-Focus+").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Unlimited focus apps, unlimited focus websites, advanced insights and more.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                LicenseInputView(licenseManager: licenseManager)

                Divider().padding(16)

                Link(destination: URL(string: "https://auto-focus.app")!) {
                    HStack {
                        Text("Visit auto-focus.app")
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

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
        ScrollView {
            VStack(spacing: 10) {
                if licenseManager.isLicensed {
                    LicensedView(licenseManager: licenseManager)
                } else {
                    UnlicensedView(licenseManager: licenseManager)
                }
            }
            .padding()
        }
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

struct BetaUpgradeView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var showingLicenseInput = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎉 You're in Beta!")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Enjoying Auto-Focus+? Get a license for continued access after August 31, 2025.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://auto-focus.app")!) {
                    HStack {
                        Text("Get License")
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button("Enter License Key") {
                    showingLicenseInput.toggle()
                }
                .buttonStyle(.bordered)
            }

            if showingLicenseInput {
                Divider()
                    .padding(.vertical, 4)

                LicenseInputView(licenseManager: licenseManager)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}
