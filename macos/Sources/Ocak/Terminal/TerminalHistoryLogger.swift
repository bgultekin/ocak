import Foundation

/// Logs raw terminal output bytes to a per-session file for history persistence.
/// Buffers writes in memory and flushes periodically to avoid per-chunk disk I/O.
final class TerminalHistoryLogger {
    let sessionID: UUID

    private var buffer = Data()
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0
    private var flushTimer: DispatchSourceTimer?

    static let maxFileSize: UInt64 = 512 * 1024
    private static let truncateTargetSize: UInt64 = 384 * 1024
    private static let flushThreshold = 64 * 1024
    private static let flushInterval: TimeInterval = 0.5

    init(sessionID: UUID) {
        self.sessionID = sessionID
        ensureDirectory()
        openFile()
        startFlushTimer()
    }

    deinit {
        flushTimer?.cancel()
        flushSync()
        fileHandle?.closeFile()
    }

    /// Append raw bytes from terminal output. Called on main thread; only touches in-memory buffer.
    func append(bytes: ArraySlice<UInt8>) {
        buffer.append(contentsOf: bytes)
        if buffer.count >= Self.flushThreshold {
            flushAsync()
        }
    }

    /// Flush pending buffer to disk synchronously.
    func flush() {
        flushSync()
    }

    // MARK: - Static

    static func readLog(for sessionID: UUID) -> Data? {
        let url = fileURL(for: sessionID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try? Data(contentsOf: url)
        return (data?.isEmpty == true) ? nil : data
    }

    static func deleteLog(for sessionID: UUID) {
        let url = fileURL(for: sessionID)
        try? FileManager.default.removeItem(at: url)
    }

    static func cleanupStale(validSessionIDs: Set<UUID>) {
        let dir = baseDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "log" {
            let stem = file.deletingPathExtension().lastPathComponent
            if let id = UUID(uuidString: stem), !validSessionIDs.contains(id) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Private

    static let baseDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Ocak/terminal-history", isDirectory: true)
    }()

    private static func fileURL(for sessionID: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(sessionID.uuidString).log")
    }

    private var fileURL: URL { Self.fileURL(for: sessionID) }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: Self.baseDirectory, withIntermediateDirectories: true)
    }

    private func openFile() {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: fileURL.path)
        fileHandle?.seekToEndOfFile()
        currentFileSize = fileHandle?.offsetInFile ?? 0
    }

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.flushInterval, repeating: Self.flushInterval)
        timer.setEventHandler { [weak self] in
            self?.flushAsync()
        }
        timer.resume()
        flushTimer = timer
    }

    private func flushAsync() {
        guard !buffer.isEmpty else { return }
        let chunk = buffer
        buffer = Data()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.writeChunk(chunk)
        }
    }

    private func flushSync() {
        guard !buffer.isEmpty else { return }
        let chunk = buffer
        buffer = Data()
        writeChunk(chunk)
    }

    private func writeChunk(_ chunk: Data) {
        fileHandle?.write(chunk)
        currentFileSize += UInt64(chunk.count)
        if currentFileSize > Self.maxFileSize {
            truncateFile()
        }
    }

    private func truncateFile() {
        fileHandle?.closeFile()
        fileHandle = nil

        guard var data = try? Data(contentsOf: fileURL) else {
            openFile()
            return
        }
        if data.count > Int(Self.truncateTargetSize) {
            data = data.suffix(Int(Self.truncateTargetSize))
        }
        try? data.write(to: fileURL, options: .atomic)
        currentFileSize = UInt64(data.count)
        openFile()
    }
}
