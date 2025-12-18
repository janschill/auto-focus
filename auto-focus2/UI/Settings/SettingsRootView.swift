import SwiftUI

struct SettingsRootView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            FocusAppsView(viewModel: viewModel)
                .tabItem { Label("Apps", systemImage: "square.stack.3d.up") }

            FocusDomainsView(viewModel: viewModel)
                .tabItem { Label("Domains", systemImage: "globe") }

            AutoFocusPlusView(viewModel: viewModel)
                .tabItem { Label("AutoFocus+", systemImage: "star.fill") }
        }
        .padding(12)
        .frame(minWidth: 820, minHeight: 620)
        .onDisappear { viewModel.saveLicenseKey() }
    }
}


