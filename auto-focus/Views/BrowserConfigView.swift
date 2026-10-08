import SwiftUI

struct BrowserConfigView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @State private var showingAddURL = false
    @State private var selectedURLId: UUID?

    var body: some View {
        Form {
            BrowserIntegrationsSection(
                permissionService: focusManager.automationPermissionService,
                enablementStore: focusManager.browserEnablementStore
            )

            FocusURLsSection(selectedTab: $selectedTab, selectedURLId: $selectedURLId, showingAddURL: $showingAddURL)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Section {
            if browsers.isEmpty {
                Text("No supported browsers installed.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(browsers) { browser in
                    BrowserRow(
                        browser: browser,
                        status: permissionService.status(for: browser.bundleId),
                        isEnabled: enablementStore.isEnabled(browser.bundleId),
                        onToggle: { enabled in handleToggle(enabled, for: browser) },
                        onRequestPermission: { permissionService.requestPermission(bundleId: browser.bundleId) },
                        onOpenSettings: { permissionService.openSystemSettings() }
                    )
                }
            }

            Label(
                "Don't add your browser as a focus app — URL detection handles website tracking automatically.",
                systemImage: "lightbulb"
            )
            .labelStyle(TintedIconLabelStyle(tint: .orange))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Browser Integrations")
        } footer: {
            Text("Auto-Focus reads only the domain of your active tab so it knows when you're on a focus website. No page content is accessed. Enable each browser you'd like Auto-Focus to watch — macOS will ask for Automation permission the first time.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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

    /// AppleScript reports -600 (procNotFound) as `.notInstalled`, which here means the browser isn't running.
    private var isRunning: Bool {
        browser.isInstalled && status != .notInstalled
    }

    var body: some View {
        HStack(spacing: 10) {
            browserIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(browser.displayName)
                statusBadge
            }

            Spacer()

            if isEnabled, isRunning {
                contextualAction
            }

            Toggle(browser.displayName, isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var browserIcon: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().scaledToFit()
            } else {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .granted:
            badge("Granted", systemImage: "checkmark.circle.fill", tint: .green)
        case .denied:
            badge("Denied", systemImage: "xmark.octagon.fill", tint: .red)
        case .notDetermined:
            badge("Not determined", systemImage: "questionmark.circle.fill", tint: .orange)
        case .unknown:
            badge("Not checked", systemImage: "circle", tint: .secondary)
        case .notInstalled:
            badge("Not running", systemImage: "moon.zzz", tint: .secondary)
        }
    }

    private func badge(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(TintedIconLabelStyle(tint: tint))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var contextualAction: some View {
        switch status {
        case .denied:
            Button("Fix in System Settings…") { onOpenSettings() }
                .controlSize(.small)
        case .notDetermined, .unknown:
            Button("Request Permission") { onRequestPermission() }
                .controlSize(.small)
        default:
            EmptyView()
        }
    }
}

private struct FocusURLsSection: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @Binding var selectedURLId: UUID?
    @Binding var showingAddURL: Bool
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
        Section {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter URLs", text: $searchText, prompt: Text("Filter URLs…"))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear filter")
                }
            }

            if focusManager.focusURLs.isEmpty {
                Text("No focus URLs added yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if sortedAndFilteredURLs.isEmpty {
                Text("No URLs match \u{201C}\(searchText)\u{201D}")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(sortedAndFilteredURLs) { focusURL in
                    FocusURLRow(focusURL: focusURL)
                        .selectableFormRow(isSelected: selectedURLId == focusURL.id) {
                            selectedURLId = selectedURLId == focusURL.id ? nil : focusURL.id
                        }
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                focusManager.removeFocusURL(focusURL)
                                if selectedURLId == focusURL.id {
                                    selectedURLId = nil
                                }
                            }
                        }
                }
            }

            HStack(spacing: 4) {
                Button {
                    showingAddURL = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 12, height: 12)
                }
                .help("Add focus URL")
                .disabled(!focusManager.canAddMoreURLs)

                Button {
                    removeSelectedURL()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 12, height: 12)
                }
                .help("Remove selected URL")
                .disabled(selectedURLId == nil)

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !licenseManager.isLicensed {
                HStack {
                    Label("Upgrade to Auto-Focus+ for unlimited URLs", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Upgrade") {
                        selectedTab = 4
                    }
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Focus URLs")
        } footer: {
            Text("Being on any of these websites will automatically activate focus mode. Select a URL and click − to remove it, or right-click it.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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

private struct FocusURLRow: View {
    let focusURL: FocusURL

    private var showName: Bool {
        !focusURL.name.isEmpty && focusURL.name.lowercased() != focusURL.domain.lowercased()
            && focusURL.name.lowercased() != FocusURL.displayName(from: focusURL.domain).lowercased()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(focusURL.domain)

            if showName {
                Text(focusURL.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if focusURL.isPremium {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .help("Premium")
            }

            if !focusURL.isEnabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("Paused")
            }
        }
    }
}

private struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State private var domain = ""
    @State private var duplicateWarning = false

    private var cleanedDomain: String {
        FocusURL.focusTarget(from: domain)
    }

    private var derivedName: String {
        FocusURL.displayName(from: cleanedDomain)
    }

    private var isDuplicate: Bool {
        let domain = cleanedDomain
        guard !domain.isEmpty else { return false }
        return focusManager.focusURLs.contains { $0.domain == domain }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Domain")
                        .font(.headline)
                    TextField("e.g., github.com, *.google.com, or localhost:3000", text: $domain)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit { addURL() }

                    Text("Use *.domain.com to match all subdomains. You can also paste a full URL.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !cleanedDomain.isEmpty {
                        HStack(spacing: 4) {
                            Text("Will be saved as:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(derivedName)
                                .font(.caption)
                                .bold()
                            Text("(\(cleanedDomain))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isDuplicate {
                        Label("This domain is already in your list", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
        let domain = cleanedDomain
        guard !domain.isEmpty, !isDuplicate else { return }

        let urlToAdd = FocusURL(name: FocusURL.displayName(from: domain), domain: domain)
        focusManager.addFocusURL(urlToAdd)
        dismiss()
    }
}
