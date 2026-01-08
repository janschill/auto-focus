import AppKit
import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    // Inputs
    @Published var activationMinutes: Int = 12
    @Published var bufferSeconds: Int = 30

    @Published var newDomainValue: String = ""

    // State
    @Published private(set) var focusEntities: [FocusEntity] = []
    @Published private(set) var lastError: String?

    // License
    @Published var licenseKey: String = ""

    // Launch on login
    @Published var launchOnLoginEnabled: Bool = false

    // System prerequisites / permissions
    @Published private(set) var prerequisites: SystemPrerequisitesStatus = SystemPrerequisitesStatus()
    @Published private(set) var isCheckingPrerequisites: Bool = false

    private let settingsStore: FocusSettingsStoring
    private let entityStore: FocusEntityStoring
    private let launchOnLogin: LaunchOnLoginServicing
    private let notificationsController: NotificationsControlling
    let licenseService: LicenseService

    private let permissionProbe = AppleEventsPermissionProbe()
    private let shortcutsCLI = ShortcutsCLI()

    init(root: CompositionRoot) {
        self.settingsStore = root.settingsStore
        self.entityStore = root.entityStore
        self.launchOnLogin = root.launchOnLoginService
        self.notificationsController = root.notificationsController
        self.licenseService = root.licenseService

        reload()
    }

    var focusApps: [FocusEntity] {
        focusEntities.filter { $0.type == .app }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var focusDomains: [FocusEntity] {
        focusEntities.filter { $0.type == .domain }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func reload() {
        do {
            let settings = try settingsStore.load()
            activationMinutes = settings.activationMinutes
            bufferSeconds = settings.bufferSeconds
            focusEntities = try entityStore.list()
            licenseKey = licenseService.currentLicenseKey()
            launchOnLoginEnabled = launchOnLogin.isEnabled
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    func refreshPrerequisitesSilently() {
        var next = prerequisites
        next.systemEventsAutomation = permissionProbe.checkSilently(.systemEvents)
        next.shortcutsAutomation = permissionProbe.checkSilently(.shortcutsEvents)
        next.safariAutomation = permissionProbe.checkSilently(.safari)
        next.chromeAutomation = permissionProbe.checkSilently(.chrome)
        next.shortcutInstalled = shortcutsCLI.isShortcutInstalled(named: next.shortcutName)
        prerequisites = next
    }

    func requestAutomationPermissions() async {
        if isCheckingPrerequisites { return }
        isCheckingPrerequisites = true
        defer { isCheckingPrerequisites = false }

        var next = prerequisites
        next.systemEventsAutomation = await permissionProbe.requestPrompt(.systemEvents)
        next.shortcutsAutomation = await permissionProbe.requestPrompt(.shortcutsEvents)
        // Browser permissions are optional, but we probe so status is visible.
        next.safariAutomation = permissionProbe.checkSilently(.safari)
        next.chromeAutomation = permissionProbe.checkSilently(.chrome)
        next.shortcutInstalled = shortcutsCLI.isShortcutInstalled(named: next.shortcutName)
        prerequisites = next
    }

    /// Runs the configured shortcut twice (toggle + toggle back) so the net effect should be no change.
    /// This is best-effort and still depends on the user's Shortcut behavior.
    func testShortcutRoundTrip() async throws {
        try await notificationsController.setNotifications(.disabled)
        try await notificationsController.setNotifications(.enabled)
    }

    func saveTimers() {
        do {
            try settingsStore.save(FocusSettings(activationMinutes: activationMinutes, bufferSeconds: bufferSeconds))
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    func addDomain() {
        let value = newDomainValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return }

        let entity = FocusEntity(type: .domain, displayName: value, matchValue: value)
        do {
            try entityStore.upsert(entity)
            newDomainValue = ""
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addApp(from bundleURL: URL) {
        guard let bundle = Bundle(url: bundleURL),
              let bundleId = bundle.bundleIdentifier,
              !bundleId.isEmpty
        else {
            lastError = "Could not read app bundle identifier."
            return
        }

        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent

        let entity = FocusEntity(type: .app, displayName: name, matchValue: bundleId)
        do {
            try entityStore.upsert(entity)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func presentAppPickerAndAdd() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Add App"

        if panel.runModal() == .OK, let url = panel.url {
            addApp(from: url)
        }
    }

    func deleteEntity(_ entity: FocusEntity) {
        do {
            try entityStore.delete(id: entity.id)
            reload()
        } catch {
            lastError = String(describing: error)
        }
    }

    func toggleLaunchOnLogin(_ enabled: Bool) {
        do {
            try launchOnLogin.setEnabled(enabled)
            launchOnLoginEnabled = launchOnLogin.isEnabled
            lastError = nil
        } catch {
            lastError = String(describing: error)
            launchOnLoginEnabled = launchOnLogin.isEnabled
        }
    }

    func saveLicenseKey() {
        licenseService.setLicenseKey(licenseKey)
    }
}


