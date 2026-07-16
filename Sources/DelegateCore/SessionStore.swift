import Foundation

public struct DelegateSession: Sendable {
    public let id: String
    public let purpose: String
    public let approvedBytes: Int
    public let maxFiles: Int
    public let roots: [String]
    public var usedBytes: Int
    public var usedFiles: Int

    public var remainingBytes: Int { max(0, approvedBytes - usedBytes) }
    public var remainingFiles: Int { max(0, maxFiles - usedFiles) }
}

public final class SessionStore: @unchecked Sendable {
    public static let defaultByteCeiling = 512_000
    public static let absoluteByteCeiling = 5_000_000
    public static let defaultMaxFiles = 40
    public static let absoluteMaxFiles = 250

    private let lock = NSLock()
    private var sessions: [String: DelegateSession] = [:]

    public init() {}

    public func create(from request: SessionStartRequest) -> SessionStartResponse {
        let approved = clamp(
            request.approvedBytes,
            lower: 1_024,
            upper: Self.absoluteByteCeiling,
            fallback: Self.defaultByteCeiling
        )
        let maxFiles = clamp(
            request.maxFiles,
            lower: 1,
            upper: Self.absoluteMaxFiles,
            fallback: Self.defaultMaxFiles
        )
        let session = DelegateSession(
            id: UUID().uuidString.lowercased(),
            purpose: request.purpose,
            approvedBytes: approved,
            maxFiles: maxFiles,
            roots: request.roots,
            usedBytes: 0,
            usedFiles: 0
        )
        lock.lock()
        sessions[session.id] = session
        lock.unlock()
        return SessionStartResponse(
            sessionId: session.id,
            approvedBytes: session.approvedBytes,
            maxFiles: session.maxFiles,
            remainingBytes: session.remainingBytes
        )
    }

    public func prepare(_ envelope: AIRequestEnvelope) -> (AIRequestEnvelope, [String]) {
        var prepared = envelope
        var extraDenies: [String] = []

        lock.lock()
        defer { lock.unlock() }

        if let sessionId = envelope.sessionId, let session = sessions[sessionId] {
            prepared.approvedBytes = session.remainingBytes
            if envelope.fileCount > session.remainingFiles {
                extraDenies.append(
                    "Session file budget exceeded (\(envelope.fileCount) > \(session.remainingFiles) remaining)"
                )
            }
            if !session.roots.isEmpty {
                let outside = envelope.paths.filter { path in
                    !session.roots.contains { root in
                        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
                    }
                }
                if !outside.isEmpty {
                    extraDenies.append("Paths outside the approved session roots")
                }
            }
        } else {
            // Client-equalized budgets are treated as "no real budget proposed".
            let proposed = envelope.approvedBytes
            let looksSelfAttested = proposed >= envelope.estimatedBytes && envelope.estimatedBytes > 0
            prepared.approvedBytes = looksSelfAttested
                ? Self.defaultByteCeiling
                : min(max(proposed, 0), Self.defaultByteCeiling)
        }
        return (prepared, extraDenies)
    }

    public func commit(_ envelope: AIRequestEnvelope, allowed: Bool) {
        guard allowed, let sessionId = envelope.sessionId else { return }
        lock.lock()
        defer { lock.unlock() }
        guard var session = sessions[sessionId] else { return }
        session.usedBytes += max(0, envelope.estimatedBytes)
        session.usedFiles += max(0, envelope.fileCount)
        sessions[sessionId] = session
    }

    private func clamp(_ value: Int, lower: Int, upper: Int, fallback: Int) -> Int {
        let candidate = value > 0 ? value : fallback
        return min(max(candidate, lower), upper)
    }
}
