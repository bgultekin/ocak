import AppKit
import SwiftTerm
import Foundation
import Observation

/// Owns all terminal views and their processes. Views persist across session switches.
@MainActor
final class TerminalManager {
    static let shared = TerminalManager()

    private var terminals: [UUID: OcakTerminalView] = [:]
    private var delegates: [UUID: TerminalDelegate] = [:]

    /// Get or create a terminal view for a session.
    func terminal(
        for sessionID: UUID,
        workingDirectory: String,
        aiTool: AITool,
        initialCommand: String? = nil,
        onStatusChange: ((SessionStatus) -> Void)?,
        onDirectoryChange: ((String) -> Void)?
    ) -> OcakTerminalView {
        if let existing = terminals[sessionID] {
            // Update callbacks (closures may capture new state)
            delegates[sessionID]?.onStatusChange = onStatusChange
            delegates[sessionID]?.onDirectoryChange = onDirectoryChange
            return existing
        }

        // Create new terminal
        let termView = OcakTerminalView(frame: .zero)
        let delegate = TerminalDelegate(
            onStatusChange: onStatusChange,
            onDirectoryChange: onDirectoryChange
        )

        configureAppearance(termView)
        termView.configureHistoryLogging(sessionID: sessionID)

        // Defer history replay until the view has proper dimensions (layout())
        if let historyData = TerminalHistoryLogger.readLog(for: sessionID) {
            termView.pendingHistoryReplay = historyData
        }

        termView.processDelegate = delegate
        terminals[sessionID] = termView
        delegates[sessionID] = delegate

        startShellProcess(in: termView, sessionID: sessionID, workingDirectory: workingDirectory, aiTool: aiTool, initialCommand: initialCommand)

        return termView
    }

    /// Remove a terminal when its session is deleted.
    func removeTerminal(for sessionID: UUID) {
        terminals[sessionID]?.historyLogger?.flush()
        terminals.removeValue(forKey: sessionID)
        delegates.removeValue(forKey: sessionID)
        ShellHookWriter.cleanup(sessionID: sessionID)
        TerminalHistoryLogger.deleteLog(for: sessionID)
    }

    /// Check if a terminal already exists for a session.
    func hasTerminal(for sessionID: UUID) -> Bool {
        terminals[sessionID] != nil
    }

    /// Returns the shell PID for a session's terminal, or nil if no terminal exists or shell not started.
    func shellPid(for sessionID: UUID) -> pid_t? {
        guard let view = terminals[sessionID],
              view.process.shellPid != 0 else { return nil }
        return view.process.shellPid
    }

    /// Flush all active history loggers to disk.
    func flushAllHistoryLogs() {
        for (_, termView) in terminals {
            termView.historyLogger?.flush()
        }
    }

    func redrawAllTerminals() {
        for (_, termView) in terminals {
            termView.setNeedsDisplay(termView.bounds)
        }
    }

    /// Update appearance for all terminals (e.g., when theme changes).
    func updateAllTerminalsAppearance() {
        for (_, termView) in terminals {
            configureAppearance(termView)
        }
    }

    /// Force every persistent terminal view to redraw. Used after the drawer finishes
    /// sliding in on a new panel/screen: SwiftTerm only marks itself dirty inside
    /// `setFrameSize` / mouse events, so when the view is re-parented into a fresh
    /// window with unchanged final bounds, the CALayer keeps its stale backing store
    /// and the terminal renders as a solid background color (looks black) until the
    /// user clicks. Calling this after the panel is fully on-screen guarantees a
    /// draw pass in the new window's compositor.
    func redrawAllTerminals() {
        for (_, termView) in terminals {
            termView.needsDisplay = true
        }
    }

    // MARK: - Private

