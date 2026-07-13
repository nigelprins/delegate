import NetworkExtension
import os

/// Privileged enforcement layer. This target intentionally remains outside the
/// unsigned Swift package until a Network Extension entitlement is available.
final class FilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "com.delegate.network-filter", category: "flows")
    private let knownAIHosts: Set<String> = [
        "api.openai.com",
        "api.anthropic.com",
        "api.x.ai",
        "chatgpt.com",
        "claude.ai",
        "grok.com"
    ]

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.notice("Delegate network filter started")
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        logger.notice("Delegate network filter stopped: \(reason.rawValue)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let socketFlow = flow as? NEFilterSocketFlow,
              let endpoint = socketFlow.remoteEndpoint as? NWHostEndpoint
        else {
            return .filterDataVerdict(withFilterInbound: false, peekInboundBytes: 0)
        }

        let host = endpoint.hostname.lowercased()
        if knownAIHosts.contains(host) {
            // Peek outbound data so the signed build can enforce per-flow byte budgets.
            // TLS content remains private; payload inspection belongs in LocalGateway.
            return .filterDataVerdict(
                withFilterInbound: false,
                peekInboundBytes: 0,
                filterOutbound: true,
                peekOutboundBytes: 64 * 1024
            )
        }
        return .allow()
    }

    override func handleOutboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        // The production target reads the approved byte budget from an App Group.
        // Fail closed when an AI flow exceeds that budget.
        let approvedBytes = flow.metaData.sourceAppAuditToken != nil ? 1_048_576 : 0
        let observedBytes = offset + readBytes.count
        if observedBytes > approvedBytes {
            logger.error("Blocked AI flow after \(observedBytes) outbound bytes")
            return .drop()
        }
        return .needRules()
    }
}
