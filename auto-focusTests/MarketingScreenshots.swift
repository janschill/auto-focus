// MarketingScreenshots.swift
// Renders app views with fixed sample data into PNGs for the marketing website.
// Skipped unless AUTOFOCUS_SCREENSHOT_DIR is set; run `make screenshots` to render into build/screenshots.

import AppKit
@testable import auto_focus
import GRDB
import SwiftUI
import XCTest

#if DEBUG

final class MarketingScreenshots: XCTestCase {
    private var outputDirectory: URL!
    private var appMonitor: MockAppMonitor!
    private var sessionManager: MockSessionManager!
    private var browserManager: MockBrowserManager!
    private var focusManager: FocusManager!
    private var licenseManager: LicenseManager!
    private var appEventRepo: AppEventRepository!
    private var flowMonitor: FlowMonitor!

    private static let focusApps: [(name: String, bundleID: String)] = [
        ("Xcode", "com.apple.dt.Xcode"),
        ("Figma", "com.figma.Desktop"),
        ("Ghostty", "com.mitchellh.ghostty"),
        ("Obsidian", "md.obsidian"),
        ("Visual Studio Code", "com.microsoft.VSCode")
    ]

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["AUTOFOCUS_SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("Set AUTOFOCUS_SCREENSHOT_DIR to render marketing screenshots")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let testDB = MockFactory.createTestDB()
        let mocks = MockFactory.createMockDependencies()
        appMonitor = mocks.appMonitor
        sessionManager = mocks.sessionManager
        browserManager = mocks.browserManager
        appEventRepo = AppEventRepository(dbQueue: testDB)

        // A fresh instance whose license state is set in memory only; nothing is persisted.
        licenseManager = LicenseManager()
        applyLicensedState()

        let focusAppRepo = FocusAppRepository(dbQueue: testDB)
        for app in Self.focusApps {
            try focusAppRepo.insert(AppInfo(id: UUID().uuidString, name: app.name, bundleIdentifier: app.bundleID))
        }
        browserManager.focusURLs = [
            FocusURL(name: "GitHub", domain: "github.com", category: .development),
            FocusURL(name: "Linear", domain: "linear.app", category: .work),
            FocusURL(name: "Notion", domain: "notion.so", category: .work)
        ]

        focusManager = FocusManager(
            settingsRepo: SettingsRepository(dbQueue: testDB),
            focusAppRepo: focusAppRepo,
            sessionManager: sessionManager,
            appMonitor: appMonitor,
            bufferManager: mocks.bufferManager,
            focusModeController: mocks.focusModeManager,
            browserManager: browserManager,
            licenseManager: licenseManager
        )
        focusManager.hasCompletedOnboarding = true

        sessionManager.focusSessions = Self.sampleSessions()
        try seedAppEvents()

        let manager = focusManager!
        flowMonitor = FlowMonitor(appEventRepo: appEventRepo, focusContext: { manager.focusContext }, idleTime: { 0 })
        flowMonitor.refresh()
    }

    // MARK: - Screenshots

    func testMenuBarInFocus() throws {
        appMonitor.simulateAppSwitch(to: "com.apple.dt.Xcode", isFocusApp: true)
        focusManager.isInFocusMode = true
        focusManager.isShortcutInstalled = true

        let view = MenuBarView()
            .environmentObject(focusManager)
            .environmentObject(flowMonitor)
            .background(Color(nsColor: .windowBackgroundColor))
        // The focus timer overwrites timeSpent on each tick, so set it right before capture.
        try render(view, size: CGSize(width: 290, height: 0), name: "menubar-in-focus") { [focusManager] in
            focusManager?.timeSpent = 47 * 60
        }
    }

    func testConfiguration() throws {
        let view = ConfigurationView(selectedTab: .constant(0))
            .environmentObject(focusManager)
            .environmentObject(licenseManager)
        // Taller than the window so the focus app list is fully visible.
        try render(view, size: CGSize(width: 600, height: 1_020), name: "configuration")
    }

    func testInsightsSummary() throws {
        try renderInsights(.summary, name: "insights-summary")
    }

    func testInsightsActivity() throws {
        try renderInsights(.activity, name: "insights-activity")
    }

    func testInsightsFocusQuality() throws {
        try renderInsights(.focusQuality, name: "insights-focus-quality")
    }

    private func renderInsights(_ tab: InsightsSubTab, name: String) throws {
        let viewModel = InsightsViewModel(dataProvider: InsightsDataProvider(focusManager: focusManager, appEventRepo: appEventRepo))
        viewModel.selectedTimeframe = .week
        let view = InsightsPaneScreenshot(tab: tab, viewModel: viewModel)
            .environmentObject(focusManager)
            .environmentObject(licenseManager)
            .background(Color(nsColor: .windowBackgroundColor))
        try render(view, size: CGSize(width: 600, height: 0), name: name)
    }

    /// Startup validation of a stored key may finish later, so this is reapplied before each capture.
    private func applyLicensedState() {
        licenseManager.isLicensed = true
        licenseManager.licenseStatus = .valid
        licenseManager.maxAppsAllowed = AppConfiguration.unlimited
    }

