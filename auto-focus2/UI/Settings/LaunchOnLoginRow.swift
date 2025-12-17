import SwiftUI

struct LaunchOnLoginRow: View {
    @Binding var isEnabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle("Launch on login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                onChange(newValue)
            }
    }
}


