import SwiftUI

struct DataView: View {
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var selectedTab: Int

    @State private var dataMetrics = DataMetrics.empty
    @State private var showingSessionList = false
    @State private var sheetInitialFilter: SessionDurationFilter = .all
    @State private var sheetInitialSort: SessionSortOrder = .newest
    @State private var showingExportOptions = false
    @State private var exportOptions = ExportOptions.default
    @State private var estimatedExportSize = ""
    @State private var showingImportAlert = false
    @State private var importResult: ImportResult?

    private var dataExportService: DataExportService {
        DataExportService(focusManager: focusManager)
    }

    var body: some View {
        Form {
            overviewSection
            sessionsSection
            exportImportSection
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onChange(of: focusManager.focusSessions) { refresh() }
        .onChange(of: focusManager.focusApps.count) { refresh() }
        .onChange(of: exportOptions) { updateEstimatedExportSize() }
        .sheet(isPresented: $showingSessionList) {
            SessionListView(initialFilter: sheetInitialFilter, initialSort: sheetInitialSort)
                .frame(minWidth: 600, minHeight: 560)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                options: $exportOptions,
                onExport: {
                    dataExportService.exportDataToFile(options: exportOptions)
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
                    Text("Successfully imported \(summary.sessionsImported.formatted()) sessions, \(summary.focusAppsImported.formatted()) apps. \(summary.duplicatesSkipped.formatted()) duplicates skipped.")
                case .failure(let error):
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section("Overview") {
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    StatTile(
                        title: "Sessions",
                        systemImage: "clock.fill",
                        tint: .blue,
                        value: dataMetrics.totalSessions.formatted()
                    )
                    StatTile(
                        title: "Focus Time",
                        systemImage: "brain.head.profile.fill",
                        tint: .purple,
                        value: TimeFormatter.duration(Int(dataMetrics.totalFocusTime / 60))
                    )
                }
                GridRow {
                    StatTile(
                        title: "This Week",
                        systemImage: "calendar",
                        tint: .green,
                        value: dataMetrics.thisWeekSessions.formatted(),
                        detail: "sessions"
                    )
                    StatTile(
                        title: "This Month",
                        systemImage: "calendar.badge.clock",
                        tint: .orange,
                        value: dataMetrics.thisMonthSessions.formatted(),
                        detail: "sessions"
                    )
                }
            }
            .padding(.vertical, 4)

            LabeledContent("Focus Apps", value: dataMetrics.totalFocusApps.formatted())

            LabeledContent("Data Range") {
                if let oldest = dataMetrics.oldestSession, let newest = dataMetrics.newestSession {
                    Text("\(oldest.startTime.formatted(date: .abbreviated, time: .omitted)) – \(newest.startTime.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("No sessions recorded")
                }
            }
        }
    }

    private var sessionsSection: some View {
        Section {
            if let shortest = dataMetrics.shortestSession {
                LabeledContent("Shortest Session") {
                    Text(TimeFormatter.duration(Int(shortest.duration / 60)))
                        .foregroundStyle(shortest.duration < 60 ? Color.orange : Color.secondary)
                        .monospacedDigit()
                }
            }

            if let longest = dataMetrics.longestSession {
                LabeledContent("Longest Session") {
                    Text(TimeFormatter.duration(Int(longest.duration / 60)))
                        .monospacedDigit()
                }
            }

            if dataMetrics.veryShortSessions > 0 {
                LabeledContent {
                    Button("Review & Clean Up…") {
                        sheetInitialFilter = .veryShort
                        sheetInitialSort = .oldest
                        showingSessionList = true
                    }
                } label: {
                    Label(
                        "\(dataMetrics.veryShortSessions.formatted()) session\(dataMetrics.veryShortSessions == 1 ? "" : "s") under 1 minute",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .labelStyle(TintedIconLabelStyle(tint: .orange))
                }
            }

            HStack {
                Spacer()
                Button("Manage Sessions…") {
                    sheetInitialFilter = .all
                    sheetInitialSort = .newest
                    showingSessionList = true
                }
                .disabled(dataMetrics.totalSessions == 0)
            }
        } header: {
            Text("Sessions")
        } footer: {
            Text("View and manage your focus sessions. Remove unwanted sessions if needed.")
                .foregroundStyle(.secondary)
        }
    }

    private var exportImportSection: some View {
        Section {
            LabeledContent("Estimated Export Size", value: estimatedExportSize)

            HStack {
                Spacer()
                Button("Customize Export…") {
                    showingExportOptions = true
                }
                Button("Import…") {
                    dataExportService.importDataFromFile { result in
                        importResult = result
                        showingImportAlert = true
                    }
                }
                Button("Export…") {
                    dataExportService.exportDataToFile(options: exportOptions)
                }
                .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Export & Import")
        } footer: {
            Text("Export your sessions, focus apps and settings to JSON for backup or transfer to another device, or import data exported from another device.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func refresh() {
        dataMetrics = DataMetrics(focusManager: focusManager)
        updateEstimatedExportSize()
    }

    private func updateEstimatedExportSize() {
        let options = exportOptions
        let sessions = options.includeSessions ? filterSessions(by: options.dateRange) : []
        let apps = options.includeFocusApps ? focusManager.focusApps : []
        estimatedExportSize = estimateFileSize(sessions: sessions, apps: apps, includeSettings: options.includeSettings)
    }

    private func filterSessions(by dateRange: DateRange?) -> [FocusSession] {
        guard let range = dateRange else { return focusManager.focusSessions }

        return focusManager.focusSessions.filter { session in
            session.startTime >= range.startDate && session.endTime <= range.endDate
        }
    }

    private func estimateFileSize(sessions: [FocusSession], apps: [AppInfo], includeSettings: Bool) -> String {
        // Rough estimation: each session ~150 bytes, each app ~100 bytes, settings ~50 bytes
        let sessionSize = sessions.count * 150
        let appSize = apps.count * 100
        let settingsSize = includeSettings ? 50 : 0
        let metadataSize = 200

        let totalBytes = sessionSize + appSize + settingsSize + metadataSize
        return "~" + Int64(totalBytes).formatted(.byteCount(style: .file))
    }
}

// MARK: - Supporting Models

/// Session statistics for the Data tab, computed once per session change
/// instead of on every render.
struct DataMetrics {
    let totalSessions: Int
    let totalFocusTime: TimeInterval
    let totalFocusApps: Int
    let oldestSession: FocusSession?
    let newestSession: FocusSession?
    let shortestSession: FocusSession?
    let longestSession: FocusSession?
    let veryShortSessions: Int
    let thisWeekSessions: Int
    let thisMonthSessions: Int

    static let empty = DataMetrics(
        totalSessions: 0,
        totalFocusTime: 0,
        totalFocusApps: 0,
        oldestSession: nil,
        newestSession: nil,
        shortestSession: nil,
        longestSession: nil,
        veryShortSessions: 0,
        thisWeekSessions: 0,
        thisMonthSessions: 0
    )
}

extension DataMetrics {
    init(focusManager: FocusManager) {
        let sessions = focusManager.focusSessions
        self.init(
            totalSessions: sessions.count,
            totalFocusTime: sessions.reduce(0) { $0 + $1.duration },
            totalFocusApps: focusManager.focusApps.count,
            oldestSession: sessions.min { $0.startTime < $1.startTime },
            newestSession: sessions.max { $0.startTime < $1.startTime },
            shortestSession: sessions.min { $0.duration < $1.duration },
            longestSession: sessions.max { $0.duration < $1.duration },
            veryShortSessions: sessions.filter { $0.duration < 60 }.count,
            thisWeekSessions: focusManager.weekSessions.count,
            thisMonthSessions: focusManager.monthSessions.count
        )
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    @Binding var options: ExportOptions
    let onExport: () -> Void
    let onCancel: () -> Void
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var useDateRange = false

    private var hasNothingSelected: Bool {
        !options.includeSessions && !options.includeSettings && !options.includeFocusApps
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Export Options")
                .font(.headline)
                .padding(.top)

            Form {
                Section {
                    Toggle("Focus sessions", isOn: $options.includeSessions)
                    Toggle("Focus apps configuration", isOn: $options.includeFocusApps)
                    Toggle("Settings and preferences", isOn: $options.includeSettings)
                } header: {
                    Text("Include")
                }

                Section {
                    Toggle("Limit to date range", isOn: $useDateRange)
                    if useDateRange {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Date Range")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
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
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(hasNothingSelected)
            }
            .padding()
        }
        .frame(width: 420)
    }
}

#Preview {
    DataView(selectedTab: .constant(3))
        .environmentObject(FocusManager.shared)
        .environmentObject(LicenseManager())
        .frame(width: 600, height: 800)
}
