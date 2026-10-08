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

                    // Show license input for expired or invalid licenses
                    if licenseManager.licenseStatus == .expired || licenseManager.licenseStatus == .invalid {
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

                    if licenseManager.licenseStatus == .valid {
                        HStack {
                            Spacer()

                            Button("Deactivate License") {
                                showingDeactivateAlert = true
                            }
                            .foregroundColor(.red)
                            .buttonStyle(.bordered)
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
        DateFormatter.mediumDate.string(from: date)
    }

    private func maskedLicenseKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    private var statusTitle: String {
        switch licenseManager.licenseStatus {
        case .valid:
            return "Auto-Focus+ Active"
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
            return "Your Auto-Focus+ license is active. All premium features are unlocked."
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
        RelativeDateTimeFormatter.full.localizedString(for: date, relativeTo: Date())
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

    private var canActivate: Bool {
        licenseInput.count >= 8 && !licenseManager.isActivating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("License key", text: $licenseInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(activate)

                Button(action: activate) {
                    if licenseManager.isActivating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Activate")
                    }
                }
                .disabled(!canActivate)
            }

            if let error = licenseManager.validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func activate() {
        guard canActivate else { return }
        licenseManager.licenseKey = licenseInput
        licenseManager.activateLicense()
    }
}

struct LicenseBenefitsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PremiumFeatureRow(
                icon: "square.stack.3d.up.fill",
                tint: .blue,
                title: "Unlimited Focus Apps",
                description: "Add as many focus-triggering apps as you need."
            )
            PremiumFeatureRow(
                icon: "globe",
                tint: .teal,
                title: "Unlimited Focus Websites",
                description: "Track any website with browser integration."
            )
            PremiumFeatureRow(
                icon: "chart.bar.xaxis",
                tint: .orange,
                title: "Advanced Insights",
                description: "See focus quality, context switches, and your most productive times."
            )
            PremiumFeatureRow(
                icon: "arrow.triangle.2.circlepath",
                tint: .green,
                title: "Free Updates",
                description: "Get every future premium feature included."
            )
            PremiumFeatureRow(
                icon: "heart.fill",
                tint: .pink,
                title: "Support an Indie Developer",
                description: "Help keep Auto-Focus independent and ad-free."
            )
        }
    }
}

struct UnlicensedView: View {
    @ObservedObject var licenseManager: LicenseManager

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor.gradient)
                Text("Auto-Focus+")
                    .font(.largeTitle.weight(.bold))
                Text("Unlock everything Auto-Focus can do.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            LicenseBenefitsView()
                .frame(maxWidth: 380, alignment: .leading)

            Link(destination: URL(string: "https://auto-focus.app/#pricing")!) {
                Label("Get Auto-Focus+", systemImage: "arrow.up.forward")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Already purchased?")
                        .font(.headline)
                    Text("Enter the license key from your purchase email.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LicenseInputView(licenseManager: licenseManager)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
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
    let tint: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 900)
}
