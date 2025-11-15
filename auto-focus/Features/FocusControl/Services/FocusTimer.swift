import Foundation

/// Manages focus time tracking with configurable intervals and thresholds
class FocusTimer {
    private var timer: Timer?
    private var elapsedTime: TimeInterval = 0
    private var isPaused: Bool = false
    private let interval: TimeInterval
    
    /// Callback invoked on each timer tick with the current elapsed time
    var onTick: ((TimeInterval) -> Void)?
    
    /// Callback invoked when the threshold is reached
    var onThresholdReached: (() -> Void)?
    
    /// Current elapsed time
    var currentTime: TimeInterval {
        return elapsedTime
    }
    
    /// Whether the timer is currently running
    var isRunning: Bool {
        return timer != nil && !isPaused
    }
    
    init(interval: TimeInterval = AppConfiguration.checkInterval) {
        self.interval = interval
    }
    
    // MARK: - Timer Control
    
    /// Start the timer, optionally preserving existing elapsed time
    /// - Parameter preserveTime: If true, keeps current elapsedTime; if false, resets to 0
    func start(preserveTime: Bool = false) {
        // Stop any existing timer first
        stop()
        
        if !preserveTime {
            elapsedTime = 0
        }
        
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        AppLogger.focus.debug("Focus timer started", metadata: [
            "preserve_time": String(preserveTime),
            "elapsed_time": String(format: "%.1f", elapsedTime),
            "interval": String(format: "%.1f", interval)
        ])
    }
    
    /// Pause the timer without resetting elapsed time
    func pause() {
        guard timer != nil else { return }
        
        timer?.invalidate()
        timer = nil
        isPaused = true
        
        AppLogger.focus.debug("Focus timer paused", metadata: [
            "elapsed_time": String(format: "%.1f", elapsedTime)
        ])
    }
    
    /// Resume a paused timer
    func resume() {
        guard isPaused else { return }
        
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        AppLogger.focus.debug("Focus timer resumed", metadata: [
            "elapsed_time": String(format: "%.1f", elapsedTime)
        ])
    }
    
    /// Reset elapsed time to 0 and stop the timer
    func reset() {
        stop()
        elapsedTime = 0
        
        AppLogger.focus.debug("Focus timer reset")
    }
    
    /// Stop the timer completely
    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        
        AppLogger.focus.debug("Focus timer stopped", metadata: [
            "elapsed_time": String(format: "%.1f", elapsedTime)
        ])
    }
    
    // MARK: - Private Methods
    
    private func tick() {
        guard !isPaused else { return }
        
        elapsedTime += interval
        onTick?(elapsedTime)
    }
    
    deinit {
        stop()
    }
}

