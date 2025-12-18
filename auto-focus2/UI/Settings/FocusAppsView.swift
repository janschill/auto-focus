import AppKit
import SwiftUI

struct FocusAppsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Focus Applications", subtitle: "Being in any of these apps counts toward starting focus mode.")

            HStack {
                Button {
                    viewModel.presentAppPickerAndAdd()
                } label: {
                    Label("Add App…", systemImage: "plus")
                }

                Spacer()
            }

            List {
                ForEach(viewModel.focusApps) { entity in
                    HStack(spacing: 10) {
                        appIcon(bundleId: entity.matchValue)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entity.displayName)
                            Text(entity.matchValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.deleteEntity(entity)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 360)

            if let err = viewModel.lastError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
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

    private func appIcon(bundleId: String) -> Image {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return Image(nsImage: icon)
        }
        return Image(systemName: "app")
    }
}


