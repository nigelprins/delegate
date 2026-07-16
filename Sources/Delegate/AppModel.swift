import AppKit
import Combine
import DelegateCore
import Foundation

private struct VaultState: Codable {
    var events: [SecurityEvent]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var events: [SecurityEvent]
    @Published private(set) var isPaused = false
    @Published private(set) var isLockedDown = false
    @Published private(set) var gatewayError: String?

    let pairingToken: String
    let gatewayAddress = "http://127.0.0.1:\(LocalGateway.port)"

    private let vault = EncryptedVault()
    private let gateway: LocalGateway

    init() {
        let defaults = UserDefaults.standard
        if let storedToken = defaults.string(forKey: "pairingToken") {
            pairingToken = storedToken
        } else {
            let token = Self.makeToken()
            pairingToken = token
            defaults.set(token, forKey: "pairingToken")
        }
        events = []
        gateway = LocalGateway(pairingToken: pairingToken)
        gateway.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.record(event)
            }
        }
        do {
            try gateway.start()
            NSLog("Delegate gateway starting on %@", gatewayAddress)
        } catch {
            gatewayError = error.localizedDescription
            NSLog("Delegate gateway failed: %@", error.localizedDescription)
        }
        let vault = vault
        Task.detached { [weak self] in
            let state = try? vault.load(VaultState.self)
            await self?.restore(state?.events ?? [])
        }
    }

    func toggleProtection() {
        if isPaused {
            do {
                try gateway.start()
                isPaused = false
                gatewayError = nil
            } catch {
                gatewayError = error.localizedDescription
            }
        } else {
            gateway.stop()
            isPaused = true
        }
    }

    func toggleLockdown() {
        isLockedDown.toggle()
        gateway.setLockedDown(isLockedDown)
        if isLockedDown, isPaused {
            do {
                try gateway.start()
                isPaused = false
                gatewayError = nil
            } catch {
                gatewayError = error.localizedDescription
            }
        }
    }

    func copyPairingToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairingToken, forType: .string)
    }

    func clearEvents() {
        events = []
        persist()
    }

    var blockedCount: Int {
        events.filter { $0.verdict == .deny }.count
    }

    var protectedBytes: Int {
        events.filter { $0.verdict == .deny }.reduce(0) { $0 + $1.estimatedBytes }
    }

    private func record(_ event: SecurityEvent) {
        events.insert(event, at: 0)
        events = Array(events.prefix(250))
        persist()
    }

    private func persist() {
        let snapshot = events
        let vault = vault
        Task.detached {
            try? vault.save(VaultState(events: snapshot))
        }
    }

    private func restore(_ storedEvents: [SecurityEvent]) {
        guard events.isEmpty else { return }
        events = storedEvents
    }

    private static func makeToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
