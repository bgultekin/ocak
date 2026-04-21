import Foundation

/// Runs `claude -p` with the Haiku model to summarize a user prompt into a short
/// terminal tab name (2–4 words). Results are delivered on the main queue.
enum TerminalNameSummarizer {
    /// Generate a short name for `prompt` and invoke `completion` on the main queue
    /// once finished. `completion` receives nil on any failure (missing `claude`,
    /// non-zero exit, timeout, empty output) so callers can silently fall back.
    static func summarize(prompt: String, completion: @escaping (String?) -> Void) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let name = runSummarizer(prompt: trimmed)
            DispatchQueue.main.async { completion(name) }
        }
    }

    // MARK: - Internal

    private static let instruction = """
    Summarize the following user request as a short terminal tab name.
    Respond with 2 to 4 words only. No quotes, no punctuation, no trailing period, \
    no explanation — output nothing except the name itself.

    Request:
    """

    private static func runSummarizer(prompt: String) -> String? {
        let loginPath = loginPath()
        guard let claudePath = findExecutable("claude", loginPath: loginPath) else {
            return nil
        }

        let fullPrompt = "\(instruction)\n\(prompt)"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: claudePath)
        proc.arguments = ["-p", fullPrompt, "--model", "haiku"]

        var env = ProcessInfo.processInfo.environment
        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let login = loginPath, !login.isEmpty {
            env["PATH"] = "\(login):\(env["PATH"] ?? defaultPath)"
        } else if env["PATH"] == nil {
            env["PATH"] = defaultPath
        }
        // Prevent claude from attempting to use our hook server for its own session.
        env.removeValue(forKey: "OCAK_SESSION_ID")
        proc.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        do {
            try proc.run()
        } catch {
            return nil
        }

        var stdoutData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global().async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global().async {
            _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        if readGroup.wait(timeout: .now() + 30) == .timedOut {
            proc.terminate()
            // Wait up to 5 seconds for process to terminate after SIGTERM
            let waited = DispatchGroup()
            waited.enter()
            DispatchQueue.global(qos: .utility).async {
                proc.waitUntilExit()
                waited.leave()
            }
            _ = waited.wait(timeout: .now() + 5)
            return nil
        }

        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }

        let raw = String(data: stdoutData, encoding: .utf8) ?? ""
        return sanitize(raw)
    }

    private static func sanitize(_ raw: String) -> String? {
        let firstLine = raw
            .components(separatedBy: CharacterSet.newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""

        var name = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let strippable: Set<Character> = ["\"", "'", "`", "“", "”", "‘", "’", "."]
        while let first = name.first, strippable.contains(first) { name.removeFirst() }
        while let last = name.last, strippable.contains(last) { name.removeLast() }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return nil }
        let maxLength = 40
        if name.count > maxLength {
            name = String(name.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !name.isEmpty else { return nil }
        return name.capitalized
    }

    private static func loginPath() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return nil
        }
        let waited = DispatchGroup()
        waited.enter()
        DispatchQueue.global(qos: .utility).async {
            proc.waitUntilExit()
            waited.leave()
        }
        if waited.wait(timeout: .now() + 10) == .timedOut {
            proc.terminate()
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
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
        for candidate in fallbackPaths where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }
}