    private static func historyFilePath(for sessionID: UUID) -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Ocak/terminal-history/hist_\(sessionID.uuidString)").path
    }

    private func configureAppearance(_ termView: OcakTerminalView) {
        let isDark = TerminalThemeConfigStore.shared.effectiveMode == .dark

        let bgColor: NSColor
        let fgColor: NSColor

        if isDark {
            bgColor = NSColor(red: 0.051, green: 0.051, blue: 0.063, alpha: 1) // #0D0D10
            fgColor = NSColor(white: 1.0, alpha: 0.73)
        } else {
            bgColor = NSColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1) // #FAFAFA
            fgColor = NSColor(red: 0.114, green: 0.114, blue: 0.122, alpha: 1) // #1D1D1F
        }

        termView.nativeBackgroundColor = bgColor
        termView.nativeForegroundColor = fgColor
        termView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        // SwiftTerm.Color expects components in 0..65535; multiply 8-bit values by 257.
        func c(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> SwiftTerm.Color {
            SwiftTerm.Color(red: r * 257, green: g * 257, blue: b * 257)
        }

        let ansiColors: [SwiftTerm.Color] = [
            c(0, 0, 0),
            c(255, 69, 58),
            c(48, 209, 88),
            c(255, 214, 10),
            c(10, 132, 255),
            c(191, 90, 242),
            c(100, 230, 224),
            c(204, 204, 204),
            c(102, 102, 102),
            c(255, 107, 97),
            c(76, 225, 117),
            c(255, 224, 61),
            c(64, 156, 255),
            c(209, 120, 255),
            c(140, 242, 237),
            c(255, 255, 255),
        ]
        termView.installColors(ansiColors)
    }

    private func startShellProcess(in termView: OcakTerminalView, sessionID: UUID, workingDirectory: String, aiTool: AITool, initialCommand: String? = nil) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let isZsh = shell.hasSuffix("/zsh")
        let isBash = shell.hasSuffix("/bash")

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["TERM_PROGRAM"] = "Ocak"
        env["TERM_PROGRAM_VERSION"] = "1.0"
        env["OCAK_SESSION_ID"] = sessionID.uuidString
        env["HISTSIZE"] = "10000"
        env["SAVEHIST"] = "10000"
        env["PATH"] = Self.expandedPath(current: env["PATH"])

        var args: [String]

        if isZsh {
            let originalZDOTDIR = env["ZDOTDIR"]
            let zdotdir = ShellHookWriter.prepareZsh(sessionID: sessionID, originalZDOTDIR: originalZDOTDIR)
            env["ZDOTDIR"] = zdotdir
            env["ZDOTDIR_ORIGINAL"] = originalZDOTDIR ?? NSHomeDirectory()
            args = ["-l"]
        } else if isBash {
            let rcfile = ShellHookWriter.prepareBash(sessionID: sessionID)
            args = ["--rcfile", rcfile]
        } else {
            args = ["-l"]
        }

        let envArray = env.map { "\($0.key)=\($0.value)" }

        termView.startProcess(
            executable: shell,
            args: args,
            environment: envArray,
            execName: nil,
            currentDirectory: workingDirectory
        )

        if let initialCommand, !initialCommand.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                termView.send(txt: "\(initialCommand)\n")
            }
        }
    }

    /// Builds a PATH suitable for GUI-launched shells, which start with launchd's minimal PATH.
    /// Runs /usr/libexec/path_helper (same as a login shell) and prepends common user bin dirs.
    nonisolated private static func expandedPath(current: String?) -> String {
        // Run path_helper to get the system-expanded PATH (Homebrew, /usr/local/bin, etc.)
        var systemPath = current ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/path_helper")
        task.arguments = ["-s"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        if (try? task.run()) != nil {
            task.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // path_helper outputs: PATH="..."; export PATH;
            if let match = output.range(of: #"PATH="([^"]+)""#, options: .regularExpression) {
                let inner = output[match].dropFirst(6).dropLast(1) // strip PATH=" and "
                systemPath = String(inner)
            }
        }

        // Prepend user-local bin dirs that tools like Claude Code install to.
        // These aren't covered by path_helper and may not be in dotfiles.
        let home = NSHomeDirectory()
        let userPaths = ["\(home)/.local/bin"]
        let existing = Set(systemPath.split(separator: ":").map(String.init))
        let toAdd = userPaths.filter { !existing.contains($0) }
        return toAdd.isEmpty ? systemPath : toAdd.joined(separator: ":") + ":" + systemPath
    }
}

// MARK: - Delegate

final class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate {
    var onStatusChange: ((SessionStatus) -> Void)?
    var onDirectoryChange: ((String) -> Void)?
    private(set) var isShellTerminated = false

    init(
        onStatusChange: ((SessionStatus) -> Void)?,
        onDirectoryChange: ((String) -> Void)?
    ) {
        self.onStatusChange = onStatusChange
        self.onDirectoryChange = onDirectoryChange
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory else { return }
        let path: String
        if let url = URL(string: directory), url.scheme == "file" {
            path = url.path
        } else {
            path = directory
        }
        DispatchQueue.main.async {
            self.onDirectoryChange?(path)
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.isShellTerminated = true
            self.onStatusChange?(.done)
        }
    }
}
