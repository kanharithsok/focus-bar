import SwiftUI

struct HyperfocusView: View {
    @Environment(AppModel.self) private var app

    @State private var showEarlyEnd = false

    private var session: ActiveSession? {
        app.sessionManager.activeSession
    }

    private var commitMode: Bool {
        app.settings.settings.commitMode
    }

    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Hyperfocus", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(app.sessionManager.remainingText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityLabel("\(app.sessionManager.remainingText) remaining")
                }

                Text(session.focusObject)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let intention = session.intentionText {
                    Label(intention, systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: app.sessionManager.progress)
                    .tint(.orange)

                HStack {
                    Text("\(Int(session.plannedDuration / 60)) min planned")
                    Spacer()
                    Text("Started \(session.startDate, style: .time)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if let blocklist = session.blocklistName {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                        Text("Blocklist: \(blocklist)")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                if commitMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Commit mode is on", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("The normal early-end action is hidden. An emergency stop remains available and is recorded as an emergency stop.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Emergency stop…") {
                            Task { await app.emergencyStop() }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                } else {
                    HStack {
                        Button("End early…") {
                            showEarlyEnd = true
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button("Emergency stop…") {
                            Task { await app.emergencyStop() }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Text("FocusBar cannot prevent force quitting or restarting your Mac.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .sheet(isPresented: $showEarlyEnd) {
                EarlyEndView()
                    .environment(app)
            }
        } else {
            Text("No active session")
                .foregroundStyle(.secondary)
        }
    }
}
