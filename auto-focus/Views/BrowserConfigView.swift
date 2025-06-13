import SwiftUI

struct BrowserConfigView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showingAddURL = false
    @State private var showingPresets = false
    @State private var newURL = FocusURL(name: "", domain: "")
    @State private var selectedCategory: URLCategory = .work
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderView()
            
            ExtensionStatusView()
            
            FocusURLsListView(showingAddURL: $showingAddURL, showingPresets: $showingPresets)
            
            if focusManager.focusURLs.isEmpty {
                EmptyStateView(showingPresets: $showingPresets)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddURL) {
            AddURLSheet(newURL: $newURL, selectedCategory: $selectedCategory)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showingPresets) {
            URLPresetsSheet()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browser Integration")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Track focus time on specific websites and web apps")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct ExtensionStatusView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingHealthDetails = false
    
    var body: some View {
        GroupBox("Extension Status") {
            VStack(spacing: 12) {
                // Main status row
                HStack {
                    connectionStatusIcon
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(connectionStatusText)
                                .font(.headline)
                            
                            if focusManager.isExtensionConnected {
                                connectionQualityBadge
                            }
                        }
                        
                        Text(connectionStatusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    actionButtons
                }
                
                // Extension health details (if connected)
                if focusManager.isExtensionConnected {
                    extensionHealthRow
                }
                
                // Detailed health view
                if showingHealthDetails && focusManager.extensionHealth != nil {
                    Divider()
                    ExtensionHealthDetailView(health: focusManager.extensionHealth!)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var connectionStatusIcon: some View {
        Image(systemName: focusManager.isExtensionConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundColor(focusManager.isExtensionConnected ? .green : .orange)
            .font(.title2)
    }
    
    private var connectionStatusText: String {
        if focusManager.isExtensionConnected {
            return "Chrome Extension Connected"
        } else {
            return "Chrome Extension Not Connected"
        }
    }
    
    private var connectionStatusDescription: String {
        if focusManager.isExtensionConnected {
            let quality = focusManager.connectionQuality.displayName
            return "Browser tabs are being monitored • Connection: \(quality)"
        } else {
            return "Install and activate the Chrome extension to track browser focus"
        }
    }
    
    private var connectionQualityBadge: some View {
        Label(focusManager.connectionQuality.displayName, systemImage: focusManager.connectionQuality.icon)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(focusManager.connectionQuality.color).opacity(0.2))
            .foregroundColor(Color(focusManager.connectionQuality.color))
            .cornerRadius(4)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if !focusManager.isExtensionConnected {
                Button("Install Extension") {
                    openExtensionInstallation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                if focusManager.extensionHealth != nil {
                    Button(showingHealthDetails ? "Hide Details" : "Show Details") {
                        showingHealthDetails.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Reconnect") {
                    reconnectExtension()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var extensionHealthRow: some View {
        HStack {
            if let health = focusManager.extensionHealth {
                HStack(spacing: 16) {
                    Label("v\(health.version)", systemImage: "app.badge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if health.errors.isEmpty {
                        Label("No errors", systemImage: "checkmark.shield")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("\(health.errors.count) error\(health.errors.count == 1 ? "" : "s")", systemImage: "exclamationmark.shield")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if health.consecutiveFailures > 0 {
                        Label("\(health.consecutiveFailures) failures", systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func openExtensionInstallation() {
        if let url = URL(string: "https://chrome.google.com/webstore/detail/auto-focus/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func reconnectExtension() {
        // This would trigger a reconnection attempt
        print("Triggering extension reconnection")
    }
}

private struct ExtensionHealthDetailView: View {
    let health: ExtensionHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extension Health Details")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Version:")
                        .foregroundColor(.secondary)
                    Text(health.version)
                }
                
                if let installDate = health.installationDate {
                    GridRow {
                        Text("Installed:")
                            .foregroundColor(.secondary)
                        Text(installDate, style: .date)
                    }
                }
                
                if let lastUpdate = health.lastUpdateCheck {
                    GridRow {
                        Text("Last Check:")
                            .foregroundColor(.secondary)
                        Text(lastUpdate, style: .relative)
                    }
                }
                
                GridRow {
                    Text("Consecutive Failures:")
                        .foregroundColor(.secondary)
                    Text("\(health.consecutiveFailures)")
                        .foregroundColor(health.consecutiveFailures > 0 ? .red : .primary)
                }
            }
            .font(.caption)
            
            if !health.errors.isEmpty {
                Text("Recent Errors:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                ForEach(health.errors.prefix(3)) { error in
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(error.type.capitalized)
                                .font(.caption2)
                                .fontWeight(.medium)
                            Text(error.message)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Text(error.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                
                if health.errors.count > 3 {
                    Text("... and \(health.errors.count - 3) more errors")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct FocusURLsListView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var showingAddURL: Bool
    @Binding var showingPresets: Bool
    
    var body: some View {
        GroupBox("Focus URLs") {
            VStack(spacing: 12) {
                // Header with add buttons
                HStack {
                    Text("Configure which websites count as focus work")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Preset") {
                        showingPresets = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Add Custom") {
                        showingAddURL = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!focusManager.canAddMoreURLs)
                }
                
                // URL limits info
                if !licenseManager.isLicensed {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("Free tier: \(focusManager.focusURLs.count)/3 URLs")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if !focusManager.canAddMoreURLs {
                            Text("Upgrade for unlimited URLs")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // URLs list
                if !focusManager.focusURLs.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(focusManager.focusURLs) { focusURL in
                            FocusURLRow(focusURL: focusURL)
                                .background(Color(.controlBackgroundColor))
                        }
                    }
                    .background(Color(.separatorColor))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct FocusURLRow: View {
    let focusURL: FocusURL
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingEdit = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: focusURL.category.icon)
                .foregroundColor(colorForCategory(focusURL.category))
                .frame(width: 20)
            
            // URL info
            VStack(alignment: .leading, spacing: 2) {
                Text(focusURL.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(focusURL.domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(focusURL.matchType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status and actions
            HStack(spacing: 8) {
                if !focusURL.isEnabled {
                    Image(systemName: "pause.circle")
                        .foregroundColor(.orange)
                }
                
                if focusURL.isPremium && focusManager.focusURLs.contains(where: { $0.id == focusURL.id }) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                Menu {
                    Button("Edit") {
                        showingEdit = true
                    }
                    
                    Button("Toggle \(focusURL.isEnabled ? "Disable" : "Enable")") {
                        var updatedURL = focusURL
                        updatedURL.isEnabled.toggle()
                        focusManager.updateFocusURL(updatedURL)
                    }
                    
                    Divider()
                    
                    Button("Remove", role: .destructive) {
                        focusManager.removeFocusURL(focusURL)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(focusURL.isEnabled ? Color.clear : Color.gray.opacity(0.15))
        .sheet(isPresented: $showingEdit) {
            EditURLSheet(focusURL: focusURL)
        }
    }
    
    private func colorForCategory(_ category: URLCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "indigo": return .indigo
        case "yellow": return .yellow
        default: return .gray
        }
    }
}

private struct EmptyStateView: View {
    @Binding var showingPresets: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.badge.chevron.backward")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Focus URLs Configured")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Add websites that should count as focus work. Popular options like GitHub and Google Docs are available as presets.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Browse Presets") {
                showingPresets = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
    }
}

private struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @Binding var newURL: FocusURL
    @Binding var selectedCategory: URLCategory
    @State private var selectedMatchType: URLMatchType = .domain
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GroupBox("URL Information") {
                    VStack(spacing: 12) {
                        TextField("Name (e.g., 'GitHub')", text: $newURL.name)
                        TextField("Domain (e.g., 'github.com')", text: $newURL.domain)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 8)
                }
                
                GroupBox("Matching") {
                    VStack(spacing: 12) {
                        Picker("Match Type", selection: $selectedMatchType) {
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
                    }
                    .padding(.vertical, 8)
                }
                
                GroupBox("Category") {
                    VStack(spacing: 12) {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(URLCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 8)
                }
                
                if !newURL.domain.isEmpty {
                    GroupBox("Preview") {
                        VStack(spacing: 8) {
                            Text("Will match URLs like:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(previewText)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                        }
                        .padding(.vertical, 8)
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
                    .disabled(newURL.name.isEmpty || newURL.domain.isEmpty)
                }
            }
        }
    }
    
    private var previewText: String {
        let domain = newURL.domain.lowercased()
        switch selectedMatchType {
        case .exact:
            return domain
        case .domain:
            return "\(domain), www.\(domain), app.\(domain)"
        case .contains:
            return "Any URL containing '\(domain)'"
        case .startsWith:
            return "URLs starting with '\(domain)'"
        }
    }
    
    private func addURL() {
        var urlToAdd = newURL
        urlToAdd.category = selectedCategory
        urlToAdd.matchType = selectedMatchType
        urlToAdd.domain = urlToAdd.domain.lowercased()
        
        focusManager.addFocusURL(urlToAdd)
        
        // Reset form
        newURL = FocusURL(name: "", domain: "")
        selectedCategory = .work
        selectedMatchType = .domain
        
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

#Preview {
    BrowserConfigView()
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
}