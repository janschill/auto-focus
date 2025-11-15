import Foundation
import SwiftUI

protocol BufferManagerDelegate: AnyObject {
    func bufferManagerDidStartBuffer(_ manager: any BufferManaging)
    func bufferManagerDidEndBuffer(_ manager: any BufferManaging)
    func bufferManagerDidTimeout(_ manager: any BufferManaging)
}

class BufferManager: ObservableObject, BufferManaging {
    @Published private(set) var bufferTimeRemaining: TimeInterval = 0
    @Published private(set) var isInBufferPeriod = false

    private var bufferTimer: Timer?
    private var remainingBufferTime: TimeInterval = 0
    private let timerInterval: TimeInterval = AppConfiguration.bufferTimerInterval

    weak var delegate: BufferManagerDelegate?

    // MARK: - Buffer Control

    func startBuffer(duration: TimeInterval) {
        guard !isInBufferPeriod else { return }

        isInBufferPeriod = true
        remainingBufferTime = duration
        bufferTimeRemaining = remainingBufferTime

        // Cancel any existing timer
        bufferTimer?.invalidate()

        bufferTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.remainingBufferTime -= self.timerInterval
            self.bufferTimeRemaining = self.remainingBufferTime

            if self.remainingBufferTime <= 0 {
                self.endBuffer(timedOut: true)
            }
        }

        RunLoop.current.add(bufferTimer!, forMode: .common)

        delegate?.bufferManagerDidStartBuffer(self)
        AppLogger.focus.info("Buffer started", metadata: [
            "duration": String(format: "%.1f", duration)
        ])
    }

    func cancelBuffer() {
        guard isInBufferPeriod else { return }
        endBuffer(timedOut: false)
        AppLogger.focus.info("Buffer cancelled")
    }

    private func endBuffer(timedOut: Bool) {
        bufferTimer?.invalidate()
        bufferTimer = nil
        isInBufferPeriod = false
        bufferTimeRemaining = 0
        remainingBufferTime = 0

        if timedOut {
            delegate?.bufferManagerDidTimeout(self)
        } else {
            delegate?.bufferManagerDidEndBuffer(self)
        }
    }

    deinit {
        bufferTimer?.invalidate()
    }
}
