import XCTest
@testable import FocusBar

final class SyncMergeTests: XCTestCase {
    private let deviceA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let deviceB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot(
        device: UUID,
        sessions: [SessionRecord] = [],
        captures: [Capture] = [],
        intentions: [DailyIntention] = [],
        skippedDays: [Date] = [],
        attempts: [BlockedAttempt] = [],
        settings: SharedSettingsSnapshot? = nil,
        deletions: [String: Date] = [:]
    ) -> SyncSnapshot {
        SyncSnapshot(
            deviceID: device,
            sessions: sessions,
            captures: captures,
            intentions: intentions,
            skippedDays: skippedDays,
            blockedAttempts: attempts,
            sharedSettings: settings,
            deletions: deletions
        )
    }

    func testMergesSessionsFromBothDevices() {
        let first = makeRecord(focusObject: "First", startDate: base)
        let second = makeRecord(focusObject: "Second", startDate: base.addingTimeInterval(3_600))

        let merged = SyncMerge.merge(
            local: snapshot(device: deviceA, sessions: [first]),
            remotes: [snapshot(device: deviceB, sessions: [second])]
        )

        XCTAssertEqual(Set(merged.sessions.map(\.id)), Set([first.id, second.id]))
    }

    func testNewerReviewWins() {
        var original = makeRecord(startDate: base)
        original.updatedAt = base.addingTimeInterval(10)

        var reviewed = original
        reviewed.rating = 5
        reviewed.note = "Focused"
        reviewed.updatedAt = base.addingTimeInterval(20)

        let fromA = SyncMerge.merge(
            local: snapshot(device: deviceA, sessions: [original]),
            remotes: [snapshot(device: deviceB, sessions: [reviewed])]
        )
        let fromB = SyncMerge.merge(
            local: snapshot(device: deviceB, sessions: [reviewed]),
            remotes: [snapshot(device: deviceA, sessions: [original])]
        )

        XCTAssertEqual(fromA.sessions.first?.rating, 5)
        XCTAssertEqual(fromA.sessions.first?.note, "Focused")
        XCTAssertEqual(fromB.sessions.first?.rating, 5)
    }

    func testLegacySessionFallsBackToActualEndDate() {
        let earlier = makeRecord(startDate: base, actualDuration: 60)
        var later = earlier
        later.focusObject = "Later"
        later.actualEndDate = base.addingTimeInterval(120)

        let merged = SyncMerge.merge(
            local: snapshot(device: deviceA, sessions: [earlier]),
            remotes: [snapshot(device: deviceB, sessions: [later])]
        )

        XCTAssertEqual(merged.sessions.count, 1)
        XCTAssertEqual(merged.sessions.first?.actualDuration, 120)
    }

    func testCaptureTombstoneWinsOverOlderSnapshot() {
        let capture = Capture(
            text: "Parked thought",
            createdAt: base,
            sessionID: nil,
            source: .distraction
        )
        let deletion = [SyncState.key(kind: "capture", id: capture.id): base.addingTimeInterval(60)]

        let merged = SyncMerge.merge(
            local: snapshot(device: deviceA, deletions: deletion),
            remotes: [snapshot(device: deviceB, captures: [capture])]
        )

        XCTAssertTrue(merged.captures.isEmpty)
        XCTAssertNotNil(merged.deletions[SyncState.key(kind: "capture", id: capture.id)])
    }

    func testIntentionTombstoneWinsOverOlderSnapshot() {
        let intention = DailyIntention(text: "Write the report", day: base, createdAt: base)
        let deletion = [SyncState.key(kind: "intention", id: intention.id): base.addingTimeInterval(60)]

        let merged = SyncMerge.merge(
            local: snapshot(device: deviceA, intentions: [intention]),
            remotes: [snapshot(device: deviceB, deletions: deletion)]
        )

        XCTAssertTrue(merged.intentions.isEmpty)
    }

    func testSkippedDaysAndAttemptsUnion() {
        let firstAttempt = BlockedAttempt(
            timestamp: base,
            sessionID: nil,
            kind: .website,
            identifier: "x.com",
            displayName: "X"
        )
        let secondAttempt = BlockedAttempt(
            timestamp: base.addingTimeInterval(10),
            sessionID: nil,
            kind: .application,
            identifier: "com.example.app",
            displayName: "Example"
        )

        let merged = SyncMerge.merge(
            local: snapshot(
                device: deviceA,
                skippedDays: [base],
                attempts: [firstAttempt]
            ),
            remotes: [
                snapshot(
                    device: deviceB,
                    skippedDays: [base.addingTimeInterval(86_400)],
                    attempts: [secondAttempt]
                )
            ]
        )

        XCTAssertEqual(merged.skippedDays.count, 2)
        XCTAssertEqual(Set(merged.blockedAttempts.map(\.id)), Set([firstAttempt.id, secondAttempt.id]))
    }

