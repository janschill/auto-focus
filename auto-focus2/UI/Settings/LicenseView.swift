import SwiftUI

struct LicenseView: View {
    @ObservedObject var licenseService: LicenseService
    @Binding var licenseKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("License")
                .font(.headline)

            TextField("License key", text: $licenseKey)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Save") {
                    licenseService.setLicenseKey(licenseKey)
                }

                Button(licenseService.isValidating ? "Validating…" : "Validate") {
                    Task { await licenseService.validate() }
                }
                .disabled(licenseService.isValidating)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Status: \(licenseService.status.state.rawValue)")
                if let message = licenseService.status.message, !message.isEmpty {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                if let date = licenseService.status.lastValidatedAt {
                    Text("Last validated: \(date.formatted())")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Entitlements")
                    .font(.subheadline)
                Text("Max entities: \(licenseService.status.entitlements.maxFocusEntities < 0 ? "unlimited" : String(licenseService.status.entitlements.maxFocusEntities))")
                Text("Insights depth: \(licenseService.status.entitlements.insightsDepthDays < 0 ? "unlimited" : String(licenseService.status.entitlements.insightsDepthDays) + " days")")
                Text("Export: \(licenseService.status.entitlements.exportEnabled ? "enabled" : "disabled")")
            }
            .foregroundStyle(.secondary)
        }
    }
}


