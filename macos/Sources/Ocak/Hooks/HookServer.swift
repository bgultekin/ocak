import Network
import Foundation

/// Minimal TCP server that accepts HTTP POST requests on a fixed port
/// and dispatches parsed HookEvent values to a handler closure.
final class HookServer {
    static let port: UInt16 = 27832
    private var listener: NWListener?
    var onEvent: ((HookEvent) -> Void)?

    func start() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("[HookServer] listener failed: \(error)")
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
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
