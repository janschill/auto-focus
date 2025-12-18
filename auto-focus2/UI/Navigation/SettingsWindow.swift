import SwiftUI

struct SettingsWindow: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Group {
            if let root = appModel.compositionRoot {
                SettingsRootView(viewModel: SettingsViewModel(root: root))
            } else {
                VStack(spacing: 12) {
                    Text("Not initialized")
                        .font(.headline)
                    Button("Initialize") { appModel.start() }
                }
                .padding(20)
            }
        }
    }
}


