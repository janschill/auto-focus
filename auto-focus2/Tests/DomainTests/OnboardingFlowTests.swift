import XCTest
@testable import AutoFocus2

final class OnboardingFlowTests: XCTestCase {
    func testStartsAtPermissions() {
        let state = OnboardingState()
        XCTAssertEqual(state.step, .permissions)
    }

    func testCannotAdvanceWithoutPermissions() {
        var state = OnboardingState(step: .permissions, hasPermissions: false, hasAddedApps: false, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .permissions)
    }

    func testPermissionsGrantedAdvancesToLicense() {
        var state = OnboardingState()
        state = OnboardingFlow.reduce(state, event: .permissionsGranted(true))
        XCTAssertEqual(state.step, .license)
    }

    func testNextFromLicenseGoesToApps() {
        var state = OnboardingState(step: .license, hasPermissions: true, hasAddedApps: false, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .apps)
    }

    func testAppsAddedAdvancesToDomains() {
        var state = OnboardingState(step: .apps, hasPermissions: true, hasAddedApps: false, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .appsAdded(true))
        XCTAssertEqual(state.step, .domains)
    }

    func testDomainsAddedEnds() {
        var state = OnboardingState(step: .domains, hasPermissions: true, hasAddedApps: true, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .domainsAdded(true))
        XCTAssertEqual(state.step, .done)
    }

    func testNextFromAppsGoesToDomainsEvenIfNoAppsAdded() {
        var state = OnboardingState(step: .apps, hasPermissions: true, hasAddedApps: false, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .domains)
    }

    func testNextFromDomainsGoesToDoneEvenIfNoDomainsAdded() {
        var state = OnboardingState(step: .domains, hasPermissions: true, hasAddedApps: true, hasAddedDomains: false)
        state = OnboardingFlow.reduce(state, event: .next)
        XCTAssertEqual(state.step, .done)
    }
}


