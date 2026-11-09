import XCTest
@testable import FocusBar

final class BlockingPlanTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(
        kind: SessionKind = .hyperfocus,
        suspended: Bool = false
    ) -> ActiveSession {
        ActiveSession(
            kind: kind,
            focusObject: "Focus",
            plannedDuration: 25 * 60,
            startDate: start,
            endDate: start.addingTimeInterval(25 * 60),
            blockingSuspended: suspended
        )
    }

    private var preset: BlocklistPreset {
        BlocklistPreset(
            name: "Test",
            websiteDomains: ["x.com", "example.com"],
            apps: [BlockedApp(bundleID: "com.example.app", name: "Example")]
        )
    }

    func testHyperfocusEnablesConfiguredBlockers() {
        let plan = BlockingPlan.make(
            session: session(),
            preset: preset,
            settings: .defaults(),
            blockedPageAvailable: true
        )

        XCTAssertTrue(plan.appBlockingEnabled)
        XCTAssertTrue(plan.websiteBlockingEnabled)
        XCTAssertEqual(plan.appCount, 1)
        XCTAssertEqual(plan.domainCount, 2)
        XCTAssertFalse(plan.suspended)
        XCTAssertTrue(plan.notes.isEmpty)
    }

    func testSystemWideBlockingUsesExpandedHostnames() {
        var settings = AppSettings.defaults()
        settings.systemWideWebsiteBlockingEnabled = true
        settings.blockWebsites = false

        let plan = BlockingPlan.make(
            session: session(),
            preset: preset,
            settings: settings,
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.systemWebsiteBlockingEnabled)
        XCTAssertGreaterThan(plan.systemHostnameCount, plan.domainCount)
    }

    func testSystemWideBlockingFollowsScatterfocusSuspension() {
        var settings = AppSettings.defaults()
        settings.systemWideWebsiteBlockingEnabled = true

        let plan = BlockingPlan.make(
            session: session(kind: .scatterfocus, suspended: true),
            preset: preset,
            settings: settings,
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.systemWebsiteBlockingEnabled)
        XCTAssertEqual(plan.systemHostnameCount, 0)
    }

    func testScatterfocusBlockingCanBeDisabledInSettings() {
        var settings = AppSettings.defaults()
        settings.blockDuringScatterfocus = false

        let plan = BlockingPlan.make(
            session: session(kind: .scatterfocus),
            preset: preset,
            settings: settings,
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.appBlockingEnabled)
        XCTAssertFalse(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.notes.contains { $0.contains("Scatterfocus") })
    }

    func testSuspendedBreakDisablesBlockers() {
        let plan = BlockingPlan.make(
            session: session(kind: .scatterfocus, suspended: true),
            preset: preset,
            settings: .defaults(),
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.appBlockingEnabled)
        XCTAssertFalse(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.suspended)
        XCTAssertTrue(plan.notes.contains { $0.contains("suspended") })
    }

    func testNoPresetDisablesBlocking() {
        let plan = BlockingPlan.make(
            session: session(),
            preset: nil,
            settings: .defaults(),
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.appBlockingEnabled)
        XCTAssertFalse(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.notes.contains { $0.contains("No blocklist") })
    }

    func testMissingBlockedPageDisablesWebsiteBlockerOnly() {
        let plan = BlockingPlan.make(
            session: session(),
            preset: preset,
            settings: .defaults(),
            blockedPageAvailable: false
        )

        XCTAssertTrue(plan.appBlockingEnabled)
        XCTAssertFalse(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.notes.contains { $0.contains("blocked page") })
    }

    func testEmptyAppListIsReported() {
        let emptyApps = BlocklistPreset(name: "Sites only", websiteDomains: ["x.com"])
        let plan = BlockingPlan.make(
            session: session(),
            preset: emptyApps,
            settings: .defaults(),
            blockedPageAvailable: true
        )

        XCTAssertFalse(plan.appBlockingEnabled)
        XCTAssertTrue(plan.websiteBlockingEnabled)
        XCTAssertTrue(plan.notes.contains { $0.contains("No applications") })
    }

    func testTerminateRequestsAreLabelledBestEffort() {
        var settings = AppSettings.defaults()
        settings.appBlockingAction = .requestTerminate
        let plan = BlockingPlan.make(
            session: session(),
            preset: preset,
            settings: settings,
            blockedPageAvailable: true
        )
        XCTAssertTrue(plan.notes.contains { $0.contains("best-effort") })
    }
}

