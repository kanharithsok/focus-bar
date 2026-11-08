import SwiftUI

struct IdleView: View {
    @Environment(AppModel.self) private var app

    @State private var focusObject = ""
    @State private var durationChoice: DurationChoice = .twentyFive
    @State private var customMinutes = 45
    @State private var selectedIntentionID: UUID?
    @State private var isStarting = false
    @State private var errorMessage: String?

    private var todayIntentions: [DailyIntention] {
        app.intentions.intentions(on: Date())
    }

    private enum DurationChoice: Int, CaseIterable, Identifiable {
        case twentyFive = 25
        case fifty = 50
        case ninety = 90
        case custom = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .twentyFive: return "25"
            case .fifty: return "50"
            case .ninety: return "90"
            case .custom: return "Custom"
            }
        }
    }

    private var minutes: Int {
        durationChoice == .custom ? customMinutes : durationChoice.rawValue
    }

    private var canStart: Bool {
        !focusObject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStarting
            && (1...480).contains(minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FocusBar")
                    .font(.title3.weight(.semibold))
                Text("What deserves your full attention?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "One specific focus")

                    TextField("e.g. Finish the authentication API", text: $focusObject)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(startIfPossible)

                    SectionLabel(text: "Duration")

                    Picker("Duration", selection: $durationChoice) {
                        ForEach(DurationChoice.allCases) { choice in
                            Text(choice == .custom ? choice.label : "\(choice.label) min")
                                .tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if durationChoice == .custom {
                        HStack(spacing: 8) {
                            TextField("Minutes", value: $customMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Stepper("", value: $customMinutes, in: 1...480)
                                .labelsHidden()
                            Text("minutes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !todayIntentions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Link to an intention")
                            Picker("Intention", selection: $selectedIntentionID) {
                                Text("None").tag(UUID?.none)
                                ForEach(todayIntentions) { intention in
                                    Text(intention.text).tag(Optional(intention.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    Button(action: startIfPossible) {
                        HStack {
                            Spacer()
                            if isStarting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Start Hyperfocus")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!canStart)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            IntentionsCard()

            Text("FocusBar keeps your session on this Mac. Nothing is uploaded.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func startIfPossible() {
        guard canStart else { return }
        isStarting = true
        errorMessage = nil

        let intention = todayIntentions.first { $0.id == selectedIntentionID }

        Task {
            defer { isStarting = false }
            do {
                try await app.sessionManager.startHyperfocus(
                    focusObject: focusObject,
                    minutes: minutes,
                    intention: intention,
                    preset: app.settings.selectedPreset
                )
                focusObject = ""
                selectedIntentionID = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
