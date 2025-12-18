import SwiftUI

struct AutoFocusPlusView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "AutoFocus+", subtitle: "Unlock premium limits and export.")

            GroupBox {
                LicenseView(licenseService: viewModel.licenseService, licenseKey: $viewModel.licenseKey)
            }

            Spacer()
        }
        .padding(16)
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}


