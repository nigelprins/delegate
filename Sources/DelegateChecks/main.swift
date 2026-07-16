import DelegateCore
import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("PASS  \(message)")
        return true
    } else {
        print("FAIL  \(message)")
        return false
    }
}

private func envelope(
    provider: AIProvider,
    endpoint: String,
    paths: [String] = [],
    content: String = "Public release notes",
    bytes: Int = 200,
    approvedBytes: Int = 500,
    gitHistory: Bool = false,
    channel: TransferChannel = .model,
    fileCount: Int = 0,
    purpose: String = "Security check"
) -> AIRequestEnvelope {
    AIRequestEnvelope(
        provider: provider,
        endpoint: endpoint,
        purpose: purpose,
        paths: paths,
        contentSample: content,
        estimatedBytes: bytes,
        approvedBytes: approvedBytes,
        includesGitHistory: gitHistory,
        classification: .internalData,
        channel: channel,
        fileCount: fileCount
    )
}

let engine = PolicyEngine()

let local = engine.evaluate(envelope(
    provider: .ollama,
    endpoint: "http://127.0.0.1:11434/api/chat"
))

let history = engine.evaluate(envelope(
    provider: .xAI,
    endpoint: "https://api.x.ai/v1/responses",
    gitHistory: true
))

let secret = engine.evaluate(envelope(
    provider: .anthropic,
    endpoint: "https://api.anthropic.com/v1/messages",
    paths: ["/project/.env"],
    content: "API_KEY=DELEGATE_TEST_CANARY_123456789"
))

let growth = engine.evaluate(envelope(
    provider: .custom,
    endpoint: "https://telemetry.example.com/upload",
    bytes: 5_000_000,
    approvedBytes: 1_000
))

let storage = engine.evaluate(envelope(
    provider: .xAI,
    endpoint: "https://api.x.ai/v1/storage",
    channel: .storage,
    fileCount: 298,
    purpose: "Reply OK, do not read any files"
))

let pathUpload = engine.evaluate(envelope(
    provider: .xAI,
    endpoint: "https://api.x.ai/v1/responses?trace_upload=1",
    fileCount: 1,
    purpose: "Review one file"
))

let fileExplosion = engine.evaluate(envelope(
    provider: .xAI,
    endpoint: "https://api.x.ai/v1/responses",
    fileCount: 298,
    purpose: "Review one file"
))

let results = [
    check(local.verdict == .allow, "small local-model request is allowed"),
    check(history.verdict == .deny, "Git history is denied"),
    check(secret.verdict == .deny, "credential files and secret patterns are denied"),
    check(!secret.redactions.isEmpty, "secret values are represented only as redactions"),
    check(growth.verdict == .deny, "unknown endpoints and upload growth are denied"),
    check(storage.verdict == .deny, "explicit storage channel uploads are denied"),
    check(pathUpload.verdict == .deny, "telemetry-style upload paths are denied"),
    check(fileExplosion.verdict == .deny, "file-count explosion beyond stated purpose is denied")
]
let failures = results.filter { !$0 }.count

if failures > 0 {
    print("\n\(failures) policy checks failed")
    exit(1)
}
print("\nAll Delegate policy checks passed")
