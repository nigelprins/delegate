import Foundation

public struct SecretFinding: Equatable, Sendable {
    public let kind: String
    public let redactedValue: String
}

public struct SecretScanner: Sendable {
    private let patterns: [(String, String)] = [
        ("Private key", #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#),
        ("OpenAI-style API key", #"\bsk-[A-Za-z0-9_-]{16,}\b"#),
        ("GitHub token", #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#),
        ("AWS access key", #"\bAKIA[0-9A-Z]{16}\b"#),
        ("xAI-style key", #"\bxai-[A-Za-z0-9_-]{16,}\b"#),
        ("Anthropic-style key", #"\bsk-ant-[A-Za-z0-9_-]{16,}\b"#),
        ("Credential assignment", #"(?i)\b(?:api[_-]?key|secret|password|token)\s*[:=]\s*['"]?[^\s'"]{8,}"#)
    ]

    public init() {}

    public func scan(_ text: String) -> [SecretFinding] {
        patterns.flatMap { pair -> [SecretFinding] in
            let (name, pattern) = pair
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(text.startIndex..., in: text)
            return regex.matches(in: text, range: range).compactMap { match in
                guard let swiftRange = Range(match.range, in: text) else { return nil }
                return SecretFinding(
                    kind: name,
                    redactedValue: redact(String(text[swiftRange]))
                )
            }
        }
    }

    private func redact(_ value: String) -> String {
        guard value.count > 8 else { return "••••" }
        return "\(value.prefix(4))…\(value.suffix(4))"
    }
}

public struct PolicyEngine: Sendable {
    private let scanner = SecretScanner()
    private let externalHosts = [
        "api.openai.com",
        "api.anthropic.com",
        "api.x.ai"
    ]
    private let blockedHosts = [
        "grok-code-session-traces",
        "storage.googleapis.com"
    ]
    private let blockedPathFragments = [
        "/v1/storage",
        "/storage",
        "session-trace",
        "session_trace",
        "codebase_upload",
        "telemetry",
        "trace_upload"
    ]

    public init() {}

    public func evaluate(_ envelope: AIRequestEnvelope) -> PolicyDecision {
        var hardBlocks: [String] = []
        var approvals: [String] = []
        let findings = scanner.scan(envelope.contentSample)
        let sensitivePaths = envelope.paths.filter(isSensitivePath)
        let inferredChannel = inferredChannel(for: envelope)

        if envelope.includesGitHistory {
            hardBlocks.append("Git history may not leave the device")
        }
        if inferredChannel == .storage || inferredChannel == .telemetry {
            hardBlocks.append("Repository/storage/telemetry upload channels are blocked")
        }
        if matchesBlockedHost(envelope.endpoint) {
            hardBlocks.append("Destination matches a blocked storage or telemetry host")
        }
        if matchesBlockedPath(envelope.endpoint) {
            hardBlocks.append("Endpoint path looks like a whole-repo or telemetry upload")
        }
        if !sensitivePaths.isEmpty {
            hardBlocks.append("Sensitive paths selected: \(sensitivePaths.joined(separator: ", "))")
        }
        if !findings.isEmpty {
            hardBlocks.append("Potential secrets detected")
        }
        if envelope.estimatedBytes > envelope.approvedBytes {
            hardBlocks.append("Transfer exceeds the approved data budget")
        }
        if envelope.fileCount > 50, envelope.purpose.lowercased().contains("review")
            || envelope.purpose.lowercased().contains("one file")
            || envelope.purpose.lowercased().contains("selected")
        {
            hardBlocks.append("File count (\(envelope.fileCount)) far exceeds the stated purpose")
        }
        if !isAllowedEndpoint(envelope.endpoint) {
            hardBlocks.append("Unknown or non-TLS destination")
        }
        if envelope.classification == .confidential || envelope.classification == .secret {
            approvals.append("Sensitive classification requires explicit approval")
        }
        if envelope.provider != .ollama && envelope.estimatedBytes > 1_000_000 {
            approvals.append("External transfer is larger than 1 MB")
        }
        if envelope.fileCount > 25 && inferredChannel == .model {
            approvals.append("Large file set requires explicit approval")
        }

        let reasons = hardBlocks + approvals
        let verdict: PolicyVerdict = if !hardBlocks.isEmpty {
            .deny
        } else if !approvals.isEmpty {
            .ask
        } else {
            .allow
        }
        return PolicyDecision(
            verdict: verdict,
            reasons: reasons.isEmpty ? ["Request fits the active local policy"] : reasons,
            redactions: findings.map(\.redactedValue)
        )
    }

    private func inferredChannel(for envelope: AIRequestEnvelope) -> TransferChannel {
        if envelope.channel != .unknown && envelope.channel != .model {
            return envelope.channel
        }
        let endpoint = envelope.endpoint.lowercased()
        if blockedPathFragments.contains(where: { endpoint.contains($0) }) {
            return .storage
        }
        if matchesBlockedHost(endpoint) {
            return .storage
        }
        return envelope.channel == .unknown ? .model : envelope.channel
    }

    private func matchesBlockedHost(_ endpoint: String) -> Bool {
        guard let host = URL(string: endpoint)?.host?.lowercased() else { return false }
        return blockedHosts.contains { host.contains($0) }
    }

    private func matchesBlockedPath(_ endpoint: String) -> Bool {
        let lower = endpoint.lowercased()
        return blockedPathFragments.contains { lower.contains($0) }
    }

    private func isSensitivePath(_ path: String) -> Bool {
        let normalized = path.lowercased().replacingOccurrences(of: "\\", with: "/")
        let component = URL(fileURLWithPath: normalized).lastPathComponent
        return normalized.contains("/.git/")
            || normalized.hasSuffix("/.git")
            || normalized.contains("/.ssh/")
            || normalized.contains("/.aws/")
            || normalized.contains("/.gnupg/")
            || normalized.contains("/.delegate/")
            || component == ".env"
            || component.hasPrefix(".env.")
            || component.contains("credential")
            || component.contains("private_key")
            || component == "id_rsa"
            || component == "id_ed25519"
            || component == "id_ecdsa"
            || component.hasSuffix(".pem")
            || component.hasSuffix(".p12")
            || component.hasSuffix(".key")
    }

    private func isAllowedEndpoint(_ endpoint: String) -> Bool {
        guard let url = URL(string: endpoint), let host = url.host?.lowercased() else {
            return false
        }
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }
        return url.scheme == "https" && externalHosts.contains(host)
    }
}
