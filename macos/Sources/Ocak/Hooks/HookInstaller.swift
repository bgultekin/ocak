import Foundation

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

    /// Updates the installed ocak plugin if a newer version is bundled in the app.
    /// Returns true if an update was performed, false if no update was needed.
    @discardableResult
    static func updatePluginIfNeeded() throws -> Bool {
        let bundledVersion = try PluginVersionManager.readBundledPluginVersion()
        let installedVersion = try PluginVersionManager.readInstalledPluginVersion()

        guard let bundled = bundledVersion, let installed = installedVersion else {
            return false
        }

        guard PluginVersionManager.isVersionGreater(bundled, than: installed) else {
            return false
        }

        let loginPath = getLoginPath()
        guard let claudePath = findExecutable("claude", loginPath: loginPath) else {
            throw InstallError.commandFailed("claude not found in PATH")
        }

        try runShell("'\(claudePath)' plugin install ocak@ocak-plugins --scope user", loginPath: loginPath)
        return true
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

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        try proc.run()

        // Read stdout and stderr concurrently to avoid pipe buffer deadlocks
        var stdoutData = Data()
        var stderrData = Data()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            stdoutData = stdoutHandle.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            stderrData = stderrHandle.readDataToEndOfFile()
            group.leave()
        }

        let deadline: DispatchTime = .now() + 60
        if group.wait(timeout: deadline) == .timedOut {
            proc.terminate()
            proc.waitUntilExit()
            throw InstallError.commandFailed("Command timed out after 60s")
        }

        proc.waitUntilExit()

        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
        let output = (stdoutStr + stderrStr).trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { print(output) }
        print("[Ocak] Exit code: \(proc.terminationStatus)")

        if proc.terminationStatus != 0 {
            throw InstallError.commandFailed(output)
        }
        return stdoutStr
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
