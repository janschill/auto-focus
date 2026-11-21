@testable import auto_focus
import Foundation
import XCTest

#if DEBUG

final class UserSettingsCodingTests: XCTestCase {
    func testExportBeforeGlanceToleranceStillDecodes() throws {
        let json = #"{"focusThreshold": 12, "focusLossBuffer": 2, "hasCompletedOnboarding": true}"#

        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.focusThreshold, 12)
        XCTAssertNil(settings.glanceTolerance)
    }

    func testGlanceToleranceRoundTrips() throws {
        let original = UserSettings(focusThreshold: 6, glanceTolerance: 45, hasCompletedOnboarding: true)

        let decoded = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded.glanceTolerance, 45)
    }
}

#endif
