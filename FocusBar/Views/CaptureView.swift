import SwiftUI

struct CaptureView: View {
    let focusObject: String?
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                    .foregroundStyle(.orange)
                Text("Park a distraction")
                    .font(.headline)
                Spacer()
                Text("⏎ save · esc cancel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let focusObject {
                Text(focusObject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("What pulled your attention?", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)

            HStack {
                Text("Saved locally. Linked to the active session when there is one.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedText.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            DispatchQueue.main.async {
                focused = true
            }
        }
        .onExitCommand(perform: onCancel)
    }

    private func save() {
        guard !trimmedText.isEmpty else { return }
        onSave(trimmedText)
    }
}
