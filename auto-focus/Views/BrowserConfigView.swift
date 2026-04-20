import SwiftUI

struct BrowserConfigView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @State private var showingAddURL = false
    @State private var selectedURLId: UUID?

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()

            BrowserIntegrationsSection(
                permissionService: focusManager.automationPermissionService,
                enablementStore: focusManager.browserEnablementStore
            )

            FocusURLsManagementView(selectedTab: $selectedTab, selectedURLId: $selectedURLId, showingAddURL: $showingAddURL)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddURL) {
            AddURLSheet()
                .frame(minWidth: 500, minHeight: 300)
        }
    }
}

private struct BrowserIntegrationsSection: View {
    @ObservedObject var permissionService: AutomationPermissionService
    @ObservedObject var enablementStore: BrowserEnablementStore

    @State private var browsers: [BrowserDescriptor] = []

    var body: some View {
        GroupBox(label: Text("Browser integrations").font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Auto-Focus reads only the domain of your active tab so it knows when you're on a focus website. No page content is accessed. Enable each browser you'd like Auto-Focus to watch — macOS will ask for Automation permission the first time.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if browsers.isEmpty {
                    Text("No supported browsers installed.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                            BrowserRow(
                                browser: browser,
                                status: permissionService.status(for: browser.bundleId),
                                isEnabled: enablementStore.isEnabled(browser.bundleId),
                                onToggle: { enabled in handleToggle(enabled, for: browser) },
                                onRequestPermission: { permissionService.requestPermission(bundleId: browser.bundleId) },
                                onOpenSettings: { permissionService.openSystemSettings() }
                            )
                            if index < browsers.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            browsers = AppConfiguration.installedSupportedBrowsers()
            permissionService.refreshAll(bundleIds: browsers.map(\.bundleId))
        }
    }

    private func handleToggle(_ enabled: Bool, for browser: BrowserDescriptor) {
        enablementStore.setEnabled(enabled, for: browser.bundleId)
        guard enabled else { return }
        let current = permissionService.status(for: browser.bundleId)
        if current != .granted {
            let resolved = permissionService.requestPermission(bundleId: browser.bundleId)
            enablementStore.updateCachedStatus(resolved, for: browser.bundleId)
        }
    }
}

private struct BrowserRow: View {
    let browser: BrowserDescriptor
    let status: BrowserPermissionStatus
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            browserIcon
                .frame(width: 28, height: 28)

            Text(browser.displayName)
                .font(.body)

            statusBadge

            Spacer()

            if isEnabled {
                contextualAction
            }

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var browserIcon: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .granted:
            badge(systemImage: "checkmark.circle.fill", text: "Granted", color: .green)
        case .denied:
            badge(systemImage: "xmark.octagon.fill", text: "Denied", color: .red)
        case .notDetermined:
            badge(systemImage: "questionmark.circle.fill", text: "Not determined", color: .orange)
        case .unknown:
            badge(systemImage: "circle", text: "Not checked", color: .secondary)
        case .notInstalled:
            badge(systemImage: "slash.circle", text: "Not installed", color: .secondary)
        }
    }

    private func badge(systemImage: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
    }

    @ViewBuilder
    private var contextualAction: some View {
        switch status {
        case .denied:
            Button("Fix in System Settings…") { onOpenSettings() }
                .controlSize(.small)
        case .notDetermined, .unknown:
            Button("Request permission") { onRequestPermission() }
                .controlSize(.small)
        default:
            EmptyView()
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
                Text("Track focus time on specific websites and web apps. Auto-Focus automatically detects URLs in Safari, Chrome, Brave, Edge, Arc, and other browsers.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("💡 Tip: Don't add your browser as a focus app — URL detection handles website tracking automatically!")
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
    @State private var searchText = ""

    private var sortedAndFilteredURLs: [FocusURL] {
        let sorted = focusManager.focusURLs.sorted {
            $0.sortableDomain.localizedCaseInsensitiveCompare($1.sortableDomain) == .orderedAscending
        }
        guard !searchText.isEmpty else { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.domain.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter URLs…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            List(selection: $selectedURLId) {
                ForEach(sortedAndFilteredURLs) { focusURL in
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
                        selectedTab = 4
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct FocusURLRowSimple: View {
    let focusURL: FocusURL

    private var showName: Bool {
        !focusURL.name.isEmpty && focusURL.name.lowercased() != focusURL.domain.lowercased()
            && focusURL.name.lowercased() != FocusURL.displayName(from: focusURL.domain).lowercased()
    }

    var body: some View {
        HStack {
            Image(systemName: focusURL.category.icon)
                .foregroundColor(colorForCategory(focusURL.category))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(focusURL.domain)
                        .font(.body.monospaced())

                    if showName {
                        Text(focusURL.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

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
            }
        }
        .tag(focusURL.id)
    }

    private func colorForCategory(_ category: URLCategory) -> Color {
        switch category.color {
        case "blue": .blue
        case "green": .green
        case "purple": .purple
        case "pink": .pink
        case "orange": .orange
        case "indigo": .indigo
        case "yellow": .yellow
        default: .gray
        }
    }
}

private struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State private var domain = ""
    @State private var duplicateWarning = false

    private var cleanedDomain: String {
        var d = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let url = URL(string: d), let host = url.host {
            d = host
        } else if d.contains("://") {
            d = d.components(separatedBy: "://").last ?? d
        }

        d = d.components(separatedBy: "/").first ?? d
        d = d.components(separatedBy: "?").first ?? d

        return d
    }

    private var derivedName: String {
        FocusURL.displayName(from: cleanedDomain)
    }

    private var isDuplicate: Bool {
        let d = cleanedDomain
        guard !d.isEmpty else { return false }
        return focusManager.focusURLs.contains { $0.domain == d }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Domain")
                        .font(.headline)
                    TextField("e.g., github.com or *.google.com", text: $domain)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit { addURL() }

                    Text("Use *.domain.com to match all subdomains. You can also paste a full URL.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !cleanedDomain.isEmpty {
                        HStack(spacing: 4) {
                            Text("Will be saved as:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(derivedName)
                                .font(.caption)
                                .bold()
                            Text("(\(cleanedDomain))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if isDuplicate {
                        Label("This domain is already in your list", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
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
                    .disabled(cleanedDomain.isEmpty || isDuplicate)
                }
            }
        }
    }

    private func addURL() {
        let d = cleanedDomain
        guard !d.isEmpty, !isDuplicate else { return }

        let urlToAdd = FocusURL(name: FocusURL.displayName(from: d), domain: d)
        focusManager.addFocusURL(urlToAdd)
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

