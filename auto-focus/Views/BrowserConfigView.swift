import SwiftUI

struct BrowserConfigView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @State private var showingAddURL = false
    @State private var newURL = FocusURL(name: "", domain: "")
    @State private var selectedCategory: URLCategory = .work
    @State private var selectedURLId: UUID?

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()

            ExtensionInstallationView()

            FocusURLsManagementView(selectedTab: $selectedTab, selectedURLId: $selectedURLId, showingAddURL: $showingAddURL)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddURL) {
            AddURLSheet(newURL: $newURL, selectedCategory: $selectedCategory)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack {
                Text("Browser Integration").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("Track focus time on specific websites and web apps. Add from a list of common categories or add your own URLs. Added websites will behave just like your focus apps")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("💡 Tip: Don't add Chrome as a focus app - the extension handles website detection automatically!")
                    .font(.caption)
                    .fontDesign(.default)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 40)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

// private struct HeaderView: View {
//    var body: some View {
//        GroupBox {
//            VStack(spacing: 8) {
//                HStack {
//                    Image(systemName: "globe")
//                        .font(.title2)
//                        .foregroundColor(.blue)
//
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Browser Integration")
//                            .font(.title2)
//                            .fontWeight(.bold)
//
//                        Text("Track focus time on specific websites and web apps")
//                            .font(.callout)
//                            .foregroundColor(.secondary)
//                    }
//
//                    Spacer()
//                }
//            }
//            .padding(.vertical, 8)
//        }
//    }
// }

private struct ExtensionInstallationView: View {
    var body: some View {
        GroupBox {
            VStack {
                HStack {
                    Text("Chrome Extension")
                        .frame(width: 150, alignment: .leading)

                    Spacer()

                    Button("Install Extension") {
                        openExtensionInstallation()
                    }
                }

                HStack {
                    Text("Install the Chrome extension to monitor and track focus time on websites. The extension communicates with the app to coordinate focus sessions.")
                        .font(.callout)
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("Chrome will NOT be added as a focus app - the extension only activates for specific websites you configure.")
                        .font(.caption)
                        .fontDesign(.default)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }

    private func openExtensionInstallation() {
        if let url = URL(string: "https://chromewebstore.google.com/detail/ncmjhohihnjjmkfpcibbafakmlbfifih") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct FocusURLsManagementView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @Binding var selectedURLId: UUID?
    @Binding var showingAddURL: Bool

    var body: some View {
        GroupBox(label: Text("Focus URLs").font(.headline)) {
            VStack(alignment: .leading) {
                Text("Being on any of these websites will automatically activate focus mode.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)

                FocusURLsList(selectedTab: $selectedTab, selectedURLId: $selectedURLId)

                HStack {
                    Button {
                        showingAddURL = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 16, height: 16)
                    }
                    .disabled(!focusManager.canAddMoreURLs)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 28, height: 28)

                    Button {
                        removeSelectedURL()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 16, height: 16)
                    }
                    .disabled(selectedURLId == nil)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 28, height: 28)

                    Spacer()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }

    private func removeSelectedURL() {
        guard let selectedId = selectedURLId,
              let focusURL = focusManager.focusURLs.first(where: { $0.id == selectedId }) else {
            return
        }

        focusManager.removeFocusURL(focusURL)
        selectedURLId = nil
    }
}

private struct FocusURLsList: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @Binding var selectedURLId: UUID?

    var body: some View {
        VStack {
            List(selection: $selectedURLId) {
                ForEach(focusManager.focusURLs) { focusURL in
                    FocusURLRowSimple(focusURL: focusURL)
                }
            }
            .listStyle(.bordered)
            .animation(.easeInOut(duration: 0.2), value: focusManager.focusURLs.count)

            if !licenseManager.isLicensed {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Upgrade to Auto-Focus+ for unlimited URLs")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Upgrade") {
                        selectedTab = 4 // Navigate to Auto-Focus+ tab
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
}

private struct FocusURLRowSimple: View {
    let focusURL: FocusURL

    var body: some View {
        HStack {
            Image(systemName: focusURL.category.icon)
                .foregroundColor(colorForCategory(focusURL.category))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(focusURL.name)
                        .font(.headline)

                    if focusURL.isPremium {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }

                    if !focusURL.isEnabled {
                        Image(systemName: "pause.circle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                Text(focusURL.domain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .tag(focusURL.id)
    }

    private func colorForCategory(_ category: URLCategory) -> Color {
        switch category.color {
        case "blue":
            return .blue
        case "green":
            return .green
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "orange":
            return .orange
        case "indigo":
            return .indigo
        case "yellow":
            return .yellow
        default:
            return .gray
        }
    }
}

private struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @Binding var newURL: FocusURL
    @Binding var selectedCategory: URLCategory

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .font(.headline)
                    TextField("e.g., GitHub", text: $newURL.name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Domain")
                        .font(.headline)
                    TextField("e.g., github.com", text: $newURL.domain)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Focus URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addURL()
                    }
                    .disabled(newURL.name.isEmpty || newURL.domain.isEmpty)
                }
            }
        }
    }

    private func addURL() {
        var urlToAdd = newURL
        urlToAdd.category = selectedCategory
        urlToAdd.matchType = .domain // Default to domain matching
        urlToAdd.domain = urlToAdd.domain.lowercased()

        focusManager.addFocusURL(urlToAdd)

        // Reset form
        newURL = FocusURL(name: "", domain: "")
        selectedCategory = .work

        dismiss()
    }
}

private struct EditURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State var focusURL: FocusURL

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GroupBox("URL Information") {
                    VStack(spacing: 12) {
                        TextField("Name", text: $focusURL.name)
                        TextField("Domain", text: $focusURL.domain)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 8)
                }

                GroupBox("Settings") {
                    VStack(spacing: 12) {
                        Picker("Match Type", selection: $focusURL.matchType) {
                            ForEach(URLMatchType.allCases, id: \.self) { type in
                                VStack(alignment: .leading) {
                                    Text(type.displayName)
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Category", selection: $focusURL.category) {
                            ForEach(URLCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Enabled", isOn: $focusURL.isEnabled)
                    }
                    .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Focus URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveURL()
                    }
                }
            }
        }
    }

    private func saveURL() {
        focusManager.updateFocusURL(focusURL)
        dismiss()
    }
}

private struct URLPresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedPresets: Set<UUID> = []

    var body: some View {
        NavigationView {
            List {
                ForEach(URLCategory.allCases, id: \.self) { category in
                    let presetsInCategory = focusManager.availableURLPresets.filter { $0.category == category }

                    if !presetsInCategory.isEmpty {
                        Section(category.displayName) {
                            ForEach(presetsInCategory) { preset in
                                PresetRow(
                                    preset: preset,
                                    isSelected: selectedPresets.contains(preset.id),
                                    canSelect: !preset.isPremium || licenseManager.isLicensed,
                                    onToggle: { togglePreset(preset) }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Preset URLs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected") {
                        addSelectedPresets()
                    }
                    .disabled(selectedPresets.isEmpty)
                }
            }
        }
    }

    private func togglePreset(_ preset: FocusURL) {
        if selectedPresets.contains(preset.id) {
            selectedPresets.remove(preset.id)
        } else {
            selectedPresets.insert(preset.id)
        }
    }

    private func addSelectedPresets() {
        let presetsToAdd = focusManager.availableURLPresets.filter { selectedPresets.contains($0.id) }
        focusManager.addPresetURLs(presetsToAdd)
        dismiss()
    }
}

private struct PresetRow: View {
    let preset: FocusURL
    let isSelected: Bool
    let canSelect: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    Image(systemName: preset.category.icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(preset.name)
                                .font(.headline)

                            if preset.isPremium {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }

                        Text(preset.domain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSelect)
            .opacity(canSelect ? 1.0 : 0.6)
        }
    }
}

