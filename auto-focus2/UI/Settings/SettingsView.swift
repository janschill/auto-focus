import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title2)

            if let err = viewModel.lastError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            GroupBox("Timers") {
                HStack {
                    Stepper("Activation (minutes): \(viewModel.activationMinutes)", value: $viewModel.activationMinutes, in: 1...180)
                    Spacer()
                    Button("Save") { viewModel.saveTimers() }
                }
                Stepper("Buffer (seconds): \(viewModel.bufferSeconds)", value: $viewModel.bufferSeconds, in: 0...600)
            }

            GroupBox("Focus entities") {
                List {
                    ForEach(viewModel.focusEntities) { entity in
                        HStack {
                            Text(entity.displayName)
                            Spacer()
                            Text(entity.type.rawValue)
                                .foregroundStyle(.secondary)
                            Button("Delete") { viewModel.deleteEntity(entity) }
                        }
                    }
                }
                .frame(minHeight: 140)

                HStack {
                    TextField("Domain name", text: $viewModel.newDomainName)
                    TextField("example.com", text: $viewModel.newDomainValue)
                    Button("Add domain") { viewModel.addDomain() }
                }

                HStack {
                    TextField("App name", text: $viewModel.newAppName)
                    TextField("com.apple.dt.Xcode", text: $viewModel.newAppBundleId)
                    Button("Add app") { viewModel.addApp() }
                }
                .foregroundStyle(.secondary)
            }

            GroupBox {
                LaunchOnLoginRow(isEnabled: $viewModel.launchOnLoginEnabled) { enabled in
                    viewModel.toggleLaunchOnLogin(enabled)
                }
            }

            GroupBox {
                LicenseView(licenseService: viewModel.licenseService, licenseKey: $viewModel.licenseKey)
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
        .onDisappear {
            viewModel.saveLicenseKey()
        }
    }
}


