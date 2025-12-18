import Foundation

enum PermissionState: Equatable {
    case unknown
    case granted
    case notGranted(reason: String)
}

struct SystemPrerequisitesStatus: Equatable {
    var systemEventsAutomation: PermissionState = .unknown
    var shortcutsAutomation: PermissionState = .unknown
    var safariAutomation: PermissionState = .unknown
    var chromeAutomation: PermissionState = .unknown

    var shortcutInstalled: Bool? = nil
    var shortcutName: String = "Toggle Do Not Disturb"

    var requirementsSatisfied: Bool {
        systemEventsAutomation == .granted && shortcutsAutomation == .granted
    }
}


