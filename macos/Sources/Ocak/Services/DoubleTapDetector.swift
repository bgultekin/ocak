import CoreGraphics
import Foundation

final class DoubleTapDetector {
    var modifier: DoubleTapModifier
    var thresholdMs: Int
    var onDoubleTap: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var lastTapTime: Date?
    private var lastFlagsHadModifier = false

    init(modifier: DoubleTapModifier, thresholdMs: Int = 300) {
        self.modifier = modifier
        self.thresholdMs = thresholdMs
    }

    func start() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                Unmanaged<DoubleTapDetector>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                    .handleFlagsChanged(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source

        let thread = Thread {
            let rl = CFRunLoopGetCurrent()!
            self.tapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CFRunLoopRun()
        }
        thread.qualityOfService = QualityOfService.userInteractive
        thread.start()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = tapRunLoop, let src = runLoopSource {
            CFRunLoopRemoveSource(rl, src, .commonModes)
            CFRunLoopStop(rl)
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
        lastTapTime = nil
        lastFlagsHadModifier = false
    }

    private func handleFlagsChanged(event: CGEvent) {
        let nowHas = event.flags.contains(modifier.cgEventFlag)
        defer { lastFlagsHadModifier = nowHas }
        guard nowHas && !lastFlagsHadModifier else { return }

        let now = Date()
        if Self.isDoubleTap(previousTap: lastTapTime, currentTap: now, thresholdMs: thresholdMs) {
            lastTapTime = nil
            DispatchQueue.main.async { self.onDoubleTap?() }
        } else {
            lastTapTime = now
        }
    }

    static func isDoubleTap(previousTap: Date?, currentTap: Date, thresholdMs: Int) -> Bool {
        guard let previous = previousTap else { return false }
        return currentTap.timeIntervalSince(previous) * 1000 < Double(thresholdMs)
    }
}
