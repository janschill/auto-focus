import AppKit
import Foundation

enum BrowserPermissionStatus: String, Codable, Equatable {
    case unknown
    case notDetermined
    case granted
    case denied
    case notInstalled

    static func from(osStatus: OSStatus) -> BrowserPermissionStatus {
        switch Int(osStatus) {
        case Int(noErr):
            return .granted
        case -1743: // errAEEventNotPermitted
            return .denied
        case -1744: // errAEEventWouldRequireUserConsent
            return .notDetermined
        case -600: // procNotFound
            return .notInstalled
        default:
            return .unknown
        }
    }
}

struct BrowserEnablement: Codable, Equatable {
    var isEnabled: Bool
    var lastPermissionStatus: BrowserPermissionStatus
}

struct BrowserDescriptor: Identifiable, Equatable {
    let bundleId: String
    let displayName: String
    let isInstalled: Bool

    var id: String { bundleId }
}
