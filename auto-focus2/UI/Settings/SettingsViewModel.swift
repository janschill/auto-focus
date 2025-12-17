import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    // Inputs
    @Published var activationMinutes: Int = 12
    @Published var bufferSeconds: Int = 30

    @Published var newDomainName: String = ""
    @Published var newDomainValue: String = ""

    @Published var newAppName: String = ""
    @Published var newAppBundleId: String = ""

    // State
    @Published private(set) var focusEntities: [FocusEntity] = []
    @Published private(set) var lastError: String?

    // License
    @Published var licenseKey: String = ""

    // Launch on login
    @Published var launchOnLoginEnabled: Bool = false

    private let settingsStore: FocusSettingsStoring
    private let entityStore: FocusEntityStoring
    private let launchOnLogin: LaunchOnLoginServicing
    let licenseService: LicenseService

    init(root: CompositionRoot) {
        self.settingsStore = root.settingsStore
        self.entityStore = root.entityStore
        self.launchOnLogin = root.launchOnLoginService
        self.licenseService = root.licenseService

        reload()
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

    func saveTimers() {
        do {
            try settingsStore.save(FocusSettings(activationMinutes: activationMinutes, bufferSeconds: bufferSeconds))
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    func addDomain() {
        let name = newDomainName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = newDomainValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, !value.isEmpty else { return }

        let entity = FocusEntity(type: .domain, displayName: name, matchValue: value)
        do {
            try entityStore.upsert(entity)
            newDomainName = ""
            newDomainValue = ""
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addApp() {
        let name = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleId = newAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !bundleId.isEmpty else { return }

        let entity = FocusEntity(type: .app, displayName: name, matchValue: bundleId)
        do {
            try entityStore.upsert(entity)
            newAppName = ""
            newAppBundleId = ""
            reload()
        } catch {
            lastError = error.localizedDescription
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


