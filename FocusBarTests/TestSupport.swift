import Foundation
@testable import FocusBar

@MainActor
final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
final class TestEnvironment {
    let clock: TestClock
    let directory: URL
    let persistence: PersistenceController
    let settings: SettingsStore
    let stats: StatsStore
    let captures: CaptureStore
    let intentions: IntentionStore
    let attempts: BlockedAttemptStore
    let manager: SessionManager

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        let clock = TestClock(now: now)
        self.clock = clock
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarTests-\(UUID().uuidString)", isDirectory: true)
        persistence = PersistenceController(directory: directory)
        settings = SettingsStore(persistence: persistence)
        stats = StatsStore(persistence: persistence)
        captures = CaptureStore(persistence: persistence)
        intentions = IntentionStore(persistence: persistence)
        attempts = BlockedAttemptStore(persistence: persistence)
        manager = SessionManager(
            persistence: persistence,
            statsStore: stats,
            settingsStore: settings,
            dateProvider: { clock.now },
            automaticallyTicks: false
        )
    }

    func loadAll() async {
        await settings.load()
        await stats.load()
        await captures.load()
        await intentions.load()
        await attempts.load()
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}

func makeRecord(
    kind: SessionKind = .hyperfocus,
    focusObject: String = "Test focus",
    startDate: Date,
    duration: TimeInterval = 25 * 60,
    actualDuration: TimeInterval? = nil,
    status: SessionStatus = .completed,
    rating: Int? = nil
) -> SessionRecord {
    let actual = actualDuration ?? duration
    return SessionRecord(
        kind: kind,
        focusObject: focusObject,
        plannedDuration: duration,
        startDate: startDate,
        plannedEndDate: startDate.addingTimeInterval(duration),
        actualEndDate: startDate.addingTimeInterval(actual),
        status: status,
        rating: rating
    )
}