    func testNewerSharedSettingsWin() {
        var settingsA = AppSettings.defaults()
        settingsA.commitMode = true
        settingsA.sharedSettingsUpdatedAt = base

        var settingsB = AppSettings.defaults()
        settingsB.commitMode = false
        settingsB.blockDuringScatterfocus = false
        settingsB.sharedSettingsUpdatedAt = base.addingTimeInterval(60)

        let sharedA = SharedSettingsSnapshot(settings: settingsA)
        let sharedB = SharedSettingsSnapshot(settings: settingsB)

        let merged = SyncMerge.merge(
            local: snapshot(device: deviceA, settings: sharedA),
            remotes: [snapshot(device: deviceB, settings: sharedB)]
        )

        XCTAssertEqual(merged.sharedSettings?.commitMode, false)
        XCTAssertEqual(merged.sharedSettings?.blockDuringScatterfocus, false)
    }

    func testSharedSettingsApplyLeavesDeviceSpecificFieldsAlone() {
        var settings = AppSettings.defaults()
        settings.systemWideWebsiteBlockingEnabled = true
        settings.restartMozillaBrowsersOnSessionChange = true
        settings.syncEnabled = true

        var remote = AppSettings.defaults()
        remote.commitMode = true
        remote.sharedSettingsUpdatedAt = base.addingTimeInterval(60)
        let shared = SharedSettingsSnapshot(settings: remote)

        shared.apply(to: &settings)

        XCTAssertTrue(settings.commitMode)
        XCTAssertTrue(settings.systemWideWebsiteBlockingEnabled)
        XCTAssertTrue(settings.restartMozillaBrowsersOnSessionChange)
        XCTAssertTrue(settings.syncEnabled)
    }

    func testMergeIsOrderIndependent() {
        let first = makeRecord(focusObject: "First", startDate: base)
        let second = makeRecord(focusObject: "Second", startDate: base.addingTimeInterval(100))
        let snapA = snapshot(device: deviceA, sessions: [first])
        let snapB = snapshot(device: deviceB, sessions: [second])

        let aThenB = SyncMerge.merge(local: snapA, remotes: [snapB])
        let bThenA = SyncMerge.merge(local: snapB, remotes: [snapA])

        XCTAssertEqual(aThenB.sessions, bThenA.sessions)
    }
}

final class FolderSyncEngineTests: XCTestCase {
    private let deviceA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let deviceB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func temporaryFolder() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarSync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snapshot(device: UUID, sessions: [SessionRecord] = []) -> SyncSnapshot {
        SyncSnapshot(
            deviceID: device,
            sessions: sessions,
            captures: [],
            intentions: [],
            skippedDays: [],
            blockedAttempts: [],
            sharedSettings: nil,
            deletions: [:]
        )
    }

    func testTwoDevicesConvergeOnBothSessions() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let engine = FolderSyncEngine()
        let first = makeRecord(focusObject: "First", startDate: base)
        let second = makeRecord(focusObject: "Second", startDate: base.addingTimeInterval(100))

        _ = try await engine.sync(local: snapshot(device: deviceA, sessions: [first]), folderURL: folder)
        _ = try await engine.sync(local: snapshot(device: deviceB, sessions: [second]), folderURL: folder)
        let finalA = try await engine.sync(local: snapshot(device: deviceA, sessions: [first]), folderURL: folder)

        XCTAssertEqual(Set(finalA.snapshot.sessions.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(finalA.otherDeviceCount, 1)
    }

    func testUnreadableRemoteFileIsSkippedWithWarning() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let devices = folder.appendingPathComponent("devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
        try Data("not json".utf8).write(
            to: devices.appendingPathComponent("device-\(deviceB.uuidString).json")
        )

        let engine = FolderSyncEngine()
        let record = makeRecord(startDate: base)
        let outcome = try await engine.sync(
            local: snapshot(device: deviceA, sessions: [record]),
            folderURL: folder
        )

        XCTAssertFalse(outcome.warnings.isEmpty)
        XCTAssertEqual(outcome.snapshot.sessions.count, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: devices.appendingPathComponent("device-\(deviceA.uuidString).json").path
            )
        )
    }

