import SwiftUI

struct FocusAppsView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    
    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            EnablementToggleView(focusManager: focusManager)
            
            if focusManager.isFocusAppsEnabled {
                FocusApplicationsManagementView(focusManager: focusManager, licenseManager: licenseManager)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack {
                Text("Focus Apps").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Automatically activate focus mode when using specific applications. Focus apps are monitored continuously to detect when you're working on focused tasks.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EnablementToggleView: View {
    let focusManager: FocusManager
    
    var body: some View {
        GroupBox {
            VStack {
                HStack {
                    Text("Enable Focus Apps Integration")
                        .frame(width: 250, alignment: .leading)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { focusManager.isFocusAppsEnabled },
                        set: { newValue in
                            focusManager.isFocusAppsEnabled = newValue
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 5)
                }
                
                if !focusManager.isFocusAppsEnabled {
                    HStack {
                        Text("Enable this integration to automatically trigger focus mode when using your designated focus applications.")
                            .font(.callout)
                            .fontDesign(.default)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FocusApplicationsManagementView: View {
    let focusManager: FocusManager
    let licenseManager: LicenseManager
    
    var body: some View {
        GroupBox("Focus Applications") {
            VStack(alignment: .leading) {
                Text("Being in any of these apps will automatically activate focus mode.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                AppsListView()

                HStack {
                    Button {
                        DispatchQueue.main.async {
                            focusManager.selectFocusApplication()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!licenseManager.isLicensed)

                    Button {
                        DispatchQueue.main.async {
                            focusManager.removeSelectedApp()
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(focusManager.selectedAppId == nil)

                    Spacer()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppsListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        List(selection: $focusManager.selectedAppId) {
            ForEach(focusManager.focusApps) { app in
                AppRowView(app: app)
            }
        }
        .listStyle(.bordered)

        if !licenseManager.isLicensed {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text("Upgrade to Auto-Focus+ for unlimited apps")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Upgrade") {
                    // Instead of changing tabs, show an alert or notification
                    // This removes the circular binding dependency
                    print("Upgrade to premium for export/import features")
                }
                .controlSize(.small)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

private struct AppRowView: View {
    let app: AppInfo

    var body: some View {
        HStack {
            if let appIcon = SafeImageLoader.loadAppIcon(for: app.bundleIdentifier) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                // Fallback to SF Symbol if app icon can't be loaded safely
                Image(systemName: "app.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading) {
                Text(app.name)
                    .font(.headline)
            }
        }
        .tag(app.id)
    }
}

#Preview {
    FocusAppsView()
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 800)
}