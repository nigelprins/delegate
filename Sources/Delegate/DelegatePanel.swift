import DelegateCore
import SwiftUI

struct DelegatePanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            summary
            Divider()
            eventList
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                Image(systemName: statusIcon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Delegate")
                    .font(.headline)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(model.isLockedDown ? "Unlock" : "Block all") {
                model.toggleLockdown()
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isLockedDown ? .orange : .red)
            Button(model.isPaused ? "Resume" : "Pause") {
                model.toggleProtection()
            }
            .buttonStyle(.bordered)
            .disabled(model.isLockedDown)
        }
        .padding(16)
    }

    private var statusLabel: String {
        if model.isLockedDown { return "Emergency lock — all AI transfers denied" }
        if model.isPaused { return "Protection paused" }
        return "Local protection active"
    }

    private var statusIcon: String {
        if model.isLockedDown { return "lock.shield.fill" }
        if model.isPaused { return "shield.slash.fill" }
        return "checkmark.shield.fill"
    }

    private var statusColor: Color {
        if model.isLockedDown { return .red }
        if model.isPaused { return .orange }
        return .green
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.gatewayError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(spacing: 10) {
                MetricCard(
                    title: "Blocked",
                    value: "\(model.blockedCount)",
                    icon: "hand.raised.fill"
                )
                MetricCard(
                    title: "Data protected",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(model.protectedBytes),
                        countStyle: .file
                    ),
                    icon: "externaldrive.fill.badge.xmark"
                )
            }
            Label("Gateway: \(model.gatewayAddress)", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent decisions")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !model.events.isEmpty {
                    Button("Clear") { model.clearEvents() }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
            }

            if model.events.isEmpty {
                ContentUnavailableView(
                    "No traffic evaluated",
                    systemImage: "wave.3.right",
                    description: Text("Use the browser connector, agent runner, or tools/smoke_test.sh to exercise the gateway.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Label("Connections", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .padding(14)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EventRow: View {
    let event: SecurityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verdictIcon)
                .foregroundStyle(verdictColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.provider.displayName)
                        .font(.caption.weight(.semibold))
                    if event.channel != .model && event.channel != .unknown {
                        Text(event.channel.rawValue.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Text("· \(event.purpose)")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(event.reasons.first ?? "Evaluated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(9)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var verdictIcon: String {
        switch event.verdict {
        case .allow: "checkmark.circle.fill"
        case .ask: "questionmark.circle.fill"
        case .deny: "xmark.octagon.fill"
        }
    }

    private var verdictColor: Color {
        switch event.verdict {
        case .allow: .green
        case .ask: .orange
        case .deny: .red
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Local gateway") {
                LabeledContent("Address", value: model.gatewayAddress)
                HStack {
                    LabeledContent("Pairing token", value: maskedToken)
                    Button("Copy") { model.copyPairingToken() }
                }
            }
            Section("Security boundary") {
                Label("Secrets, Git history, credential files, storage/telemetry uploads and unapproved growth are blocked.", systemImage: "lock.shield")
                Text("Block all keeps the gateway up and denies every transfer. System-wide process visibility still needs Apple Endpoint Security and Network Extension entitlements.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var maskedToken: String {
        "\(model.pairingToken.prefix(4))••••\(model.pairingToken.suffix(4))"
    }
}
