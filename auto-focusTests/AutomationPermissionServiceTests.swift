import XCTest
@testable import auto_focus

#if DEBUG

final class AutomationPermissionServiceTests: XCTestCase {
    private var checker: MockAETargetPermissionChecker!
    private var service: AutomationPermissionService!

    override func setUp() {
        super.setUp()
        checker = MockAETargetPermissionChecker()
        service = AutomationPermissionService(checker: checker)
    }

    func testStatusMappingFromOSStatus() {
        XCTAssertEqual(BrowserPermissionStatus.from(osStatus: OSStatus(noErr)), .granted)
        XCTAssertEqual(BrowserPermissionStatus.from(osStatus: OSStatus(-1743)), .denied)
        XCTAssertEqual(BrowserPermissionStatus.from(osStatus: OSStatus(-1744)), .notDetermined)
        XCTAssertEqual(BrowserPermissionStatus.from(osStatus: OSStatus(-600)), .notInstalled)
        XCTAssertEqual(BrowserPermissionStatus.from(osStatus: OSStatus(-999)), .unknown)
    }

    func testRefreshAllRecordsGrantedStatuses() {
        checker.scriptedStatuses = [
            "com.apple.Safari": OSStatus(noErr),
            "com.google.Chrome": OSStatus(-1743)
        ]

        service.refreshAll(bundleIds: ["com.apple.Safari", "com.google.Chrome"])

        XCTAssertEqual(service.status(for: "com.apple.Safari"), .granted)
        XCTAssertEqual(service.status(for: "com.google.Chrome"), .denied)
    }

    func testRefreshAllDoesNotPrompt() {
        checker.scriptedStatuses = ["com.apple.Safari": OSStatus(noErr)]

        service.refreshAll(bundleIds: ["com.apple.Safari"])

        XCTAssertEqual(checker.callLog.count, 1)
        XCTAssertFalse(checker.callLog[0].askUserIfNeeded)
    }

    func testRequestPermissionPromptsAndPublishes() {
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(noErr)]

        let resolved = service.requestPermission(bundleId: "com.google.Chrome")

        XCTAssertEqual(resolved, .granted)
        XCTAssertEqual(service.status(for: "com.google.Chrome"), .granted)
        XCTAssertEqual(checker.callLog.last?.askUserIfNeeded, true)
    }

    func testRequestPermissionRecordsDenial() {
        checker.scriptedStatuses = ["com.google.Chrome": OSStatus(-1743)]

        let resolved = service.requestPermission(bundleId: "com.google.Chrome")

        XCTAssertEqual(resolved, .denied)
        XCTAssertEqual(service.status(for: "com.google.Chrome"), .denied)
    }

    func testStatusDefaultsToUnknown() {
        XCTAssertEqual(service.status(for: "com.unseen.browser"), .unknown)
    }
}

#endif