    func testNewerRemoteSchemaIsSkipped() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let devices = folder.appendingPathComponent("devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)

        let future = SyncSnapshot(
            schemaVersion: SyncSnapshot.schemaVersion + 1,
            deviceID: deviceB,
            sessions: [],
            captures: [],
            intentions: [],
            skippedDays: [],
            blockedAttempts: [],
            sharedSettings: nil,
            deletions: [:]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode(future).write(
            to: devices.appendingPathComponent("device-\(deviceB.uuidString).json")
        )

        let engine = FolderSyncEngine()
        let record = makeRecord(startDate: base)
        let outcome = try await engine.sync(
            local: snapshot(device: deviceA, sessions: [record]),
            folderURL: folder
        )

        XCTAssertEqual(outcome.otherDeviceCount, 0)
        XCTAssertFalse(outcome.warnings.isEmpty)
        XCTAssertEqual(outcome.snapshot.sessions.count, 1)
    }

    func testEvictedICloudPlaceholderIsSkippedUntilDownloaded() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let devices = folder.appendingPathComponent("devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
        try Data("placeholder".utf8).write(
            to: devices.appendingPathComponent(".device-\(deviceB.uuidString).json.icloud")
        )

        let engine = FolderSyncEngine()
        let record = makeRecord(startDate: base)
        let outcome = try await engine.sync(
            local: snapshot(device: deviceA, sessions: [record]),
            folderURL: folder
        )

        XCTAssertEqual(outcome.otherDeviceCount, 0)
        XCTAssertTrue(outcome.warnings.isEmpty)
    }

    func testUnchangedSyncDoesNotRewriteOwnSnapshot() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let engine = FolderSyncEngine()
        let local = snapshot(device: deviceA, sessions: [makeRecord(startDate: base)])

        _ = try await engine.sync(local: local, folderURL: folder)
        let ownURL = folder
            .appendingPathComponent("devices", isDirectory: true)
            .appendingPathComponent("device-\(deviceA.uuidString).json")
        let firstData = try Data(contentsOf: ownURL)

        _ = try await engine.sync(local: local, folderURL: folder)
        let secondData = try Data(contentsOf: ownURL)

        XCTAssertEqual(firstData, secondData)
    }
}

@MainActor
final class SyncCoordinatorTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private struct Environment {
        let directory: URL
        let coordinator: SyncCoordinator
        let stats: StatsStore
        let captures: CaptureStore
        let settings: SettingsStore
    }

    private func makeEnvironment() async -> Environment {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarCoordinator-\(UUID().uuidString)", isDirectory: true)
        let persistence = PersistenceController(directory: directory)
        let settings = SettingsStore(persistence: persistence, dateProvider: { self.base })
        let stats = StatsStore(persistence: persistence)
        let captures = CaptureStore(persistence: persistence)
        let intentions = IntentionStore(persistence: persistence)
        let attempts = BlockedAttemptStore(persistence: persistence)
        await settings.load()
        await stats.load()
        await captures.load()
        await intentions.load()
        await attempts.load()

        let coordinator = SyncCoordinator(
            persistence: persistence,
            settings: settings,
            stats: stats,
            captures: captures,
            intentions: intentions,
            blockedAttempts: attempts,
            dateProvider: { self.base }
        )
        await coordinator.start()
        return Environment(
            directory: directory,
            coordinator: coordinator,
            stats: stats,
            captures: captures,
            settings: settings
        )
    }

    func testTwoCoordinatorsShareHistoryThroughFolder() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarShared-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = await makeEnvironment()
        let second = await makeEnvironment()
        defer {
            try? FileManager.default.removeItem(at: first.directory)
            try? FileManager.default.removeItem(at: second.directory)
        }

        await first.coordinator.enable(folderURL: folder)
        await second.coordinator.enable(folderURL: folder)

        let record = makeRecord(focusObject: "Shared", startDate: base)
        await first.stats.upsert(record)

        await first.coordinator.syncNow()
        await second.coordinator.syncNow()
        await first.coordinator.syncNow()

        XCTAssertEqual(second.stats.sessions.count, 1)
        XCTAssertEqual(first.stats.sessions.count, 1)
        XCTAssertEqual(second.stats.sessions.first?.id, record.id)

        await first.coordinator.disable()
        await second.coordinator.disable()
    }

    func testDeletionTombstonePreventsResurrection() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarDeletion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = await makeEnvironment()
        let second = await makeEnvironment()
        defer {
            try? FileManager.default.removeItem(at: first.directory)
            try? FileManager.default.removeItem(at: second.directory)
        }

        await first.coordinator.enable(folderURL: folder)
        await second.coordinator.enable(folderURL: folder)

        guard let capture = await first.captures.add(
            text: "Delete me",
            sessionID: nil,
            source: .distraction,
            at: base
        ) else {
            return XCTFail("Expected a capture")
        }

        await first.coordinator.syncNow()
        await second.coordinator.syncNow()
        XCTAssertTrue(second.captures.captures.contains { $0.id == capture.id })

        await first.captures.delete(capture)
        await first.coordinator.syncNow()
        await second.coordinator.syncNow()

        XCTAssertFalse(second.captures.captures.contains { $0.id == capture.id })

        await first.coordinator.disable()
        await second.coordinator.disable()
    }
}