@MainActor
final class BlockedAttemptStoreTests: XCTestCase {
    func testRecordsAndCountsAttempts() async {
        let env = TestEnvironment()
        await env.loadAll()
        defer { env.cleanup() }

        let sessionID = UUID()
        let now = env.clock.now
        await env.attempts.record(
            BlockedAttempt(
                timestamp: now,
                sessionID: sessionID,
                kind: .application,
                identifier: "com.example.app",
                displayName: "Example"
            )
        )
        await env.attempts.record(
            BlockedAttempt(
                timestamp: now.addingTimeInterval(60),
                sessionID: nil,
                kind: .website,
                identifier: "x.com",
                displayName: "x.com",
                browserName: "Safari"
            )
        )

        XCTAssertEqual(env.attempts.count(sessionID: sessionID), 1)
        XCTAssertEqual(env.attempts.count(on: now), 2)
        XCTAssertEqual(env.attempts.totalCount, 2)

        let reloaded = BlockedAttemptStore(persistence: env.persistence)
        await reloaded.load()
        XCTAssertEqual(reloaded.totalCount, 2)
    }
}

final class AppleScriptRunnerTests: XCTestCase {
    func testSuccessfulScript() async {
        let runner = AppleScriptRunner()
        let result = await runner.run(script: #"return "hello""#, timeout: 3)
        XCTAssertEqual(try? result.get(), "hello")
    }

    func testTimeoutIsReported() async {
        let runner = AppleScriptRunner()
        let result = await runner.run(script: "delay 10", timeout: 0.4)
        guard case .failure(.timedOut) = result else {
            return XCTFail("Expected timedOut, got \(result)")
        }
    }

    func testPermissionErrorIsMapped() async {
        let runner = AppleScriptRunner()
        let script = #"error "Not authorized to send Apple events to Safari." number -1743"#
        let result = await runner.run(script: script, timeout: 3)
        guard case .failure(.permissionDenied) = result else {
            return XCTFail("Expected permissionDenied, got \(result)")
        }
    }

    func testExecutionErrorIsReported() async {
        let runner = AppleScriptRunner()
        let result = await runner.run(script: #"error "boom""#, timeout: 3)
        guard case .failure(.executionFailed(let message)) = result else {
            return XCTFail("Expected executionFailed, got \(result)")
        }
        XCTAssertTrue(message.contains("boom"))
    }
}

final class AppSettingsDecodingTests: XCTestCase {
    func testMissingFieldsFallBackToDefaults() throws {
        let json = #"{"commitMode":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.commitMode)
        XCTAssertTrue(settings.blockApps)
        XCTAssertTrue(settings.blockWebsites)
        XCTAssertFalse(settings.systemWideWebsiteBlockingEnabled)
        XCTAssertFalse(settings.restartMozillaBrowsersOnSessionChange)
        XCTAssertTrue(settings.blockDuringScatterfocus)
        XCTAssertEqual(settings.appBlockingAction, .hide)
        XCTAssertEqual(settings.presets.count, 1)
        XCTAssertEqual(settings.selectedPresetID, settings.presets.first?.id)
        XCTAssertTrue(settings.notificationsEnabled)
        XCTAssertEqual(settings.earlyEndDelaySeconds, 0)
    }

    func testEarlyEndDelayDecodesStoredValue() throws {
        let json = #"{"earlyEndDelaySeconds":20}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.earlyEndDelaySeconds, 20)
    }

    func testSystemWideBlockingDecodesStoredValue() throws {
        let json = #"{"systemWideWebsiteBlockingEnabled":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertTrue(settings.systemWideWebsiteBlockingEnabled)
    }

    func testMozillaRestartDecodesStoredValue() throws {
        let json = #"{"restartMozillaBrowsersOnSessionChange":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertTrue(settings.restartMozillaBrowsersOnSessionChange)
    }

    func testUnknownSelectedPresetFallsBackToFirst() throws {
        let json = """
        {
          "commitMode": false,
          "presets": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "name": "Only",
              "websiteDomains": ["example.com"],
              "apps": [],
              "isBuiltIn": false
            }
          ],
          "selectedPresetID": "22222222-2222-2222-2222-222222222222"
        }
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.selectedPresetID?.uuidString, "11111111-1111-1111-1111-111111111111")
    }
}

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testEarlyEndDelayNormalizesToSupportedOptions() async {
        let env = TestEnvironment()
        await env.settings.load()
        defer { env.cleanup() }

        await env.settings.update { $0.earlyEndDelaySeconds = 20 }
        XCTAssertEqual(env.settings.settings.earlyEndDelaySeconds, 20)

        await env.settings.update { $0.earlyEndDelaySeconds = 7 }
        XCTAssertEqual(env.settings.settings.earlyEndDelaySeconds, 0)

        await env.settings.update { $0.earlyEndDelaySeconds = -5 }
        XCTAssertEqual(env.settings.settings.earlyEndDelaySeconds, 0)
    }
}
