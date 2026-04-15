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

            guard let body = Self.parseBody(from: data) else { return }

            guard let event = try? JSONDecoder().decode(HookEvent.self, from: body) else { return }

            DispatchQueue.main.async { self?.onEvent?(event) }
        }
    }

    /// Extract HTTP body by splitting on \r\n\r\n header/body separator.
    private static func parseBody(from data: Data) -> Data? {
        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        guard let range = data.range(of: separator) else { return nil }
        return data.subdata(in: range.upperBound..<data.endIndex)
    }
}
