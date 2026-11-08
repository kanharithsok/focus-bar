import Foundation
import Observation

@MainActor
@Observable
final class StatsStore {
    private(set) var sessions: [SessionRecord] = []
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func load() async {
        if let loaded = await persistence.load([SessionRecord].self, from: "sessions.json") {
            sessions = loaded.sorted { $0.startDate > $1.startDate }
        }
    }

    /// Inserts or replaces a record by ID. Used both for new sessions and review updates.
    func upsert(_ record: SessionRecord) async {
        if let index = sessions.firstIndex(where: { $0.id == record.id }) {
            sessions[index] = record
        } else {
            sessions.append(record)
        }
        sessions.sort { $0.startDate > $1.startDate }
        await persist()
    }

    func record(id: UUID) -> SessionRecord? {
        sessions.first { $0.id == id }
    }

    var hyperfocusSessions: [SessionRecord] {
        sessions.filter { $0.kind == .hyperfocus }
    }

    func focusMinutes(on day: Date, calendar: Calendar = .current) -> Double {
        StatsCalculator.focusMinutes(sessions: sessions, on: day, calendar: calendar)
    }

    func weekFocusMinutes(now: Date = Date(), calendar: Calendar = .current) -> Double {
        StatsCalculator.focusMinutes(
            sessions: sessions,
            in: StatsCalculator.weekInterval(containing: now, calendar: calendar)
        )
    }

    var totalFocusMinutes: Double {
        StatsCalculator.totalFocusMinutes(sessions: sessions)
    }

    var averageRating: Double? {
        StatsCalculator.averageRating(sessions: sessions)
    }

    func dailyFocus(lastDays: Int, now: Date = Date(), calendar: Calendar = .current) -> [DailyFocus] {
        StatsCalculator.dailyFocus(
            sessions: sessions,
            lastDays: lastDays,
            now: now,
            calendar: calendar
        )
    }

    func capturesCount(for sessionID: UUID, in captureStore: CaptureStore) -> Int {
        captureStore.captures(for: sessionID).count
    }

    private func persist() async {
        do {
            try await persistence.save(sessions, to: "sessions.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save session history: \(error.localizedDescription)"
        }
    }
}
