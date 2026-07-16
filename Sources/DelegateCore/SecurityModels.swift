import Foundation

public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case xAI
    case ollama
    case custom

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .xAI: "xAI"
        case .ollama: "Ollama"
        case .custom: "Custom"
        }
    }
}

public enum DataClassification: String, Codable, CaseIterable, Sendable {
    case publicData
    case internalData
    case confidential
    case secret
}

public enum TransferChannel: String, Codable, CaseIterable, Sendable {
    case model
    case storage
    case telemetry
    case unknown
}

public struct AIRequestEnvelope: Codable, Sendable {
    public var sessionId: String?
    public var provider: AIProvider
    public var endpoint: String
    public var purpose: String
    public var paths: [String]
    public var contentSample: String
    public var estimatedBytes: Int
    public var approvedBytes: Int
    public var includesGitHistory: Bool
    public var classification: DataClassification
    public var channel: TransferChannel
    public var fileCount: Int

    public init(
        sessionId: String? = nil,
        provider: AIProvider,
        endpoint: String,
        purpose: String,
        paths: [String],
        contentSample: String,
        estimatedBytes: Int,
        approvedBytes: Int,
        includesGitHistory: Bool,
        classification: DataClassification,
        channel: TransferChannel = .model,
        fileCount: Int = 0
    ) {
        self.sessionId = sessionId
        self.provider = provider
        self.endpoint = endpoint
        self.purpose = purpose
        self.paths = paths
        self.contentSample = contentSample
        self.estimatedBytes = estimatedBytes
        self.approvedBytes = approvedBytes
        self.includesGitHistory = includesGitHistory
        self.classification = classification
        self.channel = channel
        self.fileCount = fileCount > 0 ? fileCount : paths.count
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        provider = try container.decode(AIProvider.self, forKey: .provider)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        purpose = try container.decode(String.self, forKey: .purpose)
        paths = try container.decodeIfPresent([String].self, forKey: .paths) ?? []
        contentSample = try container.decodeIfPresent(String.self, forKey: .contentSample) ?? ""
        estimatedBytes = try container.decode(Int.self, forKey: .estimatedBytes)
        approvedBytes = try container.decode(Int.self, forKey: .approvedBytes)
        includesGitHistory = try container.decodeIfPresent(Bool.self, forKey: .includesGitHistory) ?? false
        classification = try container.decodeIfPresent(
            DataClassification.self,
            forKey: .classification
        ) ?? .internalData
        channel = try container.decodeIfPresent(TransferChannel.self, forKey: .channel) ?? .model
        let decodedCount = try container.decodeIfPresent(Int.self, forKey: .fileCount) ?? 0
        fileCount = decodedCount > 0 ? decodedCount : paths.count
    }
}

public struct SessionStartRequest: Codable, Sendable {
    public var purpose: String
    public var approvedBytes: Int
    public var maxFiles: Int
    public var roots: [String]

    public init(purpose: String, approvedBytes: Int, maxFiles: Int, roots: [String] = []) {
        self.purpose = purpose
        self.approvedBytes = approvedBytes
        self.maxFiles = maxFiles
        self.roots = roots
    }
}

public struct SessionStartResponse: Codable, Sendable {
    public var sessionId: String
    public var approvedBytes: Int
    public var maxFiles: Int
    public var remainingBytes: Int

    public init(sessionId: String, approvedBytes: Int, maxFiles: Int, remainingBytes: Int) {
        self.sessionId = sessionId
        self.approvedBytes = approvedBytes
        self.maxFiles = maxFiles
        self.remainingBytes = remainingBytes
    }
}

public enum PolicyVerdict: String, Codable, Sendable {
    case allow
    case ask
    case deny
}

public struct PolicyDecision: Codable, Sendable {
    public var verdict: PolicyVerdict
    public var reasons: [String]
    public var redactions: [String]

    public init(verdict: PolicyVerdict, reasons: [String], redactions: [String]) {
        self.verdict = verdict
        self.reasons = reasons
        self.redactions = redactions
    }
}

public struct SecurityEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let provider: AIProvider
    public let purpose: String
    public let verdict: PolicyVerdict
    public let reasons: [String]
    public let estimatedBytes: Int
    public let channel: TransferChannel

    public init(envelope: AIRequestEnvelope, decision: PolicyDecision) {
        id = UUID()
        timestamp = Date()
        provider = envelope.provider
        purpose = envelope.purpose
        verdict = decision.verdict
        reasons = decision.reasons
        estimatedBytes = envelope.estimatedBytes
        channel = envelope.channel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        provider = try container.decode(AIProvider.self, forKey: .provider)
        purpose = try container.decode(String.self, forKey: .purpose)
        verdict = try container.decode(PolicyVerdict.self, forKey: .verdict)
        reasons = try container.decode([String].self, forKey: .reasons)
        estimatedBytes = try container.decode(Int.self, forKey: .estimatedBytes)
        channel = try container.decodeIfPresent(TransferChannel.self, forKey: .channel) ?? .unknown
    }
}
