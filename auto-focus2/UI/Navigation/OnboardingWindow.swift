import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Group {
            if appModel.compositionRoot != nil {
                OnboardingView()
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


