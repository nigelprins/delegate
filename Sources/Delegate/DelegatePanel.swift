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
                    .fill(model.isPaused ? Color.orange.opacity(0.16) : Color.green.opacity(0.16))
                Image(systemName: model.isPaused ? "shield.slash.fill" : "checkmark.shield.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(model.isPaused ? .orange : .green)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Delegate")
                    .font(.headline)
                Text(model.isPaused ? "Protection paused" : "Local protection active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(model.isPaused ? "Resume" : "Pause") {
                model.toggleProtection()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
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
                    description: Text("Connect the browser extension or route an AI client through the local gateway.")
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
                Label("Secrets, Git history, credential files and unapproved upload growth are blocked.", systemImage: "lock.shield")
                Text("System-wide enforcement requires an Apple Network Extension entitlement. Configured clients and the isolated runner are enforced now.")
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
