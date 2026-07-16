import DelegateCore
import Foundation
import Network

final class LocalGateway: @unchecked Sendable {
    static let port: UInt16 = 43_121

    private let queue = DispatchQueue(label: "com.delegate.gateway")
    private let lock = NSLock()
    private let policy = PolicyEngine()
    private let pairingToken: String
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: HTTPConnection] = [:]
    private var isLockedDown = false
    var onEvent: (@Sendable (SecurityEvent) -> Void)?

    init(pairingToken: String) {
        self.pairingToken = pairingToken
    }

    func setLockedDown(_ locked: Bool) {
        lock.lock()
        isLockedDown = locked
        lock.unlock()
    }

    private var lockedDown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLockedDown
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: Self.port)!)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            let client = HTTPConnection(connection: connection) { request in
                self.handle(request)
            }
            let identifier = ObjectIdentifier(client)
            self.connections[identifier] = client
            client.onClose = { [weak self] in
                self?.connections.removeValue(forKey: identifier)
            }
            client.start(on: self.queue)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ request: HTTPRequest) -> HTTPResponse {
        if request.method == "OPTIONS" {
            return .empty(status: 204)
        }
        if request.method == "GET", request.path == "/health" {
            return .json(
                status: 200,
                body: [
                    "status": lockedDown ? "locked" : "protected",
                    "version": "0.2.0"
                ]
            )
        }
        guard request.headers["x-delegate-token"] == pairingToken else {
            return .json(status: 401, body: ["error": "Invalid pairing token"])
        }
        if request.method == "GET", request.path == "/v1/status" {
            return .json(
                status: 200,
                body: [
                    "status": lockedDown ? "locked" : "protected",
                    "gateway": "http://127.0.0.1:\(Self.port)"
                ]
            )
        }
        guard request.method == "POST", request.path == "/v1/evaluate" else {
            return .json(status: 404, body: ["error": "Unknown route"])
        }

        do {
            let envelope = try JSONDecoder().decode(AIRequestEnvelope.self, from: request.body)
            let locked = lockedDown
            let decision: PolicyDecision
            if locked {
                decision = PolicyDecision(
                    verdict: .deny,
                    reasons: ["Emergency lock: all AI transfers are denied"],
                    redactions: []
                )
            } else {
                decision = policy.evaluate(envelope)
            }
            onEvent?(SecurityEvent(envelope: envelope, decision: decision))
            let body = try JSONEncoder().encode(decision)
            return HTTPResponse(status: 200, body: body)
        } catch {
            return .json(status: 400, body: ["error": "Invalid request envelope"])
        }
    }
}

private struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

private struct HTTPResponse: Sendable {
    let status: Int
    let body: Data

    static func json(status: Int, body: [String: String]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        return HTTPResponse(status: status, body: data)
    }

    static func empty(status: Int) -> HTTPResponse {
        HTTPResponse(status: status, body: Data())
    }

    var encoded: Data {
        let reason = switch status {
        case 200: "OK"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        default: "Error"
        }
        let header = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Headers: Content-Type, X-Delegate-Token",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        return Data(header.utf8) + body
    }
}

private final class HTTPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let handler: @Sendable (HTTPRequest) -> HTTPResponse
    private var buffer = Data()
    var onClose: (@Sendable () -> Void)?

    init(
        connection: NWConnection,
        handler: @escaping @Sendable (HTTPRequest) -> HTTPResponse
    ) {
        self.connection = connection
        self.handler = handler
    }

    func start(on queue: DispatchQueue) {
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { self.buffer.append(data) }
            if let request = self.parseRequest() {
                let response = self.handler(request)
                self.connection.send(content: response.encoded, completion: .contentProcessed { _ in
                    self.connection.cancel()
                    self.onClose?()
                })
            } else if error == nil && !isComplete {
                self.receive()
            } else {
                self.connection.cancel()
                self.onClose?()
            }
        }
    }

    private func parseRequest() -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: separator),
              let headerText = String(data: buffer[..<headerRange.lowerBound], encoding: .utf8)
        else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            headers[String(parts[0]).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
        }

        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard buffer.count >= bodyStart + contentLength else { return nil }
        let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
        return HTTPRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: body
        )
    }
}
