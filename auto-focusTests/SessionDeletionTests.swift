@testable import auto_focus
import GRDB
import XCTest

#if DEBUG

final class SessionDeletionTests: XCTestCase {
    var sessionRepo: SessionRepository!
    var sessionManager: SessionManager!

    override func setUp() {
        super.setUp()
        let testDB = MockFactory.createTestDB()
        sessionRepo = SessionRepository(dbQueue: testDB)
        sessionManager = SessionManager(sessionRepo: sessionRepo)
    }

    func testDeleteSessionsRemovesMatchingSessions() throws {
        let now = Date()
        let s1 = FocusSession(startTime: now.addingTimeInterval(-300), endTime: now.addingTimeInterval(-290))
        let s2 = FocusSession(startTime: now.addingTimeInterval(-200), endTime: now.addingTimeInterval(-100))
        let s3 = FocusSession(startTime: now.addingTimeInterval(-90), endTime: now)

        try sessionRepo.insert(s1)
        try sessionRepo.insert(s2)
        try sessionRepo.insert(s3)

        sessionManager.deleteSessions([s1, s3])

        // Allow the observation publisher to deliver before reading
        let exp = expectation(description: "observation delivers")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        let remaining = try sessionRepo.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, s2.id)
    }

    func testDeleteSessionsWithEmptyArrayIsNoOp() throws {
        let now = Date()
        let s1 = FocusSession(startTime: now.addingTimeInterval(-100), endTime: now)
        try sessionRepo.insert(s1)

        sessionManager.deleteSessions([])

        let remaining = try sessionRepo.fetchAll()
        XCTAssertEqual(remaining.count, 1)
    }
}

#endif
