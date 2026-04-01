import AppKit
import SwiftTerm

class MonitoredTerminalView: LocalProcessTerminalView {
    /// Tracks "meaningful" data — bursts larger than cursor blink escape sequences.
    var lastMeaningfulData = Date()
    var userSubmittedAt: Date?
    var detectedSessionNotFound = false

    /// Called on the main thread when meaningful terminal output is received.
    var onActivity: (() -> Void)?
    /// Called on the main thread when the idle timer fires (no output for idleThreshold).
    var onIdleTimeout: (() -> Void)?

    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 5.0
    private let startTime = Date()
    private let startupGracePeriod: TimeInterval = 15.0
    private var hasReceivedFirstMeaningfulData = false

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        // Cursor blink/position updates are typically < 20 bytes.
        // Real output (text, tool calls, progress) is larger.
        if slice.count > 20 {
            lastMeaningfulData = Date()
            hasReceivedFirstMeaningfulData = true
            onActivity?()
            resetIdleTimer()
        }
        if !detectedSessionNotFound,
           let text = String(bytes: slice, encoding: .utf8),
           text.contains("No conversation found with session ID") {
            detectedSessionNotFound = true
        }
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        super.send(source: source, data: data)
        // Detect Enter key (carriage return)
        if data.contains(13) {
            userSubmittedAt = Date()
        }
    }

    /// Start the initial idle countdown. Call after terminal setup.
    func startIdleTimer() {
        resetIdleTimer()
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleThreshold, repeats: false) {
            [weak self] _ in
            guard let self else { return }
            // During startup grace, don't transition to idle if no output yet
            if !self.hasReceivedFirstMeaningfulData,
               Date().timeIntervalSince(self.startTime) < self.startupGracePeriod {
                return
            }
            self.onIdleTimeout?()
        }
    }

    var secondsSinceMeaningfulData: TimeInterval {
        Date().timeIntervalSince(lastMeaningfulData)
    }

    var isUserWaiting: Bool {
        guard let submitted = userSubmittedAt else { return false }
        // User submitted and we haven't gone idle since
        return Date().timeIntervalSince(submitted) < secondsSinceMeaningfulData
    }
}
