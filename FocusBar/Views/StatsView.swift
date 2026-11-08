import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var sessions: [SessionRecord] {
        app.stats.sessions
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session history")
                        .font(.title3.weight(.semibold))
                    Text("Saved locally on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No sessions yet")
                        .font(.headline)
                    Text("Start a Hyperfocus session from the menu bar and it will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { session in
                            SessionHistoryRow(record: session)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(width: 620, height: 560)
    }
}

private struct SessionHistoryRow: View {
    @Environment(AppModel.self) private var app
    let record: SessionRecord

    private var captures: [Capture] {
        app.captures.captures(for: record.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: record.kind == .hyperfocus ? "timer" : "leaf")
                    .font(.caption)
                    .foregroundStyle(record.kind == .hyperfocus ? .orange : .teal)
                Text(record.focusObject)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text("\(SessionTimer.roundedMinutes(record.actualDuration)) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(record.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                StatusPill(
                    text: record.status.displayName,
                    color: record.status == .completed ? .green : .secondary
                )

                if let mode = record.scatterfocusMode {
                    Text(mode.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let rating = record.rating {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { value in
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }
                    }
                    .accessibilityLabel("\(rating) out of 5")
                }

                if !captures.isEmpty {
                    Label("\(captures.count)", systemImage: "tray.and.arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let intention = record.intentionText {
                Label(intention, systemImage: "target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let reason = record.earlyEndReason, record.status != .completed {
                Text("Reason: \(reason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !captures.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(captures.prefix(4)) { capture in
                        HStack(alignment: .top, spacing: 5) {
                            Text("·")
                            Text(capture.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    if captures.count > 4 {
                        Text("+ \(captures.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
