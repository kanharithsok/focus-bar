import XCTest
@testable import FocusBar

@MainActor
final class CaptureStoreTests: XCTestCase {
    func testCaptureAssociationAndFiltering() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let sessionID = UUID()
        let otherID = UUID()

        await env.captures.add(text: "  Check the deploy  ", sessionID: sessionID, source: .distraction)
        await env.captures.add(text: "General thought", sessionID: nil, source: .distraction)
        await env.captures.add(text: "Break idea", sessionID: otherID, source: .scatterfocus)

        XCTAssertEqual(env.captures.captures(for: sessionID).count, 1)
        XCTAssertEqual(env.captures.captures(for: sessionID).first?.text, "Check the deploy")
        XCTAssertEqual(env.captures.captures(for: sessionID, source: .distraction).count, 1)
        XCTAssertEqual(env.captures.generalCaptures.count, 1)
        XCTAssertEqual(env.captures.captures.count, 3)
    }

    func testEmptyCaptureIsIgnored() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let capture = await env.captures.add(text: "   \n ", sessionID: nil, source: .distraction)
        XCTAssertNil(capture)
        XCTAssertTrue(env.captures.captures.isEmpty)
    }

    func testCapturesPersistAcrossStoreInstances() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let sessionID = UUID()
        await env.captures.add(text: "Persisted", sessionID: sessionID, source: .distraction)

        let reloaded = CaptureStore(persistence: env.persistence)
        await reloaded.load()

        XCTAssertEqual(reloaded.captures.count, 1)
        XCTAssertEqual(reloaded.captures.first?.sessionID, sessionID)
    }
}

@MainActor
final class IntentionStoreTests: XCTestCase {
    func testMaximumThreeIntentionsPerDay() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let day = env.clock.now
        try await env.intentions.add(text: "One", on: day)
        try await env.intentions.add(text: "Two", on: day)
        try await env.intentions.add(text: "Three", on: day)

        do {
            try await env.intentions.add(text: "Four", on: day)
            XCTFail("Expected limitReached")
        } catch {
            XCTAssertEqual(error as? IntentionError, .limitReached)
        }

        XCTAssertEqual(env.intentions.intentions(on: day).count, 3)
        XCTAssertFalse(env.intentions.canAdd(on: day))
    }

    func testIntentionsAreScopedToTheirDay() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = env.clock.now
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!

        try await env.intentions.add(text: "Today", on: dayOne, calendar: calendar)
        try await env.intentions.add(text: "Tomorrow", on: dayTwo, calendar: calendar)

        XCTAssertEqual(env.intentions.intentions(on: dayOne, calendar: calendar).map(\.text), ["Today"])
        XCTAssertEqual(env.intentions.intentions(on: dayTwo, calendar: calendar).map(\.text), ["Tomorrow"])
    }

    func testSkipPromptIsPerDayAndPersists() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let day = env.clock.now
        await env.intentions.skipPrompt(for: day)
        XCTAssertTrue(env.intentions.isPromptSkipped(on: day))

        let reloaded = IntentionStore(persistence: env.persistence)
        await reloaded.load()
        XCTAssertTrue(reloaded.isPromptSkipped(on: day))
    }

    func testEmptyIntentionRejected() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        do {
            try await env.intentions.add(text: "  ", on: env.clock.now)
            XCTFail("Expected emptyText")
        } catch {
            XCTAssertEqual(error as? IntentionError, .emptyText)
        }
    }
}

@MainActor
final class SyncStoreTests: XCTestCase {
    func testCaptureDeleteRecordsTombstoneBeforeRemoval() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let capture = await env.captures.add(text: "Delete me", sessionID: nil, source: .distraction)
        let captureID = capture?.id
        var deletedID: UUID?
        env.captures.onDelete = { id in
            deletedID = id
        }

        if let capture {
            await env.captures.delete(capture)
        }

        XCTAssertEqual(deletedID, captureID)
        XCTAssertTrue(env.captures.captures.isEmpty)
    }

    func testIntentionDeleteRecordsTombstoneBeforeRemoval() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let intention = try await env.intentions.add(text: "Delete me", on: env.clock.now)
        var deletedID: UUID?
        env.intentions.onDelete = { id in
            deletedID = id
        }

        await env.intentions.delete(intention)

        XCTAssertEqual(deletedID, intention.id)
        XCTAssertTrue(env.intentions.intentions.isEmpty)
    }

    func testSharedSettingsTimestampOnlyMovesForSharedFields() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        XCTAssertNil(env.settings.settings.sharedSettingsUpdatedAt)

        await env.settings.update { $0.systemWideWebsiteBlockingEnabled = true }
        XCTAssertNil(env.settings.settings.sharedSettingsUpdatedAt)

        env.clock.now = env.clock.now.addingTimeInterval(120)
        await env.settings.update { $0.commitMode = true }
        XCTAssertEqual(env.settings.settings.sharedSettingsUpdatedAt, env.clock.now)
    }

    func testApplyingSharedSettingsKeepsDeviceSpecificValues() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        await env.settings.update {
            $0.systemWideWebsiteBlockingEnabled = true
            $0.restartMozillaBrowsersOnSessionChange = true
        }

        var remote = AppSettings.defaults()
        remote.commitMode = true
        remote.sharedSettingsUpdatedAt = env.clock.now.addingTimeInterval(60)
        await env.settings.applySharedSettings(SharedSettingsSnapshot(settings: remote))

        XCTAssertTrue(env.settings.settings.commitMode)
        XCTAssertTrue(env.settings.settings.systemWideWebsiteBlockingEnabled)
        XCTAssertTrue(env.settings.settings.restartMozillaBrowsersOnSessionChange)
    }

    func testStatsUpsertMarksRecordUpdated() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let record = makeRecord(startDate: env.clock.now)
        await env.stats.upsert(record)

        XCTAssertNotNil(env.stats.sessions.first?.updatedAt)
    }

    func testLegacySettingsWithoutSyncFieldsDecode() throws {
        let data = Data("{}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(settings.syncEnabled)
        XCTAssertNil(settings.syncFolderPath)
        XCTAssertNil(settings.syncFolderBookmark)
        XCTAssertNil(settings.sharedSettingsUpdatedAt)
    }
}

final class BlocklistDefaultsTests: XCTestCase {
    func testDefaultPresetContainsRequiredServicesExceptYouTube() {
        let preset = BlocklistPreset.socialMediaDefault()
        let domains = Set(preset.normalizedWebsiteDomains)

        for required in ["x.com", "twitter.com", "facebook.com", "instagram.com", "tiktok.com",
                         "reddit.com", "linkedin.com", "snapchat.com", "threads.net"] {
            XCTAssertTrue(domains.contains(required), "Missing \(required)")
        }
        XCTAssertFalse(domains.contains("youtube.com"))
        XCTAssertFalse(domains.contains("youtu.be"))
        XCTAssertTrue(preset.isBuiltIn)
    }

    func testCatalogYouTubeDefaultsOff() {
        let youtube = ServiceCatalog.services.first { $0.id == "youtube" }
        XCTAssertNotNil(youtube)
        XCTAssertEqual(youtube?.defaultEnabled, false)
    }

    func testPresetNormalizesAndDeduplicatesDomains() {
        let preset = BlocklistPreset(
            name: "Test",
            websiteDomains: ["https://WWW.Example.com/path", "example.com", "bad domain", "sub.test.org"]
        )
        XCTAssertEqual(preset.normalizedWebsiteDomains, ["example.com", "sub.test.org"])
    }
}
