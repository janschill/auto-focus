import Foundation

public enum PremiumGating {
    /// Free tier defaults (matches the old “3 apps / 3 urls” spirit, but unified into one list).
    public static let freeMaxFocusEntities = 3
    public static let freeInsightsDepthDays = 7

    public static func entitlements(for state: LicenseState) -> PremiumEntitlements {
        switch state {
        case .licensed:
            return PremiumEntitlements(maxFocusEntities: -1, exportEnabled: true, insightsDepthDays: -1)
        case .unlicensed, .offline, .validationFailed, .unknown:
            return PremiumEntitlements(maxFocusEntities: freeMaxFocusEntities, exportEnabled: false, insightsDepthDays: freeInsightsDepthDays)
        }
    }

    public static func canAddFocusEntity(currentCount: Int, licenseState: LicenseState) -> Bool {
        let max = entitlements(for: licenseState).maxFocusEntities
        if max < 0 { return true }
        return currentCount < max
    }
}


