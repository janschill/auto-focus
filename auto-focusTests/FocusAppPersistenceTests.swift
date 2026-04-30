@testable import auto_focus
import GRDB
import XCTest

#if DEBUG

final class FocusAppPersistenceTests: XCTestCase {
    var dbQueue: DatabaseQueue!
    var repo: FocusAppRepository!

    override func setUp() {
        super.setUp()
        dbQueue = MockFactory.createTestDB()
        repo = FocusAppRepository(dbQueue: dbQueue)
    }

    func testSaveDoesNotWipeExistingAppsWhenInputContainsThem() throws {
        let cursor = AppInfo(id: "1", name: "Cursor", bundleIdentifier: "com.todesktop.cursor")
        let xcode = AppInfo(id: "2", name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
        try repo.insert(cursor)
        try repo.insert(xcode)

        try repo.save([cursor, xcode])

        let after = try repo.fetchAll()
        XCTAssertEqual(after.count, 2)
        XCTAssertEqual(Set(after.map(\.id)), ["1", "2"])
    }

    func testSaveRemovesOnlyMissingApps() throws {
        let cursor = AppInfo(id: "1", name: "Cursor", bundleIdentifier: "com.todesktop.cursor")
        let xcode = AppInfo(id: "2", name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
        let iterm = AppInfo(id: "3", name: "iTerm2", bundleIdentifier: "com.googlecode.iterm2")
        try repo.insert(cursor)
        try repo.insert(xcode)
        try repo.insert(iterm)

        try repo.save([cursor, iterm])

        let after = try repo.fetchAll()
        XCTAssertEqual(Set(after.map(\.id)), ["1", "3"])
    }

    func testSaveEmptyArrayClearsTable() throws {
        // Edge case: when the user genuinely deletes all focus apps, save([]) must clear.
        // Protection against accidental empty-save lives in FocusManager (didSet guard),
        // not in the repository.
        let cursor = AppInfo(id: "1", name: "Cursor", bundleIdentifier: "com.todesktop.cursor")
        try repo.insert(cursor)

        try repo.save([])

        let after = try repo.fetchAll()
        XCTAssertEqual(after.count, 0)
    }

    func testSaveUpdatesExistingAppName() throws {
        let original = AppInfo(id: "1", name: "Cursor", bundleIdentifier: "com.todesktop.cursor")
        try repo.insert(original)

        let renamed = AppInfo(id: "1", name: "Cursor (renamed)", bundleIdentifier: "com.todesktop.cursor")
        try repo.save([renamed])

        let after = try repo.fetchAll()
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.name, "Cursor (renamed)")
    }
}

#endif
