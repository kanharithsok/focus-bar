import SwiftUI

struct ScatterfocusView: View {
    @Environment(AppModel.self) private var app

    private var session: ActiveSession? {
        app.sessionManager.activeSession
    }

    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Scatterfocus", systemImage: "leaf")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                    Spacer()
                    Text(app.sessionManager.remainingText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                if let mode = session.scatterfocusMode {
                    Text(mode.displayName)
                        .font(.title3.weight(.semibold))
                    Text(mode.guidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let question = session.problemQuestion {
                    Card {
                        Text(question)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ProgressView(value: app.sessionManager.progress)
                    .tint(.teal)

                Button("End break") {
                    Task { await app.sessionManager.endScatterfocusEarly() }
                }
                .buttonStyle(.bordered)
            }
        } else {
            Text("No active break")
                .foregroundStyle(.secondary)
        }
    }
}
