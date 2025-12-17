import Foundation
import ServiceManagement

protocol LaunchOnLoginServicing: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

final class LaunchOnLoginService: LaunchOnLoginServicing {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}


