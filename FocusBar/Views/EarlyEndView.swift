import SwiftUI

struct EarlyEndView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var secondsRemaining: Int
    @State private var isEnding = false
    @State private var errorMessage: String?

    init(delaySeconds: Int) {
        _secondsRemaining = State(initialValue: max(0, delaySeconds))
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canEnd: Bool {
        secondsRemaining == 0 && !trimmedReason.isEmpty && !isEnding
    }

    private var endButtonTitle: String {
        if isEnding { return "Ending…" }
        if secondsRemaining > 0 { return "End in \(secondsRemaining)s" }
        return "End Session"
    }

    private var statusText: String {
        if secondsRemaining > 0 {
            return "You can end the session in \(secondsRemaining)s."
        }
        if trimmedReason.isEmpty {
            return "Enter a one-line reason to end the session."
        }
        return "You can end the session now."
    }

    private var statusIcon: String {
        if secondsRemaining > 0 { return "hourglass" }
        if trimmedReason.isEmpty { return "pencil.line" }
        return "checkmark.circle"
    }

    private var statusColor: Color {
        if secondsRemaining > 0 { return .orange }
        if trimmedReason.isEmpty { return .secondary }
        return .green
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
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .monospacedDigit()
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
                Button {
                    end()
                } label: {
                    Text(endButtonTitle)
                        .monospacedDigit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canEnd)
            }

            Text("Ending early is saved as an early end. No guilt attached.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
