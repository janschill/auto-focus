import Foundation

public protocol Clocking: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clocking {
    public init() {}
    public var now: Date { Date() }
}

/// A controllable clock for deterministic tests.
public final class TestClock: Clocking, @unchecked Sendable {
    public private(set) var now: Date

    public init(now: Date = Date(timeIntervalSince1970: 0)) {
        self.now = now
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}


