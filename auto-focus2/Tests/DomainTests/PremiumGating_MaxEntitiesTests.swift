import XCTest
@testable import AutoFocus2

final class PremiumGating_MaxEntitiesTests: XCTestCase {
    func testUnlicensedHasFreeLimit() {
        XCTAssertEqual(PremiumGating.entitlements(for: .unlicensed).maxFocusEntities, PremiumGating.freeMaxFocusEntities)
        XCTAssertFalse(PremiumGating.entitlements(for: .unlicensed).exportEnabled)
    }

    func testLicensedIsUnlimited() {
        XCTAssertEqual(PremiumGating.entitlements(for: .licensed).maxFocusEntities, -1)
        XCTAssertTrue(PremiumGating.entitlements(for: .licensed).exportEnabled)
    }

    func testCanAddFocusEntityRespectsFreeLimit() {
        let max = PremiumGating.freeMaxFocusEntities
        XCTAssertTrue(PremiumGating.canAddFocusEntity(currentCount: max - 1, licenseState: .unlicensed))
        XCTAssertFalse(PremiumGating.canAddFocusEntity(currentCount: max, licenseState: .unlicensed))
    }
}


