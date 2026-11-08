import Foundation
import Observation

@MainActor
@Observable
final class BlockedAttemptStore {
    private(set) var attempts: [BlockedAttempt] = []
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController
    private let maximumCount = 5_000

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func load() async {
        if let loaded = await persistence.load([BlockedAttempt].self, from: "blockedAttempts.json") {
            attempts = loaded.sorted { $0.timestamp > $1.timestamp }
        }
    }

    func record(_ attempt: BlockedAttempt) async {
        attempts.insert(attempt, at: 0)
        if attempts.count > maximumCount {
            attempts.removeLast(attempts.count - maximumCount)
        }
        await persist()
    }

    func count(sessionID: UUID) -> Int {
        attempts.filter { $0.sessionID == sessionID }.count
    }

    func count(on day: Date, calendar: Calendar = .current) -> Int {
        attempts.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.count
    }

    func count(in interval: DateInterval?) -> Int {
        guard let interval else { return 0 }
        return attempts.filter { interval.contains($0.timestamp) }.count
    }

    var totalCount: Int { attempts.count }

    func weekCount(now: Date = Date(), calendar: Calendar = .current) -> Int {
        count(in: StatsCalculator.weekInterval(containing: now, calendar: calendar))
    }

    private func persist() async {
        do {
            try await persistence.save(attempts, to: "blockedAttempts.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save blocking history: \(error.localizedDescription)"
        }
    }
}
