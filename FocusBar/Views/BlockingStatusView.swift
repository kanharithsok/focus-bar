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
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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
            Text("Browser Automation permission hasn't been checked yet.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
