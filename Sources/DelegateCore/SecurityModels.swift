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

public struct AIRequestEnvelope: Codable, Sendable {
    public var provider: AIProvider
    public var endpoint: String
    public var purpose: String
    public var paths: [String]
    public var contentSample: String
    public var estimatedBytes: Int
    public var approvedBytes: Int
    public var includesGitHistory: Bool
    public var classification: DataClassification

    public init(
        provider: AIProvider,
        endpoint: String,
        purpose: String,
        paths: [String],
        contentSample: String,
        estimatedBytes: Int,
        approvedBytes: Int,
        includesGitHistory: Bool,
        classification: DataClassification
    ) {
        self.provider = provider
        self.endpoint = endpoint
        self.purpose = purpose
        self.paths = paths
        self.contentSample = contentSample
        self.estimatedBytes = estimatedBytes
        self.approvedBytes = approvedBytes
        self.includesGitHistory = includesGitHistory
        self.classification = classification
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

    public init(envelope: AIRequestEnvelope, decision: PolicyDecision) {
        id = UUID()
        timestamp = Date()
        provider = envelope.provider
        purpose = envelope.purpose
        verdict = decision.verdict
        reasons = decision.reasons
        estimatedBytes = envelope.estimatedBytes
    }
}
