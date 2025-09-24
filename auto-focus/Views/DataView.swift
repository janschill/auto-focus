import SwiftUI

struct DataView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 10) {
            DataHeaderView()
            DataOverviewView()
            DataSessionManagementView()
            DataExportImportView(selectedTab: $selectedTab)

            Spacer()
        }
        .padding()
    }
}

struct DataHeaderView: View {
    var body: some View {
        GroupBox {
            VStack {
                Text("Data Management").font(.title)
                    .fontDesign(.default)
                    .fontWeight(.bold)
                    .bold()
                Text("View your data statistics, export your focus sessions and settings, or import data from another device.")
                    .font(.callout)
                    .fontDesign(.default)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 50)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DataOverviewView: View {
    @EnvironmentObject var focusManager: FocusManager

    private var dataMetrics: DataMetrics {
        DataMetrics(
            totalSessions: focusManager.focusSessions.count,
            totalFocusTime: focusManager.focusSessions.reduce(0) { $0 + $1.duration },
            totalFocusApps: focusManager.focusApps.count,
            oldestSession: focusManager.focusSessions.min { $0.startTime < $1.startTime },
            newestSession: focusManager.focusSessions.max { $0.startTime < $1.startTime },
            thisWeekSessions: focusManager.weekSessions.count,
            thisMonthSessions: focusManager.monthSessions.count
        )
    }

    var body: some View {
        GroupBox(label: Text("Data Overview").font(.headline)) {
            VStack(spacing: 16) {
                // Quick stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    DataStatCard(
                        title: "Total Sessions",
                        value: "\(dataMetrics.totalSessions)",
                        icon: "clock.fill",
                        color: .blue
                    )

                    DataStatCard(
                        title: "Total Focus Time",
                        value: TimeFormatter.duration(Int(dataMetrics.totalFocusTime / 60)),
                        icon: "brain.head.profile.fill",
                        color: .purple
                    )

                    DataStatCard(
                        title: "Focus Apps",
                        value: "\(dataMetrics.totalFocusApps)",
                        icon: "app.fill",
                        color: .green
                    )
                }

                Divider()

                // Date range and recent activity
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Range")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            if let oldest = dataMetrics.oldestSession,
                               let newest = dataMetrics.newestSession {
                                Text("\(oldest.startTime, formatter: DateFormatter.mediumDate) - \(newest.startTime, formatter: DateFormatter.mediumDate)")
                                    .font(.body)
                            } else {
                                Text("No sessions recorded")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Recent Activity")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                VStack {
                                    Text("\(dataMetrics.thisWeekSessions)")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("This Week")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack {
                                    Text("\(dataMetrics.thisMonthSessions)")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("This Month")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DataSessionManagementView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingSessionList = false
    
    var body: some View {
        GroupBox(label: Text("Session Management").font(.headline)) {
            VStack(spacing: 16) {
                Text("View and edit your focus sessions. Correct any incorrect session entries or remove unwanted sessions.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(focusManager.focusSessions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    if focusManager.focusSessions.count > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Shortest Session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let shortest = focusManager.focusSessions.min(by: { $0.duration < $1.duration }) {
                                Text(TimeFormatter.duration(Int(shortest.duration / 60)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(shortest.duration < 60 ? .orange : .primary)
                            }
                        }
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Longest Session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let longest = focusManager.focusSessions.max(by: { $0.duration < $1.duration }) {
                                Text(TimeFormatter.duration(Int(longest.duration / 60)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    
                    Button("Manage Sessions") {
                        showingSessionList = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(focusManager.focusSessions.isEmpty)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingSessionList) {
            NavigationView {
                SessionListView()
                    .navigationTitle("Focus Sessions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSessionList = false
                            }
                        }
                    }
            }
            .frame(minWidth: 700, minHeight: 600)
        }
    }
}

struct DataStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DataExportImportView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int
    @State private var showingExportOptions = false
    @State private var exportOptions = ExportOptions.default
    @State private var showingImportAlert = false
    @State private var importResult: ImportResult?
    @State private var showingExportPreview = false

    private var exportPreview: ExportPreview {
        let options = exportOptions
        let sessions = options.includeSessions ? filterSessions(by: options.dateRange) : []
        let apps = options.includeFocusApps ? focusManager.focusApps : []

        return ExportPreview(
            sessionCount: sessions.count,
            focusAppsCount: apps.count,
            includesSettings: options.includeSettings,
            totalFocusTime: sessions.reduce(0) { $0 + $1.duration },
            dateRange: getDateRange(for: sessions),
            estimatedFileSize: estimateFileSize(sessions: sessions, apps: apps, includeSettings: options.includeSettings)
        )
    }

    var body: some View {
        GroupBox(label: Text("Export & Import").font(.headline)) {
            VStack(spacing: 16) {
                Text("Export your data to JSON format for backup or transfer to another device.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !licenseManager.isLicensed {
                    PremiumRequiredView(selectedTab: $selectedTab)
                } else {
                    VStack(spacing: 16) {
                        // Export preview card
                        ExportPreviewCard(preview: exportPreview, options: $exportOptions)

                        // Action buttons
                        HStack(spacing: 16) {
                            Button("Customize Export") {
                                showingExportOptions = true
                            }
                            .buttonStyle(.bordered)

                            Button("Export Data") {
                                focusManager.exportDataToFile(options: exportOptions)
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button("Import Data") {
                                focusManager.importDataFromFile { result in
                                    importResult = result
                                    showingImportAlert = true
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                options: $exportOptions,
                onExport: {
                    focusManager.exportDataToFile(options: exportOptions)
                    showingExportOptions = false
                },
                onCancel: {
                    showingExportOptions = false
                }
            )
        }
        .alert("Import Result", isPresented: $showingImportAlert) {
            Button("OK") { importResult = nil }
        } message: {
            if let result = importResult {
                switch result {
                case .success(let summary):
                    Text("Successfully imported \(summary.sessionsImported) sessions, \(summary.focusAppsImported) apps. \(summary.duplicatesSkipped) duplicates skipped.")
                case .failure(let error):
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // Helper methods
    private func filterSessions(by dateRange: DateRange?) -> [FocusSession] {
        guard let range = dateRange else { return focusManager.focusSessions }

        return focusManager.focusSessions.filter { session in
            session.startTime >= range.startDate && session.endTime <= range.endDate
        }
    }

    private func getDateRange(for sessions: [FocusSession]) -> String {
        guard !sessions.isEmpty else { return "No sessions" }

        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        guard let first = sortedSessions.first, let last = sortedSessions.last else {
            return "No sessions"
        }

        if Calendar.current.isDate(first.startTime, inSameDayAs: last.startTime) {
            return DateFormatter.mediumDate.string(from: first.startTime)
        } else {
            return "\(DateFormatter.shortDate.string(from: first.startTime)) - \(DateFormatter.shortDate.string(from: last.startTime))"
        }
    }

    private func estimateFileSize(sessions: [FocusSession], apps: [AppInfo], includeSettings: Bool) -> String {
        // Rough estimation: each session ~150 bytes, each app ~100 bytes, settings ~50 bytes
        let sessionSize = sessions.count * 150
        let appSize = apps.count * 100
        let settingsSize = includeSettings ? 50 : 0
        let metadataSize = 200

        let totalBytes = sessionSize + appSize + settingsSize + metadataSize

        if totalBytes < 1024 {
            return "\(totalBytes) bytes"
        } else if totalBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalBytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(totalBytes) / (1024 * 1024))
        }
    }
}

struct PremiumRequiredView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
            Text("Export and import require Auto-Focus+ subscription")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Upgrade") {
                selectedTab = 3
            }
            .controlSize(.small)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

struct ExportPreviewCard: View {
    let preview: ExportPreview
    @Binding var options: ExportOptions

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Export Preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("~\(preview.estimatedFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ExportMetricItem(
                    title: "Sessions",
                    value: "\(preview.sessionCount)",
                    enabled: options.includeSessions,
                    icon: "clock"
                )

                ExportMetricItem(
                    title: "Focus Apps",
                    value: "\(preview.focusAppsCount)",
                    enabled: options.includeFocusApps,
                    icon: "app"
                )

                ExportMetricItem(
                    title: "Settings",
                    value: preview.includesSettings ? "✓" : "✗",
                    enabled: preview.includesSettings,
                    icon: "gear"
                )
            }

            if preview.sessionCount > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(TimeFormatter.duration(Int(preview.totalFocusTime / 60)))
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Date Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(preview.dateRange)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ExportMetricItem: View {
    let title: String
    let value: String
    let enabled: Bool
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(enabled ? .accentColor : .secondary)
                .font(.caption)

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(enabled ? .primary : .secondary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(enabled ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Supporting Models

struct DataMetrics {
    let totalSessions: Int
    let totalFocusTime: TimeInterval
    let totalFocusApps: Int
    let oldestSession: FocusSession?
    let newestSession: FocusSession?
    let thisWeekSessions: Int
    let thisMonthSessions: Int
}

struct ExportPreview {
    let sessionCount: Int
    let focusAppsCount: Int
    let includesSettings: Bool
    let totalFocusTime: TimeInterval
    let dateRange: String
    let estimatedFileSize: String
}

// MARK: - Extensions

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - Export Options View (moved from ConfigurationView)

struct ExportOptionsView: View {
    @Binding var options: ExportOptions
    let onExport: () -> Void
    let onCancel: () -> Void
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var useDateRange = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Export Options")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel", action: onCancel)
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 16) {
                Text("What to export:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Focus sessions", isOn: $options.includeSessions)
                    Toggle("Focus apps configuration", isOn: $options.includeFocusApps)
                    Toggle("Settings and preferences", isOn: $options.includeSettings)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Export specific date range", isOn: $useDateRange)

                    if useDateRange {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("From:")
                                    .font(.caption)
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading) {
                                Text("To:")
                                    .font(.caption)
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Export") {
                    if useDateRange {
                        options = ExportOptions(
                            includeSessions: options.includeSessions,
                            includeSettings: options.includeSettings,
                            includeFocusApps: options.includeFocusApps,
                            dateRange: DateRange(startDate: startDate, endDate: endDate)
                        )
                    }
                    onExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!options.includeSessions && !options.includeSettings && !options.includeFocusApps)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

#Preview {
    DataView(selectedTab: .constant(3))
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 800)
}
