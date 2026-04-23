import AppKit
import SwiftTerm

/// LocalProcessTerminalView subclass.
/// Terminal parsing removed — status is now driven by Claude Code hooks.
final class OcakTerminalView: LocalProcessTerminalView {
    var sessionID: UUID?
    private(set) var historyLogger: TerminalHistoryLogger?
    /// History data waiting to be replayed once the view has proper dimensions.
    var pendingHistoryReplay: Data?
    /// When true, terminal responses (DA, DSR, etc.) are suppressed to avoid
    /// feeding query responses into the new shell during history replay.
    private var suppressingResponses = false

    func configureHistoryLogging(sessionID: UUID) {
        self.sessionID = sessionID
        self.historyLogger = TerminalHistoryLogger(sessionID: sessionID)
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        historyLogger?.append(bytes: slice)
        super.dataReceived(slice: slice)
    }

    override func send(source: Terminal, data: ArraySlice<UInt8>) {
        if suppressingResponses { return }
        super.send(source: source, data: data)
    }

    override func layout() {
        // Skip SwiftTerm layout when bounds are zero — avoids sending a 0-col SIGWINCH
        // to the running process during the brief zero-size phase that occurs each time
        // the drawer is reopened (makeNSView creates a frame:.zero container and AutoLayout
        // propagates the real size only after SwiftUI's next layout pass).
        guard bounds.width > 0, bounds.height > 0 else { return }
        super.layout()
        if let data = pendingHistoryReplay {
            pendingHistoryReplay = nil
            let cleaned = Self.strippedMouseReports(from: data)
            suppressingResponses = true
            feed(byteArray: ArraySlice(cleaned))
            // Replay may contain DECSET ?1006 from a TUI; force mouse tracking off.
            let mouseReset: [UInt8] = Array("\u{1B}[?1000l\u{1B}[?1002l\u{1B}[?1003l\u{1B}[?1006l".utf8)
            feed(byteArray: mouseReset[...])
            suppressingResponses = false
            let cols = terminal.cols
            let separator = "\u{1B}[90m" + String(repeating: "─", count: cols) + "\u{1B}[0m\r\n"
            feed(text: separator)
        }
    }

    /// Drop `(\d+;\d+;\d+[Mm])+` runs at the top level — stripped SGR mouse reports whose
    /// `ESC[<` prefix was eaten by zsh ZLE when a TUI left mouse tracking on. Escape
    /// sequences (CSI, OSC) are emitted verbatim and never scanned internally, so real
    /// 24-bit SGR like `ESC[38;2;R;G;Bm` is left intact.
    static func strippedMouseReports(from data: Data) -> Data {
        var out = Data()
        out.reserveCapacity(data.count)
        let bytes = [UInt8](data)
        let n = bytes.count
        var i = 0
        while i < n {
            let b = bytes[i]
            if b == 0x1B, i + 1 < n {
                let kind = bytes[i + 1]
                out.append(b)
                out.append(kind)
                var j = i + 2
                switch kind {
                case UInt8(ascii: "["):
                    // CSI: copy params until final byte in 0x40…0x7E.
                    while j < n {
                        let c = bytes[j]
                        out.append(c)
                        j += 1
                        if c >= 0x40 && c <= 0x7E { break }
                    }
                case UInt8(ascii: "]"), UInt8(ascii: "P"), UInt8(ascii: "X"), UInt8(ascii: "^"), UInt8(ascii: "_"):
                    // OSC / DCS / SOS / PM / APC: terminate on BEL or ST (ESC \).
                    while j < n {
                        let c = bytes[j]
                        out.append(c)
                        j += 1
                        if c == 0x07 { break }
                        if c == 0x1B, j < n, bytes[j] == UInt8(ascii: "\\") {
                            out.append(bytes[j]); j += 1; break
                        }
                    }
                default:
                    break
                }
                i = j
                continue
            }
            if let end = matchStrippedRun(bytes, at: i) {
                i = end
                continue
            }
            out.append(b)
            i += 1
        }
        return out
    }

    private static func matchStrippedRun(_ bytes: [UInt8], at start: Int) -> Int? {
        // Byte immediately before a real mouse-report tail is always `;` or a digit
        // (we're inside a CSI). Top-level stripped runs are preceded by whitespace,
        // a letter, a newline, or the start of the buffer.
        if start > 0 {
            let prev = bytes[start - 1]
            if prev == UInt8(ascii: ";") || (prev >= UInt8(ascii: "0") && prev <= UInt8(ascii: "9")) {
                return nil
            }
        }
        var i = start
        var groups = 0
        while let next = matchSingleGroup(bytes, at: i) {
            i = next
            groups += 1
        }
        return groups > 0 ? i : nil
    }

