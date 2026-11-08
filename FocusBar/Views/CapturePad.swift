import SwiftUI

struct CapturePad: View {
    @Environment(AppModel.self) private var app

    let sessionID: UUID
    let source: CaptureSource
    let placeholder: String

    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var saved: [Capture] {
        app.captures.captures(for: sessionID, source: source)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(2)
            }
            .frame(minHeight: 86)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09))
            )

            HStack {
                Text("\(saved.count) saved")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(isSaving ? "Saving…" : "Save thought") {
                    save()
                }
                .buttonStyle(.bordered)
                .disabled(trimmedText.isEmpty || isSaving)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if !saved.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(saved.suffix(6).reversed()) { capture in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "leaf")
                                .font(.system(size: 8))
                                .foregroundStyle(.teal)
                                .padding(.top, 3)
                            Text(capture.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.teal.opacity(0.05))
                )
            }
        }
    }

    private func save() {
        guard !trimmedText.isEmpty, !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            await app.captures.add(
                text: trimmedText,
                sessionID: sessionID,
                source: source
            )
            if app.captures.lastError != nil {
                errorMessage = app.captures.lastError
            } else {
                text = ""
            }
        }
    }
}
