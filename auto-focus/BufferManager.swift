import Foundation
import SwiftUI

protocol BufferManagerDelegate: AnyObject {
    func bufferManagerDidStartBuffer(_ manager: BufferManager)
    func bufferManagerDidEndBuffer(_ manager: BufferManager)
    func bufferManagerDidTimeout(_ manager: BufferManager)
}

class BufferManager: ObservableObject {
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
        print("Buffer started: \(duration) seconds")
    }

    func cancelBuffer() {
        guard isInBufferPeriod else { return }
        endBuffer(timedOut: false)
        print("Buffer cancelled")
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
