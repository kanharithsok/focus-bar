import SwiftUI

struct BlockingStatusView: View {
    @Environment(AppModel.self) private var app

    private var status: BlockingEngine.Status {
        app.blockingEngine.status
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    SectionLabel(text: "Protection")
                    Spacer()
                    StatusPill(
                        text: status.isActive ? "Best effort" : "Off",
                        color: status.isActive ? .orange : .secondary
                    )
                }

                if status.isActive {
                    statusRow(
                        icon: "square.grid.2x2",
                        title: "Applications",
                        enabled: status.appBlockingEnabled,
                        detail: "\(status.appCount) selected · \(app.settings.settings.appBlockingAction.displayName.lowercased())"
                    )
                    statusRow(
                        icon: "safari",
                        title: "Browser tabs",
                        enabled: status.websiteBlockingEnabled,
                        detail: "\(status.browserNames.joined(separator: " + ")) · \(status.domainCount) domains"
                    )

                    if status.systemBlockingConfigured {
                        systemBlockingRow
                    }

                    if status.websiteBlockingEnabled
                        || status.browserPermission == .denied
                        || status.browserPermission == .timedOut {
                        permissionStatus
                    }

                    ForEach(status.notes, id: \.self) { note in
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("No blocking is active for this session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Best effort only. FocusBar cannot guarantee enforcement; background tabs, fast navigations, and quit requests can be missed or refused.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if status.systemBlockingConfigured {
                    Text("System-wide blocking uses /etc/hosts. VPNs, encrypted DNS, cached DNS, and IP-literal URLs can bypass it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var permissionStatus: some View {
        switch status.browserPermission {
        case .granted:
            Label("Automation access allowed.", systemImage: "checkmark.seal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Label("Automation access denied. Enable FocusBar in System Settings > Privacy & Security > Automation.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Open Settings") { app.openAutomationSettings() }
                        .buttonStyle(.link)
                        .font(.caption2)
                    Button("Retry") { app.blockingEngine.retryBrowserPermission() }
                        .buttonStyle(.link)
                        .font(.caption2)
                }
            }
        case .timedOut:
            VStack(alignment: .leading, spacing: 4) {
                Label("The browser didn't respond. Check for a macOS permission prompt.", systemImage: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { app.blockingEngine.retryBrowserPermission() }
                    .buttonStyle(.link)
                    .font(.caption2)
            }
        case .unknown:
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Automation permission hasn't been checked yet. Open Safari or Chrome, then check access.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check permission") { app.blockingEngine.retryBrowserPermission() }
                    .buttonStyle(.link)
                    .font(.caption2)
            }
        }
    }

    private var systemBlockingRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .frame(width: 14)
                    .foregroundStyle(systemBlockingColor)
                Text("All browsers")
                    .font(.caption)
                Spacer()
                Text(systemBlockingDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let message = systemBlockingMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var systemBlockingDetail: String {
        switch app.systemBlockingClient.sessionState {
        case .active(let count):
            return "\(count) hostnames"
        case .starting:
            return "Starting…"
        case .idle:
            return "Off"
        case .unavailable:
            return "Off · setup needed"
        case .failed:
            return "Error"
        }
    }

    private var systemBlockingMessage: String? {
        switch app.systemBlockingClient.sessionState {
        case .unavailable(let message), .failed(let message):
            return message
        default:
            return nil
        }
    }

    private var systemBlockingColor: Color {
        switch app.systemBlockingClient.sessionState {
        case .active:
            return .green
        case .starting, .unavailable, .failed:
            return .orange
        case .idle:
            return .secondary
        }
    }

    private func statusRow(icon: String, title: String, enabled: Bool, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .frame(width: 14)
                .foregroundStyle(enabled ? Color.green : Color.secondary)
            Text(title)
                .font(.caption)
            Spacer()
            Text(enabled ? detail : "Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
