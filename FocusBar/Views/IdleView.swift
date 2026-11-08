import SwiftUI

struct IdleView: View {
    @Environment(AppModel.self) private var app

    @State private var mode: IdleMode = .hyperfocus
    @State private var focusObject = ""
    @State private var durationChoice: DurationChoice = .twentyFive
    @State private var customMinutes = 45
    @State private var selectedIntentionID: UUID?
    @State private var scatterMode: ScatterfocusMode = .capture
    @State private var scatterMinutes = 10
    @State private var problemQuestion = ""
    @State private var isStarting = false
    @State private var errorMessage: String?

    private enum IdleMode: String, CaseIterable, Identifiable {
        case hyperfocus
        case scatterfocus

        var id: String { rawValue }

        var label: String {
            switch self {
            case .hyperfocus: return "Hyperfocus"
            case .scatterfocus: return "Break"
            }
        }
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

    private var todayIntentions: [DailyIntention] {
        app.intentions.intentions(on: Date())
    }

    private var minutes: Int {
        durationChoice == .custom ? customMinutes : durationChoice.rawValue
    }

    private var canStartHyperfocus: Bool {
        !focusObject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStarting
            && (1...480).contains(minutes)
    }

    private var canStartBreak: Bool {
        !isStarting && (1...480).contains(scatterMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FocusBar")
                    .font(.title3.weight(.semibold))
                Text(mode == .hyperfocus
                     ? "What deserves your full attention?"
                     : "Step back and let your mind wander.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $mode) {
                ForEach(IdleMode.allCases) { idleMode in
                    Text(idleMode.label).tag(idleMode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .hyperfocus {
                hyperfocusCard
            } else {
                breakCard
            }

            IntentionsCard()

            Text("Tip: ⌃⌥Space parks a distraction without leaving your work.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("FocusBar keeps your session on this Mac. Nothing is uploaded.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Hyperfocus

    private var hyperfocusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "One specific focus")

                TextField("e.g. Finish the authentication API", text: $focusObject)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(startHyperfocusIfPossible)

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

                Button(action: startHyperfocusIfPossible) {
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
                .disabled(!canStartHyperfocus)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func startHyperfocusIfPossible() {
        guard canStartHyperfocus else { return }
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

    // MARK: - Scatterfocus

    private var breakCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Scatterfocus mode")

                Picker("Scatterfocus mode", selection: $scatterMode) {
                    ForEach(ScatterfocusMode.allCases) { scatterfocusMode in
                        Text(scatterfocusMode.shortName).tag(scatterfocusMode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(scatterMode.guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if scatterMode == .problemCrunching {
                    TextField("What question do you want to hold?", text: $problemQuestion)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    Text("Break length")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $scatterMinutes, in: 1...120, step: 5) {
                        Text("\(scatterMinutes) min")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .fixedSize()
                }

                if app.settings.settings.blockDuringScatterfocus {
                    Label("Blocking stays on during breaks unless you suspend it.", systemImage: "shield.lefthalf.filled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Blocking is off during breaks in Settings.", systemImage: "shield.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button(action: startBreakIfPossible) {
                    HStack {
                        Spacer()
                        if isStarting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Start Scatterfocus")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(!canStartBreak)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func startBreakIfPossible() {
        guard canStartBreak else { return }
        isStarting = true
        errorMessage = nil

        Task {
            defer { isStarting = false }
            do {
                try await app.sessionManager.startScatterfocus(
                    mode: scatterMode,
                    minutes: scatterMinutes,
                    question: problemQuestion,
                    preset: app.settings.selectedPreset
                )
                problemQuestion = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