    // MARK: - Sample Data

    /// Deterministic sessions over the last five weeks, heavier on weekdays and mornings.
    private static func sampleSessions() -> [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var generator = SeededGenerator(seed: 42)
        var sessions: [FocusSession] = []

        for dayOffset in 0..<35 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            let count = isWeekend ? Int.random(in: 0...2, using: &generator) : Int.random(in: 3...6, using: &generator)
            var hour = 8
            for _ in 0..<count {
                let startMinute = Int.random(in: 0...45, using: &generator)
                let length = TimeInterval(Int.random(in: 22...95, using: &generator) * 60)
                guard let start = calendar.date(bySettingHour: hour, minute: startMinute, second: 0, of: day) else { continue }
                let end = start.addingTimeInterval(length)
                // Today only includes sessions that already ended.
                if end < Date() {
                    sessions.append(FocusSession(startTime: start, endTime: end))
                }
                hour += Int.random(in: 1...3, using: &generator)
                if hour > 20 { break }
            }
        }
        return sessions
    }

    /// App activations for today and the past week, including the last ten minutes for the flow reading.
    private func seedAppEvents() throws {
        let calendar = Calendar.current
        var generator = SeededGenerator(seed: 7)
        let workApps = Self.focusApps.map(\.bundleID)
        let distractions = [("Slack", "com.tinyspeck.slackmacgap"), ("Mail", "com.apple.mail"), ("Messages", "com.apple.MobileSMS")]
        let now = Date()

        for dayOffset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)),
                  var cursor = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day) else { continue }
            let dayEnd = min(calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) ?? now, now.addingTimeInterval(-15 * 60))
            while cursor < dayEnd {
                let roll = Int.random(in: 0..<10, using: &generator)
                var event: AppEvent
                if roll < 5 {
                    let bundleID = workApps[Int.random(in: 0..<workApps.count, using: &generator)]
                    event = AppEvent(bundleIdentifier: bundleID, appName: Self.focusApps.first { $0.bundleID == bundleID }?.name)
                } else if roll < 7 {
                    let domain = ["github.com", "linear.app", "notion.so"][Int.random(in: 0..<3, using: &generator)]
                    event = AppEvent(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: "https://\(domain)/", domain: domain)
                } else {
                    let app = distractions[Int.random(in: 0..<distractions.count, using: &generator)]
                    event = AppEvent(bundleIdentifier: app.1, appName: app.0)
                }
                event.timestamp = cursor
                try appEventRepo.insert(event)
                cursor = cursor.addingTimeInterval(TimeInterval(Int.random(in: 4...28, using: &generator) * 60))
            }
        }

        // A calm last ten minutes between Xcode and GitHub reads as flow.
        let recentEvents: [(minutesAgo: Double, event: AppEvent)] = [
            (14, AppEvent(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode")),
            (7, AppEvent(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: "https://github.com/", domain: "github.com")),
            (5, AppEvent(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode"))
        ]
        for var recent in recentEvents {
            recent.event.timestamp = now.addingTimeInterval(-recent.minutesAgo * 60)
            try appEventRepo.insert(recent.event)
        }
    }

    // MARK: - Rendering

    /// Lays out the view in an offscreen window at 2x in light mode and writes it as a PNG.
    /// A zero height sizes the view to fit its content once its data has loaded.
    private func render<Content: View>(
        _ view: Content,
        size: CGSize,
        name: String,
        beforeCapture: () -> Void = {}
    ) throws {
        let hostingView = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        let initialHeight = size.height > 0 ? size.height : 4_000
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: size.width, height: initialHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hostingView

        // Let SwiftUI finish onAppear work and async layout before capturing.
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        applyLicensedState()
        beforeCapture()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        if size.height == 0 {
            let height = hostingView.fittingSize.height
            window.setContentSize(NSSize(width: size.width, height: height))
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        hostingView.layoutSubtreeIfNeeded()

        let bounds = hostingView.bounds
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width * scale),
            pixelsHigh: Int(bounds.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            XCTFail("Could not allocate bitmap for \(name)")
            return
        }
        bitmap.size = bounds.size
        hostingView.cacheDisplay(in: bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode \(name)")
            return
        }
        try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }
}

/// The licensed Insights layout: the sub-tab picker above one pane, without the scroll view.
private struct InsightsPaneScreenshot: View {
    let tab: InsightsSubTab
    @ObservedObject var viewModel: InsightsViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: .constant(tab)) {
                ForEach(InsightsSubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            VStack(spacing: 10) {
                switch tab {
                case .summary: InsightsSummaryPane(dataProvider: viewModel)
                case .activity: InsightsActivityPane(dataProvider: viewModel)
                case .focusQuality: InsightsFocusQualityPane(dataProvider: viewModel)
                }
            }
            .padding()
        }
        .onAppear { viewModel.startObserving() }
    }
}

/// Small deterministic generator so every render shows the same sample data.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

#endif