    private static func matchSingleGroup(_ bytes: [UInt8], at start: Int) -> Int? {
        var i = start
        func digits() -> Bool {
            let s = i
            while i < bytes.count, bytes[i] >= UInt8(ascii: "0"), bytes[i] <= UInt8(ascii: "9") { i += 1 }
            return i > s
        }
        guard digits() else { return nil }
        guard i < bytes.count, bytes[i] == UInt8(ascii: ";") else { return nil }
        i += 1
        guard digits() else { return nil }
        guard i < bytes.count, bytes[i] == UInt8(ascii: ";") else { return nil }
        i += 1
        guard digits() else { return nil }
        guard i < bytes.count, bytes[i] == UInt8(ascii: "M") || bytes[i] == UInt8(ascii: "m") else { return nil }
        return i + 1
    }

    /// Required for key events in a .nonactivatingPanel — without this override,
    /// AppKit refuses to grant key status and typed characters go nowhere.
    override var needsPanelToBecomeKey: Bool { true }

    /// Local event monitor for arrow keys when kitty protocol is active.
    /// In .nonactivatingPanel, interpretKeyEvents may not map arrow keys to
    /// moveLeft:/moveRight:/etc. selectors reliably, so we intercept them here.
    private var arrowKeyMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // The terminal view is persistent across drawer open/close cycles and gets
        // re-parented into a fresh window each time the drawer is reopened. SwiftTerm
        // only marks itself needsDisplay inside setFrameSize / mouse events, so when
        // the new container ends up with the same final frame, the CALayer keeps its
        // stale/empty backing store and the terminal renders black until the user
        // clicks or switches sessions. Force a redraw on every window attach.
        if window != nil {
            needsDisplay = true
        }
        arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, window != nil else { return event }
            guard !terminal.keyboardEnhancementFlags.isEmpty else { return event }
            let arrowLetter: UInt8?
            switch event.keyCode {
            case 123: arrowLetter = UInt8(ascii: "D")  // left
            case 124: arrowLetter = UInt8(ascii: "C")  // right
            case 125: arrowLetter = UInt8(ascii: "B")  // down
            case 126: arrowLetter = UInt8(ascii: "A")  // up
            default: arrowLetter = nil
            }
            guard let arrowLetter else {
                // Keys whose modifiers SwiftTerm's doCommand drops under kitty protocol
                let kittyCodepoint: Int?
                switch event.keyCode {
                case 36: kittyCodepoint = 13   // Enter
                case 53: kittyCodepoint = 27   // Escape
                case 51: kittyCodepoint = 127  // Backspace
                case 48: kittyCodepoint = 9    // Tab
                default: kittyCodepoint = nil
                }
                if let cp = kittyCodepoint {
                    let mods = event.modifierFlags
                    var modValue: Int = 0
                    if mods.contains(.shift) { modValue |= 1 }
                    if mods.contains(.control) { modValue |= 2 }
                    if mods.contains(.option) { modValue |= 4 }
                    if mods.contains(.command) { modValue |= 8 }
                    if modValue != 0 {
                        let seq = "\u{001B}[\(cp);\(modValue + 1)u"
                        send(txt: seq)
                        return nil
                    }
                }
                return event
            }
            let modifiers = event.modifierFlags
            var modValue: Int = 0
            if modifiers.contains(.shift) { modValue |= 1 }
            if modifiers.contains(.control) { modValue |= 2 }
            if modifiers.contains(.option) { modValue |= 4 }
            if modifiers.contains(.command) { modValue |= 8 }
            if modValue != 0 {
                let seq = "\u{001B}[1;\(modValue + 1)\(Character(UnicodeScalar(arrowLetter)))"
                send(txt: seq)
            } else {
                send([0x1B, 0x5B, arrowLetter])
            }
            return nil
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let monitor = arrowKeyMonitor {
            NSEvent.removeMonitor(monitor)
            arrowKeyMonitor = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        // Clear kitty keyboard + mouse-tracking flags; stale state survives abnormal exits.
        let reset: [UInt8] = Array("\u{1B}[=0u\u{1B}[?1000l\u{1B}[?1002l\u{1B}[?1003l\u{1B}[?1006l".utf8)
        feed(byteArray: reset[...])
        super.processTerminated(source, exitCode: exitCode)
    }
}
