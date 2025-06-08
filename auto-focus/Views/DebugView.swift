import SwiftUI

func setLicense() {
    LicenseManager().licenseStatus = .valid
    LicenseManager().licenseStatus = .valid
    LicenseManager().isLicensed = true
    LicenseManager().licenseOwner = "Debugger Boy"
    LicenseManager().licenseEmail = "debugger-boy@janschill.de"
    LicenseManager().licenseKey = "aasdasdd23443tfgsdfgq234"
    LicenseManager().licenseExpiry = Date() + 365 * 24 * 60 * 60

}

struct DebugMenuView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @StateObject private var viewModel: DebugViewModel

    init() {
        _viewModel = StateObject(wrappedValue: DebugViewModel(focusManager: FocusManager.shared))
    }

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.orange)
                Text("Debug Options")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            GroupBox("License") {
                Button("Add license") {
                    setLicense()
                }
                .buttonStyle(.borderedProminent)
            }
            GroupBox("Onboarding") {
                Button("Reset Onboarding") {
                    focusManager.resetOnboarding()
                }
                .buttonStyle(.bordered)
            }
            GroupBox("Sample Data Generator") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Days:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(viewModel.daysToGenerate) },
                            set: { viewModel.daysToGenerate = Int($0) }
                        ), in: 7...90, step: 1)
                        Text("\(viewModel.daysToGenerate)")
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Sessions/day:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(viewModel.sessionsPerDay) },
                            set: { viewModel.sessionsPerDay = Int($0) }
                        ), in: 1...15, step: 1)
                        Text("\(viewModel.sessionsPerDay)")
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Avg. mins:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(viewModel.avgSessionLength) },
                            set: { viewModel.avgSessionLength = Int($0) }
                        ), in: 5...60, step: 1)
                        Text("\(viewModel.avgSessionLength)")
                            .frame(width: 30)
                    }
                    HStack(spacing: 12) {
                        Button("Generate Data") {
                            viewModel.alertType = .addData
                            viewModel.showingConfirmationAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Clear All Data") {
                            viewModel.alertType = .clearData
                            viewModel.showingConfirmationAlert = true
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                }
                .padding(10)
            }
            Text("Note: These options are only available in debug builds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .alert(isPresented: $viewModel.showingConfirmationAlert) {
            switch viewModel.alertType {
            case .clearData:
                return Alert(
                    title: Text("Clear All Data"),
                    message: Text("This will delete all focus sessions. This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear")) {
                        viewModel.clearAllSessions()
                    },
                    secondaryButton: .cancel()
                )
            case .addData:
                return Alert(
                    title: Text("Generate Sample Data"),
                    message: Text("This will add \(viewModel.daysToGenerate) days of sample data with ~\(viewModel.sessionsPerDay) sessions per day."),
                    primaryButton: .default(Text("Generate")) {
                        viewModel.generateSampleData()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        #else
        EmptyView()
        #endif
    }
}

#if DEBUG
// Preview provider for SwiftUI canvas
struct DebugMenuView_Previews: PreviewProvider {
    static var previews: some View {
        DebugMenuView()
            .frame(width: 500)
            .padding()
    }
}
#endif
