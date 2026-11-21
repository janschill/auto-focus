// ClaudeAnalysisPromptTests.swift
// Tests for the Claude session analysis prompt builder

@testable import auto_focus
import XCTest

#if DEBUG

final class ClaudeAnalysisPromptTests: XCTestCase {

    func testMakePrependsDatabasePathBeforeTemplate() {
        let prompt = ClaudeAnalysisPrompt.make(
            template: "## Rules\nbody",
            databasePath: "/Users/me/Library/Application Support/auto-focus.auto-focus/autofocus.sqlite"
        )

        XCTAssertTrue(prompt.hasPrefix("Auto-Focus filled this in for you: my database is at `/Users/me/Library/Application Support/auto-focus.auto-focus/autofocus.sqlite`."))
        XCTAssertTrue(prompt.hasSuffix("## Rules\nbody"))
    }

    func testLoadReadsBundledTemplate() throws {
        let databaseURL = URL(fileURLWithPath: "/tmp/test.sqlite")

        let prompt = try XCTUnwrap(ClaudeAnalysisPrompt.load(databaseURL: databaseURL))

        XCTAssertTrue(prompt.contains("`/tmp/test.sqlite`"))
        XCTAssertTrue(prompt.contains("sqlite3 -readonly"))
        XCTAssertTrue(prompt.contains("never select the `url` column"))
    }

    func testLoadReturnsNilWhenTemplateMissing() {
        let emptyBundle = Bundle(for: ClaudeAnalysisPromptTests.self)

        XCTAssertNil(ClaudeAnalysisPrompt.load(bundle: emptyBundle, databaseURL: URL(fileURLWithPath: "/tmp/x.sqlite")))
    }
}

#endif
