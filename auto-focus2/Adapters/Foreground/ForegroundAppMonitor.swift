import AppKit
import Foundation

final class ForegroundAppProvider: ForegroundProviding {
    func currentForegroundAppBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

final class ForegroundAppMonitor: ObservableObject {
    @Published private(set) var currentBundleId: String?

    private let provider: ForegroundProviding
    private var timer: Timer?
    private let interval: TimeInterval

    init(provider: ForegroundProviding, interval: TimeInterval = 1.0) {
        self.provider = provider
        self.interval = interval
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let next = provider.currentForegroundAppBundleId()
        if next != currentBundleId {
            currentBundleId = next
        }
    }
}


