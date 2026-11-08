import Foundation
import Observation

@MainActor
@Observable
final class IntentionStore {
    private(set) var intentions: [DailyIntention] = []
    private(set) var skippedDays: Set<Date> = []
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func load() async {
        if let file = await persistence.load(IntentionFile.self, from: "intentions.json") {
            intentions = file.intentions
            skippedDays = Set(file.skippedDays)
        }
    }

    func intentions(on day: Date, calendar: Calendar = .current) -> [DailyIntention] {
        intentions
            .filter { calendar.isDate($0.day, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func canAdd(on day: Date, calendar: Calendar = .current) -> Bool {
        intentions(on: day, calendar: calendar).count < 3
    }

    @discardableResult
    func add(
        text: String,
        on day: Date,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> DailyIntention {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntentionError.emptyText }
        guard canAdd(on: day, calendar: calendar) else { throw IntentionError.limitReached }

        let intention = DailyIntention(
            text: trimmed,
            day: calendar.startOfDay(for: day),
            createdAt: date
        )
        intentions.append(intention)
        await persist()
        return intention
    }

    func delete(_ intention: DailyIntention) async {
        intentions.removeAll { $0.id == intention.id }
        await persist()
    }

    func skipPrompt(for day: Date, calendar: Calendar = .current) async {
        skippedDays.insert(calendar.startOfDay(for: day))
        await persist()
    }

    func isPromptSkipped(on day: Date, calendar: Calendar = .current) -> Bool {
        skippedDays.contains(calendar.startOfDay(for: day))
    }

    private func persist() async {
        do {
            let file = IntentionFile(
                intentions: intentions,
                skippedDays: skippedDays.sorted()
            )
            try await persistence.save(file, to: "intentions.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save intentions: \(error.localizedDescription)"
        }
    }
}
