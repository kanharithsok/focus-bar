import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showAllAttempts = false

    private var now: Date { Date() }

    private var sessions: [SessionRecord] {
        app.stats.sessions
    }

    private var ratedCount: Int {
        app.stats.hyperfocusSessions.filter { $0.rating != nil }.count
    }

    private var displayedAttempts: [BlockedAttempt] {
        showAllAttempts
            ? app.blockedAttempts.attempts
            : Array(app.blockedAttempts.attempts.prefix(8))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Attention statistics")
                        .font(.title3.weight(.semibold))
                    Text("Derived from saved session history · local only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricsGrid
                    chartCard
                    blockedAttemptsCard
                    historySection
                }
                .padding(16)
            }
        }
        .frame(width: 640, height: 660)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            MetricCard(
                title: "Today",
                value: formatMinutes(app.stats.focusMinutes(on: now)),
                subtitle: "Hyperfocus time"
            )
            MetricCard(
                title: "This week",
                value: formatMinutes(app.stats.weekFocusMinutes(now: now)),
                subtitle: "Calendar week"
            )
            MetricCard(
                title: "Average focus quality",
                value: app.stats.averageRating.map { String(format: "%.1f / 5", $0) } ?? "—",
                subtitle: "\(ratedCount) rated session\(ratedCount == 1 ? "" : "s")"
            )
            MetricCard(
                title: "Blocked attempts",
                value: "\(app.blockedAttempts.weekCount(now: now))",
                subtitle: "This week · \(app.blockedAttempts.totalCount) all time"
            )
        }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Focus minutes · last 7 days")
                    Spacer()
                    Text("\(formatMinutes(app.stats.dailyFocus(lastDays: 7, now: now).reduce(0) { $0 + $1.minutes }))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart(app.stats.dailyFocus(lastDays: 7, now: now)) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 140)
                .accessibilityLabel("Focus minutes over the last seven days")
                .accessibilityValue(
                    app.stats.dailyFocus(lastDays: 7, now: now)
                        .map { "\($0.minutes.rounded()) minutes" }
                        .joined(separator: ", ")
                )
            }
        }
    }

    private var blockedAttemptsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    SectionLabel(text: "Blocked attempts")
                    Spacer()
                    StatusPill(text: "Best effort", color: .orange)
                }

                if app.blockedAttempts.attempts.isEmpty {
                    Text("No blocked attempts recorded. FocusBar only records a match when a blocker actually detects one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(displayedAttempts) { attempt in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: attempt.kind == .application ? "square.grid.2x2" : "safari")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(attempt.displayName)
                                        .font(.caption)
                                    if let detail = attempt.actionDetail {
                                        Text(detail)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Text(attempt.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if app.blockedAttempts.attempts.count > 8 {
                            Button(showAllAttempts
                                   ? "Show less"
                                   : "Show all \(app.blockedAttempts.attempts.count)") {
                                showAllAttempts.toggle()
                            }
                            .buttonStyle(.link)
                            .font(.caption2)
                        }
                    }
                }

                Text("Only app bundle identifiers or hostnames are stored. FocusBar never stores full URLs, paths, query strings, or page content.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Sessions")
                Spacer()
                if !sessions.isEmpty {
                    Text("\(sessions.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if sessions.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("No sessions yet")
                            .font(.callout.weight(.medium))
                        Text("Start a Hyperfocus session from the menu bar and it will appear here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        SessionHistoryRow(record: session)
                        if session.id != sessions.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07))
                )
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        if rounded < 60 { return "\(rounded) min" }
        let hours = rounded / 60
        let remainder = rounded % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        )
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
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Text(record.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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
                        .accessibilityLabel("\(captures.count) captures")
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
