import Testing
import Foundation

// Duplicated core of TerminalHistoryLogger for testing (executable target cannot be imported).
private final class TestHistoryLogger {
    let sessionID: UUID
    private var buffer = Data()
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0

    static let maxFileSize: UInt64 = 512 * 1024
    static let truncateTargetSize: UInt64 = 384 * 1024

    let baseDirectory: URL

    init(sessionID: UUID, baseDirectory: URL) {
        self.sessionID = sessionID
        self.baseDirectory = baseDirectory
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let path = fileURL.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()
        currentFileSize = fileHandle?.offsetInFile ?? 0
    }

    deinit {
        flushSync()
        fileHandle?.closeFile()
    }

    var fileURL: URL {
        baseDirectory.appendingPathComponent("\(sessionID.uuidString).log")
    }

    func append(bytes: ArraySlice<UInt8>) {
        buffer.append(contentsOf: bytes)
    }

    func flush() { flushSync() }

    func readLog() -> Data? {
        flushSync()
        let data = try? Data(contentsOf: fileURL)
        return (data?.isEmpty == true) ? nil : data
    }

    func deleteLog() {
        fileHandle?.closeFile()
        fileHandle = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func flushSync() {
        guard !buffer.isEmpty else { return }
        let chunk = buffer
        buffer = Data()
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
            reopenFile()
            return
        }
        if data.count > Int(Self.truncateTargetSize) {
            data = data.suffix(Int(Self.truncateTargetSize))
        }
        try? data.write(to: fileURL, options: .atomic)
        currentFileSize = UInt64(data.count)
        reopenFile()
    }

    private func reopenFile() {
        let path = fileURL.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()
        currentFileSize = fileHandle?.offsetInFile ?? 0
    }
}

@Suite("Terminal History Logger")
struct TerminalHistoryLoggerTests {

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Append and read round-trip")
    func appendAndRead() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)

        let testData: [UInt8] = Array("Hello, terminal!\r\n".utf8)
        logger.append(bytes: testData[...])

        let result = logger.readLog()
        #expect(result == Data(testData))
    }

    @Test("Multiple appends accumulate correctly")
    func multipleAppends() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)

        let chunk1: [UInt8] = Array("line1\r\n".utf8)
        let chunk2: [UInt8] = Array("line2\r\n".utf8)
        logger.append(bytes: chunk1[...])
        logger.append(bytes: chunk2[...])

        let result = logger.readLog()
        #expect(result == Data(chunk1 + chunk2))
    }

    @Test("Size cap truncates from front, keeps tail")
    func sizeCap() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)

        // Write more than 512KB to trigger truncation
        let chunkSize = 64 * 1024
        let totalChunks = 10 // 640KB total
        for i in 0..<totalChunks {
            let byte = UInt8(i & 0xFF)
            let chunk = [UInt8](repeating: byte, count: chunkSize)
            logger.append(bytes: chunk[...])
            logger.flush()
        }

        let result = logger.readLog()
        #expect(result != nil)
        // After truncation to 384KB, one more 64KB chunk may be appended before next check
        #expect(result!.count <= Int(TestHistoryLogger.maxFileSize))
        #expect(result!.count > 0)

        // The tail bytes should be from the last chunks written
        let lastByte = UInt8((totalChunks - 1) & 0xFF)
        #expect(result!.last == lastByte)
    }

    @Test("Delete removes the log file")
    func deleteLog() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)

        logger.append(bytes: Array("data".utf8)[...])
        logger.flush()
        #expect(FileManager.default.fileExists(atPath: logger.fileURL.path))

        logger.deleteLog()
        #expect(!FileManager.default.fileExists(atPath: logger.fileURL.path))
    }

    @Test("Reading nonexistent log returns nil")
    func readNonexistent() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)
        // Don't write anything, but logger creates an empty file
        logger.deleteLog()
        // Now the file doesn't exist
        let result = try? Data(contentsOf: logger.fileURL)
        #expect(result == nil)
    }

    @Test("ANSI escape sequences preserved in round-trip")
    func ansiPreservation() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let id = UUID()
        let logger = TestHistoryLogger(sessionID: id, baseDirectory: dir)

        // Simulated colored output: ESC[31mRed TextESC[0m
        let ansi: [UInt8] = Array("\u{1B}[31mRed Text\u{1B}[0m\r\n".utf8)
        logger.append(bytes: ansi[...])

        let result = logger.readLog()
        #expect(result == Data(ansi))
    }
}
