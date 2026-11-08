import SwiftUI

struct EarlyEndView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var secondsRemaining = 20
    @State private var isEnding = false
    @State private var errorMessage: String?

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canEnd: Bool {
        secondsRemaining == 0 && !trimmedReason.isEmpty && !isEnding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("End this session early?")
                        .font(.headline)
                    Text("Take a breath. You can still continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let focus = app.sessionManager.activeSession?.focusObject {
                Text(focus)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("One-line reason")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Why are you ending early?", text: $reason)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if canEnd { end() } }
            }

            HStack(spacing: 8) {
                Image(systemName: secondsRemaining > 0 ? "hourglass" : "checkmark.circle")
                    .foregroundStyle(secondsRemaining > 0 ? Color.secondary : Color.green)
                Text(secondsRemaining > 0
                     ? "You can end the session in \(secondsRemaining)s."
                     : "You can end the session now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Keep focusing") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEnding ? "Ending…" : "End Session") { end() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canEnd)
            }

            Text("Ending early is saved as an early end. No guilt attached.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 380)
        .task {
            while secondsRemaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                secondsRemaining -= 1
            }
        }
    }

    private func end() {
        guard canEnd else { return }
        isEnding = true
        errorMessage = nil

        Task {
            defer { isEnding = false }
            do {
                try await app.sessionManager.endEarly(reason: trimmedReason, emergency: false)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
