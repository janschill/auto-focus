import Foundation
import GRDB
import XCTest
@testable import auto_focus

#if DEBUG

final class AppEventRepositoryTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var repo: AppEventRepository!

    override func setUp() {
        super.setUp()
        dbQueue = MockFactory.createTestDB()
        repo = AppEventRepository(dbQueue: dbQueue)
    }

    // MARK: - extractDomain

    func testExtractDomainFromFullURL() {
        XCTAssertEqual(AppEvent.extractDomain(from: "https://github.com/user/repo"), "github.com")
    }

    func testExtractDomainFromHTTP() {
        XCTAssertEqual(AppEvent.extractDomain(from: "http://example.com/page"), "example.com")
    }

    func testExtractDomainFromURLWithPort() {
        XCTAssertEqual(AppEvent.extractDomain(from: "http://localhost:3000/path"), "localhost")
    }

    func testExtractDomainFromSubdomain() {
        XCTAssertEqual(AppEvent.extractDomain(from: "https://docs.google.com/spreadsheets"), "docs.google.com")
    }

    func testExtractDomainFromBareHost() {
        XCTAssertEqual(AppEvent.extractDomain(from: "example.com/page"), "example.com")
    }

    func testExtractDomainReturnsNilForGarbage() {
        XCTAssertNil(AppEvent.extractDomain(from: ""))
    }

    func testExtractDomainLowercase() {
        XCTAssertEqual(AppEvent.extractDomain(from: "https://GitHub.COM/user"), "github.com")
    }

    // MARK: - Browser event persistence

    func testInsertBrowserEventPersistsDomainAndURL() throws {
        let event = AppEvent(
            bundleIdentifier: "com.google.Chrome",
            appName: "GitHub",
            url: "https://github.com/pulls",
            domain: "github.com"
        )
        try repo.insert(event)

        let fetched = try repo.fetchRecent(limit: 1)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].domain, "github.com")
        XCTAssertEqual(fetched[0].url, "https://github.com/pulls")
        XCTAssertEqual(fetched[0].eventType, "tab_changed")
    }

    func testAppEventHasNilDomainAndURL() throws {
        let event = AppEvent(bundleIdentifier: "com.apple.Xcode", appName: "Xcode")
        try repo.insert(event)

        let fetched = try repo.fetchRecent(limit: 1)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched[0].domain)
        XCTAssertNil(fetched[0].url)
        XCTAssertEqual(fetched[0].eventType, "activate")
    }

    // MARK: - fetchTopApps

    func testFetchTopAppsComputesDurations() throws {
        let base = Date()
        // Xcode active for 100s, then Safari for 50s, then Xcode for 200s
        try insertEvent(bundleId: "com.apple.Xcode", appName: "Xcode", at: base)
        try insertEvent(bundleId: "com.apple.Safari", appName: "Safari", at: base.addingTimeInterval(100))
        try insertEvent(bundleId: "com.apple.Xcode", appName: "Xcode", at: base.addingTimeInterval(150))
        try insertEvent(bundleId: "com.apple.Terminal", appName: "Terminal", at: base.addingTimeInterval(350))

        let results = try repo.fetchTopApps(since: base.addingTimeInterval(-1))
        XCTAssertFalse(results.isEmpty)

        let xcodeResult = results.first(where: { $0.bundleIdentifier == "com.apple.Xcode" })
        XCTAssertNotNil(xcodeResult)
        XCTAssertEqual(xcodeResult!.totalDuration, 300, accuracy: 1.0)

        let safariResult = results.first(where: { $0.bundleIdentifier == "com.apple.Safari" })
        XCTAssertNotNil(safariResult)
        XCTAssertEqual(safariResult!.totalDuration, 50, accuracy: 1.0)
    }

    // MARK: - fetchTopDomains

    func testFetchTopDomainsGroupsByDomain() throws {
        let base = Date()
        try insertBrowserEvent(domain: "github.com", url: "https://github.com/pulls", at: base)
        try insertBrowserEvent(domain: "stackoverflow.com", url: "https://stackoverflow.com/q/1", at: base.addingTimeInterval(60))
        try insertBrowserEvent(domain: "github.com", url: "https://github.com/issues", at: base.addingTimeInterval(90))
        // End marker
        try insertEvent(bundleId: "com.apple.Xcode", appName: "Xcode", at: base.addingTimeInterval(190))

        let results = try repo.fetchTopDomains(since: base.addingTimeInterval(-1))
        XCTAssertFalse(results.isEmpty)

        let github = results.first(where: { $0.domain == "github.com" })
        XCTAssertNotNil(github)
        // 60s (first visit) + 100s (second visit) = 160s
        XCTAssertEqual(github!.totalDuration, 160, accuracy: 1.0)
        XCTAssertEqual(github!.visitCount, 2)

        let so = results.first(where: { $0.domain == "stackoverflow.com" })
        XCTAssertNotNil(so)
        XCTAssertEqual(so!.totalDuration, 30, accuracy: 1.0)
    }

    // MARK: - deleteEvents

    func testDeleteEventsBeforeDate() throws {
        let old = Date().addingTimeInterval(-7200)
        let recent = Date()

        try insertEvent(bundleId: "com.old.app", appName: "Old", at: old)
        try insertEvent(bundleId: "com.new.app", appName: "New", at: recent)

        let cutoff = Date().addingTimeInterval(-3600)
        try repo.deleteEvents(before: cutoff)

        let remaining = try repo.fetchRecent(limit: 100)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].bundleIdentifier, "com.new.app")
    }

    // MARK: - Helpers

    private func insertEvent(bundleId: String, appName: String, at date: Date) throws {
        var event = AppEvent(bundleIdentifier: bundleId, appName: appName)
        event.timestamp = date
        try repo.insert(event)
    }

    private func insertBrowserEvent(domain: String, url: String, at date: Date) throws {
        var event = AppEvent(bundleIdentifier: "com.google.Chrome", appName: nil, url: url, domain: domain)
        event.timestamp = date
        try repo.insert(event)
    }
}

#endif
