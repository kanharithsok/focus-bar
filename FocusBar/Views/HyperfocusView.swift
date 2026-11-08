import SwiftUI

struct HyperfocusView: View {
    @Environment(AppModel.self) private var app

    private var session: ActiveSession? {
        app.sessionManager.activeSession
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
            }
        } else {
            Text("No active session")
                .foregroundStyle(.secondary)
        }
    }
}
