import Foundation
import Darwin

/// Registers Ocak's bundled Claude Code plugin via `claude plugin marketplace add` + `claude plugin install`,
/// and copies the OpenCode plugin to ~/.config/opencode/plugins/.
enum HookInstaller {
    enum InstallError: Error {
        case pluginNotFound
        case writeFailed
        case commandFailed(String)
    }

    private static let legacySettingsPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json").path
    }()

    private static let openCodePluginPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/plugins/ocak.js").path
    }()

    static let hooksIgnoredKey = "ocak.hooksIgnored"

    // MARK: - Claude Code

    /// Whether the Claude Code plugin is installed (checks UserDefaults flag).
    static func isInstalled() -> Bool {
        UserDefaults.standard.bool(forKey: "ocak.hooksInstalled")
    }

    private static func markInstalled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "ocak.hooksInstalled")
    }

    /// Registers the bundled marketplace with Claude Code via the claude CLI.
    /// Also migrates any legacy hooks out of ~/.claude/settings.json.
    static func install() throws {
        guard let marketplaceURL = Bundle.module.resourceURL?.appendingPathComponent("claude-ocak-marketplace"),
              FileManager.default.fileExists(atPath: marketplaceURL.path) else {
            throw InstallError.pluginNotFound
        }

        let loginPath = getLoginPath()
        guard let claudePath = findExecutable("claude", loginPath: loginPath) else {
            throw InstallError.commandFailed("claude not found in PATH")
        }

        let escaped = marketplaceURL.path.replacingOccurrences(of: "'", with: "'\\''")
        try runShell("'\(claudePath)' plugin marketplace add '\(escaped)' --scope user", loginPath: loginPath)
        try runShell("'\(claudePath)' plugin install ocak@ocak-plugins --scope user", loginPath: loginPath)

        markInstalled(true)
        removeLegacyHooks()
    }

    static func uninstall() throws {
        let loginPath = getLoginPath()
        guard let claudePath = findExecutable("claude", loginPath: loginPath) else {
            throw InstallError.commandFailed("claude not found in PATH")
        }

        try runShell("'\(claudePath)' plugin uninstall ocak@ocak-plugins", loginPath: loginPath)
        _ = try? runShell("'\(claudePath)' plugin marketplace remove ocak-plugins", loginPath: loginPath)
        markInstalled(false)
    }

    // MARK: - OpenCode

    /// Whether the OpenCode plugin file exists at the expected path.
    static func isOpenCodeHooksInstalled() -> Bool {
        FileManager.default.fileExists(atPath: openCodePluginPath)
    }

    /// Copies the bundled OpenCode plugin to ~/.config/opencode/plugins/ocak.js.
    static func installOpenCodeHooks() throws {
        guard let pluginURL = Bundle.module.resourceURL?.appendingPathComponent("opencode-ocak/plugin.js"),
              FileManager.default.fileExists(atPath: pluginURL.path) else {
            throw InstallError.pluginNotFound
        }

        let pluginData = try Data(contentsOf: pluginURL)
        let pluginsDir = (openCodePluginPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: pluginsDir, withIntermediateDirectories: true)
        try pluginData.write(to: URL(fileURLWithPath: openCodePluginPath), options: .atomic)
    }

    /// Removes the OpenCode plugin file.
    static func uninstallOpenCodeHooks() throws {
        if FileManager.default.fileExists(atPath: openCodePluginPath) {
            try FileManager.default.removeItem(atPath: openCodePluginPath)
        }
    }

    // MARK: - Shell

    @discardableResult
    private static func runShell(_ command: String, loginPath: String?) throws -> String {
        print("[Ocak] Running: \(command)")

        // Create master PTY
        let masterPty = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterPty > 0 else {
            throw InstallError.commandFailed("Failed to open PTY")
        }
        guard grantpt(masterPty) == 0, unlockpt(masterPty) == 0 else {
            close(masterPty)
            throw InstallError.commandFailed("Failed to configure PTY")
        }

        // Set master PTY to non-blocking
        _ = fcntl(masterPty, F_SETFL, fcntl(masterPty, F_GETFL) | O_NONBLOCK)

        // Get slave device path and open it for the child process
        guard let slaveName = ptsname(masterPty) else {
            close(masterPty)
            throw InstallError.commandFailed("Failed to get PTY slave name")
        }
        let slavePty = open(slaveName, O_RDWR)
        guard slavePty > 0 else {
            close(masterPty)
            throw InstallError.commandFailed("Failed to open PTY slave")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", command]
        var env = ProcessInfo.processInfo.environment
        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(loginPath ?? defaultPath):\(existingPath)"
        } else {
            env["PATH"] = loginPath ?? defaultPath
        }
        proc.environment = env
        proc.standardInput = FileHandle(fileDescriptor: dup(slavePty), closeOnDealloc: true)
        proc.standardOutput = FileHandle(fileDescriptor: dup(slavePty), closeOnDealloc: true)
        proc.standardError = FileHandle(fileDescriptor: dup(slavePty), closeOnDealloc: true)
        try proc.run()
        close(slavePty)

        var output = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = Date().addingTimeInterval(60)

        while proc.isRunning && Date() < deadline {
            let bytesRead = read(masterPty, &buffer, buffer.count)
            if bytesRead > 0 {
                if let text = String(bytes: buffer[..<bytesRead], encoding: .utf8) {
                    print(text, terminator: "")
                    output += text
                }
            } else if bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
                break
            }
            usleep(50_000) // 50ms poll interval
        }

        // Drain remaining with timeout
        while Date() < deadline {
            let bytesRead = read(masterPty, &buffer, buffer.count)
            if bytesRead > 0 {
                if let text = String(bytes: buffer[..<bytesRead], encoding: .utf8) {
                    print(text, terminator: "")
                    output += text
                }
            } else {
                break
            }
        }

        close(masterPty)

        if proc.isRunning {
            proc.terminate()
        }
        proc.waitUntilExit()
        print("[Ocak] Exit code: \(proc.terminationStatus)")

        if proc.terminationStatus != 0 {
            throw InstallError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private static func getLoginPath() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "echo $PATH"]
        proc.standardOutput = Pipe()
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        guard let pipe = proc.standardOutput as? Pipe else { return nil }
        let data = pipe.fileHandleForReading.availableData
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func findExecutable(_ name: String, loginPath: String?) -> String? {
        if let path = loginPath {
            for dir in path.split(separator: ":") {
                let candidate = String(dir).appending("/\(name)")
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        let fallbackPaths = [
            NSHomeDirectory().appending("/.local/bin/\(name)"),
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
        ]
        for candidate in fallbackPaths {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Migration

    /// Silently removes legacy OCAK_SESSION_ID hooks from ~/.claude/settings.json if present.
    private static func removeLegacyHooks() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacySettingsPath),
              let data = fm.contents(atPath: legacySettingsPath),
              var settings = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for (key, value) in hooks {
            guard let matchers = value as? [[String: Any]] else { continue }
            let filtered = matchers.filter { matcher in
                guard let hookArray = matcher["hooks"] as? [[String: Any]] else { return true }
                return !hookArray.contains { ($0["command"] as? String)?.contains("OCAK_SESSION_ID") == true }
            }
            if filtered.isEmpty { hooks.removeValue(forKey: key) } else { hooks[key] = filtered }
        }

        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }

        guard let out = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? out.write(to: URL(fileURLWithPath: legacySettingsPath), options: .atomic)
    }
}
