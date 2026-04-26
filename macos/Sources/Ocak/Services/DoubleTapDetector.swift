import CoreGraphics
import Foundation

final class DoubleTapDetector {
    private(set) var modifier: DoubleTapModifier
    private(set) var thresholdMs: Int
    var onDoubleTap: (() -> Void)?

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var retainedSelfPtr: UnsafeMutableRawPointer?
    private var pendingStop = false
    private var isStopped = false
    private var workerThread: Thread?
    private var lastTapTime: Date?
    private var lastFlagsHadModifier = false

    init(modifier: DoubleTapModifier, thresholdMs: Int = 300) {
        self.modifier = modifier
        self.thresholdMs = thresholdMs
    }

    func start() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let detector = Unmanaged<DoubleTapDetector>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    detector.reenableTap()
                } else if type == .flagsChanged {
                    detector.handleFlagsChanged(event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            Unmanaged<DoubleTapDetector>.fromOpaque(selfPtr).release()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        let thread = Thread {
            let rl = CFRunLoopGetCurrent()!
            self.stateLock.lock()
            self.tapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            if self.pendingStop {
                CFRunLoopStop(rl)
                self.stateLock.unlock()
                return
            }
            self.stateLock.unlock()
            CFRunLoopRun()
        }
        thread.qualityOfService = QualityOfService.userInteractive

        stateLock.lock()
        eventTap = tap
        retainedSelfPtr = selfPtr
        runLoopSource = source
        pendingStop = false
        isStopped = false
        workerThread = thread
        stateLock.unlock()

        thread.start()
    }

    func stop() {
        stateLock.lock()
        let tap = eventTap
        let ptr = retainedSelfPtr
        if let rl = tapRunLoop, let src = runLoopSource {
            CFRunLoopRemoveSource(rl, src, .commonModes)
            CFRunLoopStop(rl)
            pendingStop = false
        } else {
            pendingStop = true
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
        retainedSelfPtr = nil
        workerThread = nil
        lastTapTime = nil
        lastFlagsHadModifier = false
        isStopped = true
        stateLock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let ptr {
            Unmanaged<DoubleTapDetector>.fromOpaque(ptr).release()
        }
    }

    private func reenableTap() {
        stateLock.lock()
        let tap = eventTap
        let stopped = isStopped
        stateLock.unlock()
        if let tap, !stopped {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        stateLock.lock()
        let nowHas = event.flags.contains(modifier.cgEventFlag)
        let hadModifier = lastFlagsHadModifier
        lastFlagsHadModifier = nowHas
        stateLock.unlock()

        guard nowHas && !hadModifier else { return }

        stateLock.lock()
        let previous = lastTapTime
        stateLock.unlock()

        let now = Date()
        if Self.isDoubleTap(previousTap: previous, currentTap: now, thresholdMs: thresholdMs) {
            stateLock.lock()
            lastTapTime = nil
            stateLock.unlock()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.stateLock.lock()
                let stopped = self.isStopped
                let callback = self.onDoubleTap
                self.stateLock.unlock()
                guard !stopped else { return }
                callback?()
            }
        } else {
            stateLock.lock()
            lastTapTime = now
            stateLock.unlock()
        }
    }

    static func isDoubleTap(previousTap: Date?, currentTap: Date, thresholdMs: Int) -> Bool {
        guard let previous = previousTap else { return false }
        return currentTap.timeIntervalSince(previous) * 1000 < Double(thresholdMs)
    }
}
