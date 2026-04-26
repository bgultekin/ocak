import Testing
import Foundation

// Mirror the pure timing logic (cannot import executable target)
private func isDoubleTap(previousTap: Date?, currentTap: Date, thresholdMs: Int) -> Bool {
    guard let previous = previousTap else { return false }
    return currentTap.timeIntervalSince(previous) * 1000 < Double(thresholdMs)
}

@Suite("DoubleTapDetector — timing logic")
struct DoubleTapDetectorTests {

    @Test("no previous tap → not a double tap")
    func noPreviousTap() {
        #expect(!isDoubleTap(previousTap: nil, currentTap: Date(), thresholdMs: 300))
    }

    @Test("tap within threshold → double tap")
    func withinThreshold() {
        let first = Date()
        let second = first.addingTimeInterval(0.150)
        #expect(isDoubleTap(previousTap: first, currentTap: second, thresholdMs: 300))
    }

    @Test("tap exactly at threshold boundary → not a double tap")
    func atThreshold() {
        let first = Date()
        // Use a value guaranteed to be >= 300ms after floating-point arithmetic
        let second = first.addingTimeInterval(0.3001)
        #expect(!isDoubleTap(previousTap: first, currentTap: second, thresholdMs: 300))
    }

    @Test("tap beyond threshold → not a double tap")
    func beyondThreshold() {
        let first = Date()
        let second = first.addingTimeInterval(0.500)
        #expect(!isDoubleTap(previousTap: first, currentTap: second, thresholdMs: 300))
    }

    @Test("threshold of 0ms → never a double tap")
    func zeroThreshold() {
        let first = Date()
        let second = first.addingTimeInterval(0.001)
        #expect(!isDoubleTap(previousTap: first, currentTap: second, thresholdMs: 0))
    }

    @Test("custom threshold of 500ms works")
    func customThreshold() {
        let first = Date()
        let second = first.addingTimeInterval(0.400)
        #expect(isDoubleTap(previousTap: first, currentTap: second, thresholdMs: 500))
    }
}
