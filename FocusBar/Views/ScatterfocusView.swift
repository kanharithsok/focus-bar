import SwiftUI

struct ScatterfocusView: View {
    @Environment(AppModel.self) private var app

    private var session: ActiveSession? {
        app.sessionManager.activeSession
    }

    private var mode: ScatterfocusMode {
        session?.scatterfocusMode ?? .capture
    }

    private var blockingEnabledForBreaks: Bool {
        app.settings.settings.blockDuringScatterfocus
    }

    private var keepBlockingBinding: Binding<Bool> {
        Binding(
            get: { !(app.sessionManager.activeSession?.blockingSuspended ?? false) },
            set: { keepBlocking in
                Task {
                    try? await app.sessionManager.setBlockingSuspended(!keepBlocking)
                }
            }
        )
    }

    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Scatterfocus", systemImage: mode.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                    Spacer()
                    Text(app.sessionManager.remainingText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("\(app.sessionManager.remainingText) remaining")
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.displayName)
                        .font(.title3.weight(.semibold))
                    Text(mode.guidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProgressView(value: app.sessionManager.progress)
                    .tint(.teal)

                switch mode {
                case .capture:
                    CapturePad(
                        sessionID: session.id,
                        source: .scatterfocus,
                        placeholder: "Let a thought land here…"
                    )

                case .problemCrunching:
                    if let question = session.problemQuestion {
                        Card {
                            VStack(alignment: .leading, spacing: 3) {
                                SectionLabel(text: "Question")
                                Text(question)
                                    .font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    CapturePad(
                        sessionID: session.id,
                        source: .problemCrunching,
                        placeholder: "Ideas, fragments, connections…"
                    )

                case .habitual:
                    habitualIdeas
                }

                breakBlockingCard

                BlockingStatusView()

                HStack {
                    Button("End break") {
                        Task { await app.sessionManager.endScatterfocusEarly() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Text("Started \(session.startDate, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("No active break")
                .foregroundStyle(.secondary)
        }
    }

    private var habitualIdeas: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Low-demand ideas")
                Text("No scratchpad here. Let the mind wander without another task.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(["Take a short walk", "Wash the dishes", "Stretch", "Doodle"], id: \.self) { idea in
                        HStack(spacing: 7) {
                            Image(systemName: "circle")
                                .font(.system(size: 7))
                                .foregroundStyle(.teal)
                            Text(idea)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var breakBlockingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "Break blocking")

                if blockingEnabledForBreaks {
                    Toggle("Keep blocking during this break", isOn: keepBlockingBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.caption)
                    Text(session?.blockingSuspended == true
                         ? "Blocking is suspended for this break. Best-effort protection is off."
                         : "Social-media blocking stays on by default so a break doesn't become a scroll session. Best effort only.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("Blocking is off during breaks in Settings.", systemImage: "shield.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
