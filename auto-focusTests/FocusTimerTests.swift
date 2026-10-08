@testable import auto_focus
import XCTest

final class FocusTimerTests: XCTestCase {
    private var clock = Date(timeIntervalSinceReferenceDate: 0)
    private var timer: FocusTimer!

    override func setUp() {
        super.setUp()
        clock = Date(timeIntervalSinceReferenceDate: 0)
        timer = FocusTimer(interval: 1, now: { [unowned self] in self.clock })
    }

    override func tearDown() {
        timer.reset()
        timer = nil
        super.tearDown()
    }

    private func advance(_ seconds: TimeInterval) {
        clock = clock.addingTimeInterval(seconds)
    }

    func testMeasuresElapsedTimeFromClock() {
        timer.start()
        advance(7.5)

        XCTAssertEqual(timer.currentTime, 7.5)
        XCTAssertTrue(timer.isRunning)
    }

    func testPauseFreezesElapsedTime() {
        timer.start()
        advance(5)
        timer.pause()
        advance(30)

        XCTAssertEqual(timer.currentTime, 5)
        XCTAssertFalse(timer.isRunning)
    }

    func testStartPreservingTimeContinuesFromPause() {
        timer.start()
        advance(5)
        timer.pause()
        advance(30)
        timer.start(preserveTime: true)
        advance(2)

        XCTAssertEqual(timer.currentTime, 7)
    }

    func testRestartWhileRunningPreservesTime() {
        timer.start()
        advance(4)
        timer.start(preserveTime: true)
        advance(1)

        XCTAssertEqual(timer.currentTime, 5)
    }

    func testStartWithoutPreservingResets() {
        timer.start()
        advance(5)
        timer.start()
        advance(1)

        XCTAssertEqual(timer.currentTime, 1)
    }

    func testResetStopsAndClears() {
        timer.start()
        advance(5)
        timer.reset()
        advance(5)

        XCTAssertEqual(timer.currentTime, 0)
        XCTAssertFalse(timer.isRunning)
    }
}
