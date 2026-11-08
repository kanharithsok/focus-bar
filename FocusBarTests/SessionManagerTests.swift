import XCTest
@testable import FocusBar

@MainActor
final class SessionManagerTests: XCTestCase {
    func testStartHyperfocusSetsStateAndTimer() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let session = try await env.manager.startHyperfocus(
            focusObject: "  Finish the authentication API  ",
            minutes: 25
        )

        XCTAssertEqual(env.manager.phase, .hyperfocus)
        XCTAssertEqual(session.focusObject, "Finish the authentication API")
        XCTAssertEqual(session.plannedDuration, 25 * 60)
        XCTAssertEqual(env.manager.remainingTime, 25 * 60)
        XCTAssertEqual(env.manager.remainingText, "25:00")
        XCTAssertEqual(env.manager.progress, 0, accuracy: 0.0001)
        XCTAssertTrue(env.manager.isActive)
    }

    func testInvalidTransitionsAreRejected() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        do {
            try await env.manager.endEarly(reason: "nope", emergency: false)
            XCTFail("Expected noActiveSession")
        } catch {
            XCTAssertEqual(error as? SessionError, .noActiveSession)
        }

        try await env.manager.startHyperfocus(focusObject: "Write tests", minutes: 25)

        do {
            try await env.manager.startHyperfocus(focusObject: "Another", minutes: 50)
            XCTFail("Expected invalidState")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidState)
        }

        do {
            try await env.manager.startScatterfocus(mode: .capture)
            XCTFail("Expected invalidState")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidState)
        }

        do {
            try await env.manager.submitReview(rating: 4, note: nil)
            XCTFail("Expected invalidState")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidState)
        }
    }

    func testValidationRejectsEmptyFocusAndInvalidDuration() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        do {
            try await env.manager.startHyperfocus(focusObject: "   ", minutes: 25)
            XCTFail("Expected emptyFocusObject")
        } catch {
            XCTAssertEqual(error as? SessionError, .emptyFocusObject)
        }

        do {
            try await env.manager.startHyperfocus(focusObject: "Valid", minutes: 0)
            XCTFail("Expected invalidDuration")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidDuration)
        }

        do {
            try await env.manager.startHyperfocus(focusObject: "Valid", minutes: 481)
            XCTFail("Expected invalidDuration")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidDuration)
        }
    }

    func testSessionStoresSelectedBlocklistPreset() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let preset = BlocklistPreset(name: "Custom sites", websiteDomains: ["example.com"])
        try await env.manager.startHyperfocus(
            focusObject: "Deep work",
            minutes: 25,
            preset: preset
        )

        XCTAssertEqual(env.manager.activeSession?.blocklistPresetID, preset.id)
        XCTAssertEqual(env.manager.activeSession?.blocklistName, "Custom sites")
    }

    func testExpirationCompletesSessionAtPlannedEnd() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let start = env.clock.now
        try await env.manager.startHyperfocus(focusObject: "Deep work", minutes: 25)

        env.clock.now = start.addingTimeInterval(25 * 60 + 90)
        await env.manager.refresh()

        XCTAssertEqual(env.manager.phase, .review)
        guard let record = env.manager.pendingReview else {
            return XCTFail("Expected pending review")
        }
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.actualEndDate, start.addingTimeInterval(25 * 60))
        XCTAssertEqual(record.actualDuration, 25 * 60)
        XCTAssertEqual(env.stats.sessions.count, 1)
        XCTAssertEqual(env.stats.sessions.first?.id, record.id)
    }

    func testEarlyEndRequiresReasonAndRecordsActualDuration() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let start = env.clock.now
        try await env.manager.startHyperfocus(focusObject: "Deep work", minutes: 50)

        do {
            try await env.manager.endEarly(reason: "  ", emergency: false)
            XCTFail("Expected reasonRequired")
        } catch {
            XCTAssertEqual(error as? SessionError, .reasonRequired)
        }
        XCTAssertEqual(env.manager.phase, .hyperfocus)

        env.clock.now = start.addingTimeInterval(300)
        try await env.manager.endEarly(reason: "Meeting moved", emergency: false)

        XCTAssertEqual(env.manager.phase, .review)
        let record = try XCTUnwrap(env.manager.pendingReview)
        XCTAssertEqual(record.status, .endedEarly)
        XCTAssertEqual(record.earlyEndReason, "Meeting moved")
        XCTAssertEqual(record.actualDuration, 300)
        XCTAssertEqual(env.stats.sessions.count, 1)
    }

    func testCommitModeBlocksNormalEarlyEndButAllowsEmergency() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        await env.settings.update { $0.commitMode = true }
        try await env.manager.startHyperfocus(focusObject: "Ship it", minutes: 50)
        env.clock.now = env.clock.now.addingTimeInterval(120)

        do {
            try await env.manager.endEarly(reason: "Distracted", emergency: false)
            XCTFail("Expected commitModeActive")
        } catch {
            XCTAssertEqual(error as? SessionError, .commitModeActive)
        }
        XCTAssertEqual(env.manager.phase, .hyperfocus)

        try await env.manager.endEarly(reason: "", emergency: true)
        XCTAssertEqual(env.manager.phase, .review)
        XCTAssertEqual(env.manager.pendingReview?.status, .emergencyStop)
        XCTAssertEqual(env.manager.pendingReview?.earlyEndReason, "Emergency stop")
    }

    func testReviewSavesRatingAndReturnsToIdle() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startHyperfocus(focusObject: "Write docs", minutes: 25)
        env.clock.now = env.clock.now.addingTimeInterval(25 * 60)
        await env.manager.refresh()

        try await env.manager.submitReview(rating: 4, note: "  Solid block.  ")

        XCTAssertEqual(env.manager.phase, .idle)
        let record = try XCTUnwrap(env.stats.sessions.first)
        XCTAssertEqual(record.rating, 4)
        XCTAssertEqual(record.note, "Solid block.")
    }

    func testReviewRejectsInvalidRating() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startHyperfocus(focusObject: "Write docs", minutes: 25)
        env.clock.now = env.clock.now.addingTimeInterval(25 * 60)
        await env.manager.refresh()

        do {
            try await env.manager.submitReview(rating: 6, note: nil)
            XCTFail("Expected invalidRating")
        } catch {
            XCTAssertEqual(error as? SessionError, .invalidRating)
        }
    }

    func testRestoreResumesActiveSession() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let start = env.clock.now
        try await env.manager.startHyperfocus(focusObject: "Resume me", minutes: 50)

        env.clock.now = start.addingTimeInterval(10 * 60)
        let restored = SessionManager(
            persistence: env.persistence,
            statsStore: env.stats,
            settingsStore: env.settings,
            dateProvider: { env.clock.now },
            automaticallyTicks: false
        )
        await restored.restore()

        XCTAssertEqual(restored.phase, .hyperfocus)
        XCTAssertEqual(restored.activeSession?.focusObject, "Resume me")
        XCTAssertEqual(restored.remainingTime, 40 * 60)
    }

    func testRestoreExpiredSessionCreatesRecordOnce() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let start = env.clock.now
        try await env.manager.startHyperfocus(focusObject: "Expired while closed", minutes: 25)
        env.clock.now = start.addingTimeInterval(60 * 60)

        let restored = SessionManager(
            persistence: env.persistence,
            statsStore: env.stats,
            settingsStore: env.settings,
            dateProvider: { env.clock.now },
            automaticallyTicks: false
        )
        await restored.restore()

        XCTAssertEqual(restored.phase, .review)
        XCTAssertEqual(env.stats.sessions.count, 1)
        XCTAssertEqual(env.stats.sessions.first?.status, .completed)

        let restoredAgain = SessionManager(
            persistence: env.persistence,
            statsStore: env.stats,
            settingsStore: env.settings,
            dateProvider: { env.clock.now },
            automaticallyTicks: false
        )
        await restoredAgain.restore()
        XCTAssertEqual(restoredAgain.phase, .review)
        XCTAssertEqual(env.stats.sessions.count, 1, "Restore must not duplicate history")
    }

    func testScatterfocusModesStoreTheirContext() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let problem = try await env.manager.startScatterfocus(
            mode: .problemCrunching,
            minutes: 10,
            question: "  How should I structure the migration?  "
        )
        XCTAssertEqual(problem.scatterfocusMode, .problemCrunching)
        XCTAssertEqual(problem.problemQuestion, "How should I structure the migration?")
        XCTAssertEqual(problem.focusObject, "How should I structure the migration?")
        XCTAssertEqual(problem.plannedDuration, 10 * 60)

        await env.manager.endScatterfocusEarly()
        try await env.manager.submitReview(rating: nil, note: nil)

        let habitual = try await env.manager.startScatterfocus(mode: .habitual, minutes: 10)
        XCTAssertEqual(habitual.scatterfocusMode, .habitual)
        XCTAssertNil(habitual.problemQuestion)
        XCTAssertEqual(habitual.focusObject, "Scatterfocus: Habitual")
    }

    func testScatterfocusCapturesAreSessionAssociated() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let session = try await env.manager.startScatterfocus(mode: .capture, minutes: 10)
        await env.captures.add(text: "An unexpected connection", sessionID: session.id, source: .scatterfocus)
        await env.captures.add(text: "General note", sessionID: nil, source: .distraction)

        XCTAssertEqual(env.captures.captures(for: session.id).count, 1)
        XCTAssertEqual(env.captures.captures(for: session.id, source: .scatterfocus).first?.text, "An unexpected connection")

        await env.manager.endScatterfocusEarly()
        XCTAssertEqual(env.captures.captures(for: env.manager.pendingReview!.id).count, 1)
    }

    func testScatterfocusBlockingSuspensionPersists() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startScatterfocus(mode: .capture, minutes: 10)
        try await env.manager.setBlockingSuspended(true)

        XCTAssertEqual(env.manager.activeSession?.blockingSuspended, true)

        let restored = SessionManager(
            persistence: env.persistence,
            statsStore: env.stats,
            settingsStore: env.settings,
            dateProvider: { env.clock.now },
            automaticallyTicks: false
        )
        await restored.restore()
        XCTAssertEqual(restored.activeSession?.blockingSuspended, true)
    }

    func testScatterfocusEndsEarlyWithoutReason() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startScatterfocus(mode: .habitual, minutes: 10)
        env.clock.now = env.clock.now.addingTimeInterval(120)
        await env.manager.endScatterfocusEarly()

        XCTAssertEqual(env.manager.phase, .review)
        XCTAssertEqual(env.manager.pendingReview?.status, .endedEarly)
        XCTAssertEqual(env.manager.pendingReview?.scatterfocusMode, .habitual)
    }

    func testIntentionIsLinkedToSessionAndRecord() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let intention = try await env.intentions.add(text: "Finish the outline", on: env.clock.now)
        try await env.manager.startHyperfocus(
            focusObject: "Write section one",
            minutes: 50,
            intention: intention
        )

        XCTAssertEqual(env.manager.activeSession?.intentionID, intention.id)
        XCTAssertEqual(env.manager.activeSession?.intentionText, "Finish the outline")

        env.clock.now = env.clock.now.addingTimeInterval(50 * 60)
        await env.manager.refresh()
        try await env.manager.submitReview(rating: 4, note: nil)

        XCTAssertEqual(env.stats.sessions.first?.intentionID, intention.id)
        XCTAssertEqual(env.stats.sessions.first?.intentionText, "Finish the outline")
    }

    func testPendingReviewSurvivesRelaunch() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startHyperfocus(focusObject: "Review me", minutes: 25)
        env.clock.now = env.clock.now.addingTimeInterval(25 * 60)
        await env.manager.refresh()
        XCTAssertEqual(env.manager.phase, .review)

        let restored = SessionManager(
            persistence: env.persistence,
            statsStore: env.stats,
            settingsStore: env.settings,
            dateProvider: { env.clock.now },
            automaticallyTicks: false
        )
        await restored.restore()
        XCTAssertEqual(restored.phase, .review)
        XCTAssertEqual(restored.pendingReview?.focusObject, "Review me")

        try await restored.submitReview(rating: 3, note: "Resumed review")
        XCTAssertEqual(env.stats.sessions.first?.rating, 3)
        XCTAssertEqual(env.stats.sessions.first?.note, "Resumed review")
    }

    func testSaveAndStartBreakAfterReview() async throws {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        try await env.manager.startHyperfocus(focusObject: "Focus", minutes: 25)
        env.clock.now = env.clock.now.addingTimeInterval(25 * 60)
        await env.manager.refresh()

        try await env.manager.submitReview(rating: 5, note: nil, startBreakAfter: true)

        XCTAssertEqual(env.manager.phase, .scatterfocus)
        XCTAssertEqual(env.manager.activeSession?.scatterfocusMode, .capture)
        XCTAssertEqual(env.manager.activeSession?.plannedDuration, 10 * 60)
        XCTAssertEqual(env.stats.sessions.first?.rating, 5)
    }
}
