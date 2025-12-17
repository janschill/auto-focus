import XCTest
@testable import AutoFocus2

final class OnboardingFlowTests: XCTestCase {
    func testStartsAtPermissions() {
        let state = OnboardingState()
        XCTAssertEqual(state.step, .permissions)
    }

    func testCannotAdvanceWithoutPermissions() {
        var state = OnboardingState(step: .permissions, hasPermissions: false, hasShortcutConfigured: false, hasCompletedConfiguration: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .permissions)
    }

    func testPermissionsGrantedAdvancesToShortcut() {
        var state = OnboardingState()
        state = OnboardingFlow.reduce(state, event: .permissionsGranted(true))
        XCTAssertEqual(state.step, .shortcut)
    }

    func testShortcutConfiguredAdvancesToLicense() {
        var state = OnboardingState()
        state = OnboardingFlow.reduce(state, event: .permissionsGranted(true))
        state = OnboardingFlow.reduce(state, event: .shortcutConfigured(true))
        XCTAssertEqual(state.step, .license)
    }

    func testNextFromLicenseGoesToConfiguration() {
        var state = OnboardingState(step: .license, hasPermissions: true, hasShortcutConfigured: true, hasCompletedConfiguration: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .configuration)
    }

    func testConfigurationCompletedEnds() {
        var state = OnboardingState(step: .configuration, hasPermissions: true, hasShortcutConfigured: true, hasCompletedConfiguration: false)
        state = OnboardingFlow.reduce(state, event: .configurationCompleted(true))
        XCTAssertEqual(state.step, .done)
    }
}


