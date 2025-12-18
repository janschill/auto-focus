import SwiftUI

struct FocusDomainsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Focus Domains", subtitle: "When a supported browser is frontmost, the active tab’s domain can count toward focus mode.")

            HStack(spacing: 10) {
                TextField("example.com", text: $viewModel.newDomainValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                Button {
                    viewModel.addDomain()
                } label: {
                    Label("Add Domain", systemImage: "plus")
                }
            }

            List {
                ForEach(viewModel.focusDomains) { entity in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
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
}


