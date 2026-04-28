import Network
import Foundation
import Darwin

/// Minimal TCP server that probes `portRange` (starting at `defaultPort`) for
/// an available port, binds the first free one, and dispatches parsed HookEvent
/// values to a handler closure. The resolved port is stored in `activePort`
/// (mirrored as `OCAK_HOOK_PORT`); clients should read `activePort` to discover
/// the runtime port rather than assuming `defaultPort`.
final class HookServer {
    static let defaultPort: UInt16 = 27832
    static let portRange: ClosedRange<UInt16> = 27832...27931

    /// Resolved port of the most recently started HookServer. Read by clients
    /// (e.g. TerminalManager) that need to advertise the active port to child
    /// processes via the `OCAK_HOOK_PORT` environment variable.
    static private(set) var activePort: UInt16?

    private(set) var port: UInt16 = 0
    private var listener: NWListener?
    var onEvent: ((HookEvent) -> Void)?

    enum StartError: Error { case noAvailablePort }

    func start() throws {
        for candidate in Self.portRange where Self.isPortAvailable(candidate) {
            do {
                let params = NWParameters.tcp
                let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: candidate)!)
                let semaphore = DispatchSemaphore(value: 0)
                var listenerReady = false
                listener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        listenerReady = true
                        semaphore.signal()
                    case .failed(let error):
                        print("[HookServer] listener failed on port \(candidate): \(error)")
                        listener.cancel()
                        self?.listener = nil
                        self?.port = 0
                        Self.activePort = nil
                        semaphore.signal()
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                listener.start(queue: .global(qos: .utility))
                semaphore.wait()
                guard listenerReady else {
                    listener.cancel()
                    continue
                }
                self.listener = listener
                self.port = candidate
                Self.activePort = candidate
                if candidate != Self.defaultPort {
                    print("[HookServer] default port \(Self.defaultPort) unavailable; bound to \(candidate)")
                }
                return
            } catch {
                print("[HookServer] failed to bind \(candidate): \(error)")
                continue
            }
        }
        throw StartError.noAvailablePort
    }

    func stop() {
        listener?.cancel()
        listener = nil
        if Self.activePort == port { Self.activePort = nil }
        port = 0
    }

    /// Synchronously checks whether `port` can be bound on 127.0.0.1.
    /// Uses a short-lived POSIX socket so we can race ahead of NWListener's
    /// async failure reporting.
    static func isPortAvailable(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var yes: Int32 = 0
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let size = socklen_t(MemoryLayout<sockaddr_in>.size)

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, size)
            }
        }
        return result == 0
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data, !data.isEmpty else { return }

            // Send 200 OK regardless of parse result
            let response = Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
            connection.send(content: response, completion: .idempotent)

            let (headers, body) = Self.parseRequest(from: data)
            guard let body else { return }

            guard var event = try? JSONDecoder().decode(HookEvent.self, from: body) else { return }

            // Read session ID from X-Ocak-Session header instead of the JSON body
            event.ocakSessionId = Self.headerValue(named: "x-ocak-session", in: headers)

            DispatchQueue.main.async { self?.onEvent?(event) }
        }
    }

    /// Split raw HTTP data into header string and body data.
    private static func parseRequest(from data: Data) -> (headers: String, body: Data?) {
        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        guard let range = data.range(of: separator) else { return ("", nil) }
        let headers = String(data: data.subdata(in: data.startIndex..<range.lowerBound), encoding: .utf8) ?? ""
        let body = data.subdata(in: range.upperBound..<data.endIndex)
        return (headers, body)
    }

    /// Case-insensitive header value lookup from raw HTTP header text.
    private static func headerValue(named name: String, in headers: String) -> String? {
        let lowered = name.lowercased()
        for line in headers.components(separatedBy: "\r\n") {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
            if key == lowered {
                return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
