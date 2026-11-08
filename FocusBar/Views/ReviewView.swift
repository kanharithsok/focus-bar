import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var app

    @State private var rating: Int?
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didInitialize = false

    private var record: SessionRecord? {
        app.sessionManager.pendingReview
    }

    var body: some View {
        if let record {
            VStack(alignment: .leading, spacing: 14) {
                Label(record.kind == .hyperfocus ? "Hyperfocus complete" : "Break complete",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(record.kind == .hyperfocus ? .orange : .teal)

                Text(record.focusObject)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPill(
                        text: record.status.displayName,
                        color: record.status == .completed ? .green : .secondary
                    )
                    Text("\(SessionTimer.roundedMinutes(record.actualDuration)) min")
                    if let mode = record.scatterfocusMode {
                        Text("· \(mode.displayName)")
                    }
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let intention = record.intentionText {
                    Label(intention, systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let reason = record.earlyEndReason, record.status != .completed {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if record.kind == .hyperfocus {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How focused were you?")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    rating = rating == value ? nil : value
                                } label: {
                                    Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(value) out of 5")
                            }
                            Text(rating.map { "\($0) / 5" } ?? "Optional")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Optional: what helped or got in the way?")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $note)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(2)
                    }
                    .frame(minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.09))
                    )
                }

                capturesSection(for: record)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                VStack(spacing: 8) {
                    Button {
                        save(record: record, startBreak: false)
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(record.kind == .hyperfocus ? "Save Session" : "Done")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(record.kind == .hyperfocus ? .orange : .teal)
                    .disabled(isSaving)

                    if record.kind == .hyperfocus {
                        Button("Save & take a Scatterfocus break") {
                            save(record: record, startBreak: true)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving)
                    }

                    Button("Skip review") {
                        skip(record: record)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .disabled(isSaving)
                }

                Text("A missed session or a low rating is just information, never a verdict.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onAppear {
                guard !didInitialize else { return }
                didInitialize = true
                rating = record.rating
                note = record.note ?? ""
            }
            .onChange(of: record.id) { _, _ in
                rating = record.rating
                note = record.note ?? ""
                didInitialize = true
            }
        } else {
            Text("Nothing to review")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func capturesSection(for record: SessionRecord) -> some View {
        let captures = app.captures.captures(for: record.id)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Captured during this session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !captures.isEmpty {
                    Text("\(captures.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if captures.isEmpty {
                Text("Nothing parked. That's okay.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(captures) { capture in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: captureIcon(capture.source))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            Text(capture.text)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
            }
        }
    }

    private func captureIcon(_ source: CaptureSource) -> String {
        switch source {
        case .distraction: return "tray.and.arrow.down"
        case .scatterfocus: return "leaf"
        case .problemCrunching: return "puzzlepiece"
        }
    }

    private func save(record: SessionRecord, startBreak: Bool) {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                try await app.sessionManager.submitReview(
                    rating: record.kind == .hyperfocus ? rating : nil,
                    note: note,
                    startBreakAfter: startBreak
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func skip(record: SessionRecord) {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                try await app.sessionManager.submitReview(
                    rating: nil,
                    note: note,
                    startBreakAfter: false
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
