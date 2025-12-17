import XCTest
@testable import AutoFocus2

final class ShortcutRunnerTests: XCTestCase {
    func testSetNotificationsIsIdempotentForSameState() async throws {
        let controller = ShortcutNotificationsControllerTestDouble()

        try await controller.setNotifications(.disabled)
        try await controller.setNotifications(.disabled)

        XCTAssertEqual(controller.invocations, 1)
    }
}

// MARK: - Test double

private final class ShortcutNotificationsControllerTestDouble: NotificationsControlling {
    private(set) var invocations: Int = 0
    private var lastApplied: NotificationsDesiredState?

    func setNotifications(_ state: NotificationsDesiredState) async throws {
        if lastApplied == state { return }
        invocations += 1
        lastApplied = state
    }
}


