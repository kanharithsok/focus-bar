import SwiftUI

struct IntentionsCard: View {
    @Environment(AppModel.self) private var app

    @State private var newText = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    private var today: Date { Date() }

    private var intentions: [DailyIntention] {
        app.intentions.intentions(on: today)
    }

    private var promptSkipped: Bool {
        app.intentions.isPromptSkipped(on: today)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Today's intentions")
                    Spacer()
                    Text("\(intentions.count) / 3")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if intentions.isEmpty {
                    if promptSkipped {
                        Text("No intentions today. That's fine.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !isAdding {
                            Button("Add one") { isAdding = true }
                                .buttonStyle(.link)
                                .font(.caption)
                        }
                    } else {
                        Text("Optional: choose up to three things that deserve attention today.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        intentionField
                        HStack(spacing: 10) {
                            Button("Add") { addIntention() }
                                .disabled(trimmedNewText.isEmpty)
                            Button("Skip today") {
                                Task { await app.intentions.skipPrompt(for: today) }
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(intentions) { intention in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Image(systemName: "circle")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary)
                                Text(intention.text)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Button {
                                    Task { await app.intentions.delete(intention) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove intention")
                            }
                        }
                    }

                    if intentions.count < 3 {
                        if isAdding {
                            intentionField
                            HStack(spacing: 10) {
                                Button("Add") { addIntention() }
                                    .disabled(trimmedNewText.isEmpty)
                                Button("Cancel") {
                                    isAdding = false
                                    newText = ""
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                        } else {
                            Button("Add intention") { isAdding = true }
                                .buttonStyle(.link)
                                .font(.caption)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var trimmedNewText: String {
        newText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var intentionField: some View {
        TextField("e.g. Draft the proposal outline", text: $newText)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .onSubmit(addIntention)
    }

    private func addIntention() {
        guard !trimmedNewText.isEmpty else { return }
        errorMessage = nil

        Task {
            do {
                try await app.intentions.add(text: newText, on: today)
                newText = ""
                isAdding = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
