import AppKit
import XCTest

/// Manual/CI screenshot capture for the README. It uses a temporary data
/// directory with sample records so no personal FocusBar data is published.
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private var testDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarScreenshots-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
        try seedSampleData()

        app = XCUIApplication()
        app.launchEnvironment["FOCUSBAR_UI_TEST_DIR"] = testDirectory.path
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }

    func testCaptureReadmeScreenshots() throws {
        app.launch()
        openPopover()

        let idleTitle = app.staticTexts["FocusBar"]
        XCTAssertTrue(idleTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ship the FocusBar 1.0.1 release"].exists)
        attachCrop(popoverRect(topText: "FocusBar"), name: "01-idle")

        app.radioButtons["Scatterfocus"].click()
        XCTAssertTrue(
            app.staticTexts["Step back and let your mind wander."]
                .waitForExistence(timeout: 5)
        )
        attachCrop(popoverRect(topText: "FocusBar"), name: "02-scatterfocus")

        app.radioButtons["Hyperfocus"].click()
        XCTAssertTrue(
            app.staticTexts["What deserves your full attention?"]
                .waitForExistence(timeout: 5)
        )

        let focusField = app.textFields.firstMatch
        XCTAssertTrue(focusField.waitForExistence(timeout: 5))
        focusField.click()
        focusField.typeText("Write the launch announcement")

        let startButton = app.buttons["Start Hyperfocus"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.click()

        XCTAssertTrue(app.buttons["End early…"].waitForExistence(timeout: 8))
        attachCrop(popoverRect(topText: "Hyperfocus"), name: "03-hyperfocus")

        app.buttons["History"].click()
        XCTAssertTrue(
            app.staticTexts["FOCUS MINUTES · LAST 7 DAYS"].waitForExistence(timeout: 8)
        )
        let historyTitle = app.staticTexts["History"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5))
        let historyRect = CGRect(
            x: historyTitle.frame.minX - 16,
            y: historyTitle.frame.minY - 16,
            width: 640,
            height: 660
        )
        attachCrop(historyRect, name: "04-history")

        app.buttons["Done"].click()

        if !app.buttons["Settings"].exists {
            openPopover()
            XCTAssertTrue(app.staticTexts["FocusBar"].waitForExistence(timeout: 5))
        }
        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["FocusBar Settings"].firstMatch.waitForExistence(timeout: 8))

        // The Settings window title and the content header share the same text.
        // The content header is the lower match; use it to crop the content.
        let settingsTitles = app.staticTexts
            .matching(identifier: "FocusBar Settings")
            .allElementsBoundByIndex
        let contentTitle = settingsTitles.max { $0.frame.minY < $1.frame.minY }
            ?? app.staticTexts["FocusBar Settings"].firstMatch

        let settingsRect = CGRect(
            x: contentTitle.frame.minX - 20,
            y: contentTitle.frame.minY - 20,
            width: 580,
            height: 660
        )
        attachCrop(settingsRect, name: "05-settings")

        let syncTitle = app.staticTexts["SYNC ACROSS MACS"]
        XCTAssertTrue(syncTitle.waitForExistence(timeout: 5))
        // Clicking a scrolled-off macOS element brings it into view.
        syncTitle.click()
        XCTAssertTrue(syncTitle.isHittable)

        let presetsTitle = app.staticTexts["BLOCKLIST PRESETS"]
        let syncTop = syncTitle.frame.minY - 20
        let syncBottom = presetsTitle.exists
            ? presetsTitle.frame.minY - 16
            : syncTitle.frame.minY + 340
        let syncRect = CGRect(
            x: settingsRect.minX,
            y: syncTop,
            width: 570,
            height: max(260, syncBottom - syncTop)
        )
        attachCrop(syncRect, name: "06-settings-sync")
    }

    // MARK: - Popover

    private func openPopover() {
        let identifiedItem = app.statusItems["focusBarMenuBarItem"]
        if identifiedItem.waitForExistence(timeout: 10) {
            identifiedItem.click()
            return
        }

        let labeledItem = app.statusItems["FocusBar idle"]
        XCTAssertTrue(
            labeledItem.waitForExistence(timeout: 5),
            "FocusBar did not expose a menu bar status item"
        )
        labeledItem.click()
    }

    // MARK: - Attachments

    private func popoverRect(topText: String) -> CGRect {
        let title = app.staticTexts[topText].frame
        let quit = app.buttons["Quit"].frame
        let rect = CGRect(
            x: title.minX - 16,
            y: title.minY - 16,
            width: (quit.maxX + 16) - (title.minX - 16),
            height: (quit.maxY + 9) - (title.minY - 16)
        )
        return rect.insetBy(dx: -2, dy: -2)
    }

    private func attachCrop(_ rect: CGRect, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        guard let cgImage = screenshot.image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixelRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return }
        let bitmap = NSBitmapImageRep(cgImage: cropped)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }

        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Sample data

    private func seedSampleData() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)
                ?? today.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
                ?? day.addingTimeInterval(TimeInterval(hour * 3_600 + minute * 60))
        }

        let intentionShip = UUID()
        let intentionLaunch = UUID()
        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let thirdSessionID = UUID()
        let fourthSessionID = UUID()
        let fifthSessionID = UUID()
        let scatterSessionID = UUID()
        let presetID = UUID()

        let intentions = [
            IntentionFixture(
                id: intentionShip,
                text: "Ship the FocusBar 1.0.1 release",
                day: today,
                createdAt: date(daysAgo: 0, hour: 8, minute: 35)
            ),
            IntentionFixture(
                id: intentionLaunch,
                text: "Write the launch announcement",
                day: today,
                createdAt: date(daysAgo: 0, hour: 8, minute: 38)
            )
        ]

        let sessions = [
            SessionFixture(
                id: firstSessionID,
                kind: "hyperfocus",
                focusObject: "Write the launch announcement",
                intentionID: intentionLaunch,
                intentionText: "Write the launch announcement",
                plannedDuration: 50 * 60,
                startDate: date(daysAgo: 0, hour: 9, minute: 10),
                status: "completed",
                rating: 5,
                note: "Drafted the announcement and tightened the screenshots.",
                blocklistName: "Social media"
            ),
            SessionFixture(
                id: secondSessionID,
                kind: "hyperfocus",
                focusObject: "Review the analytics dashboard",
                plannedDuration: 25 * 60,
                startDate: date(daysAgo: 0, hour: 14, minute: 0),
                status: "completed",
                rating: 4,
                note: "Closed the remaining analytics tickets.",
                blocklistName: "Social media"
            ),
            SessionFixture(
                id: thirdSessionID,
                kind: "hyperfocus",
                focusObject: "Finish the onboarding flow",
                plannedDuration: 90 * 60,
                startDate: date(daysAgo: 1, hour: 10, minute: 0),
                status: "completed",
                rating: 5,
                blocklistName: "Social media"
            ),
            SessionFixture(
                id: fourthSessionID,
                kind: "hyperfocus",
                focusObject: "Deep work: API refactor",
                plannedDuration: 50 * 60,
                startDate: date(daysAgo: 2, hour: 9, minute: 30),
                status: "completed",
                rating: 4,
                blocklistName: "Social media"
            ),
            SessionFixture(
                id: fifthSessionID,
                kind: "hyperfocus",
                focusObject: "Plan next week",
                plannedDuration: 25 * 60,
                startDate: date(daysAgo: 4, hour: 13, minute: 0),
                status: "completed",
                rating: 3,
                blocklistName: "Social media"
            ),
            SessionFixture(
                id: scatterSessionID,
                kind: "scatterfocus",
                focusObject: "Scatterfocus: Capture",
                scatterfocusMode: "capture",
                plannedDuration: 10 * 60,
                startDate: date(daysAgo: 6, hour: 11, minute: 0),
                status: "completed",
                blocklistName: "Social media"
            )
        ]

        let captures = [
            CaptureFixture(
                id: UUID(),
                text: "Check the pricing page copy",
                createdAt: date(daysAgo: 0, hour: 9, minute: 28),
                sessionID: firstSessionID,
                source: "distraction"
            ),
            CaptureFixture(
                id: UUID(),
                text: "Ask whether the changelog needs screenshots",
                createdAt: date(daysAgo: 0, hour: 9, minute: 46),
                sessionID: firstSessionID,
                source: "distraction"
            ),
            CaptureFixture(
                id: UUID(),
                text: "Look up the retention chart definition",
                createdAt: date(daysAgo: 0, hour: 14, minute: 8),
                sessionID: secondSessionID,
                source: "distraction"
            ),
            CaptureFixture(
                id: UUID(),
                text: "Idea: add a weekly review note",
                createdAt: date(daysAgo: 6, hour: 11, minute: 5),
                sessionID: scatterSessionID,
                source: "scatterfocus"
            )
        ]

        let attempts = [
            BlockedAttemptFixture(
                id: UUID(),
                timestamp: date(daysAgo: 0, hour: 10, minute: 30),
                sessionID: firstSessionID,
                kind: "website",
                identifier: "youtube.com",
                displayName: "YouTube",
                browserName: "Safari",
                actionDetail: "Redirected the active tab to the FocusBar block page."
            ),
            BlockedAttemptFixture(
                id: UUID(),
                timestamp: date(daysAgo: 0, hour: 10, minute: 45),
                sessionID: firstSessionID,
                kind: "application",
                identifier: "com.hnc.Discord",
                displayName: "Discord",
                actionDetail: "Hid the app."
            ),
            BlockedAttemptFixture(
                id: UUID(),
                timestamp: date(daysAgo: 1, hour: 11, minute: 20),
                sessionID: thirdSessionID,
                kind: "website",
                identifier: "x.com",
                displayName: "X / Twitter",
                browserName: "Google Chrome",
                actionDetail: "Redirected the active tab to the FocusBar block page."
            ),
            BlockedAttemptFixture(
                id: UUID(),
                timestamp: date(daysAgo: 2, hour: 15, minute: 10),
                sessionID: fourthSessionID,
                kind: "website",
                identifier: "reddit.com",
                displayName: "Reddit",
                browserName: "Safari",
                actionDetail: "Redirected the active tab to the FocusBar block page."
            ),
            BlockedAttemptFixture(
                id: UUID(),
                timestamp: date(daysAgo: 5, hour: 16, minute: 0),
                sessionID: nil,
                kind: "website",
                identifier: "instagram.com",
                displayName: "Instagram",
                browserName: "Safari",
                actionDetail: "Redirected the active tab to the FocusBar block page."
            )
        ]

        let settings = SettingsFixture(
            notificationsEnabled: false,
            blockApps: true,
            blockWebsites: false,
            presets: [
                PresetFixture(
                    id: presetID,
                    name: "Social media",
                    websiteDomains: [
                        "x.com", "facebook.com", "instagram.com", "tiktok.com",
                        "reddit.com", "linkedin.com", "youtube.com"
                    ],
                    apps: [AppFixture(bundleID: "com.apple.Calculator", name: "Calculator")],
                    isBuiltIn: true
                )
            ],
            selectedPresetID: presetID
        )

        try writeEnvelope(settings, to: "settings.json")
        try writeEnvelope(sessions, to: "sessions.json")
        try writeEnvelope(
            IntentionFileFixture(intentions: intentions, skippedDays: []),
            to: "intentions.json"
        )
        try writeEnvelope(captures, to: "captures.json")
        try writeEnvelope(attempts, to: "blockedAttempts.json")
    }

    private func writeEnvelope<T: Encodable>(_ payload: T, to filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(Envelope(schemaVersion: 1, payload: payload))
        try data.write(to: testDirectory.appendingPathComponent(filename), options: .atomic)
    }
}

// MARK: - Fixtures matching the app's versioned JSON envelope

private struct Envelope<T: Encodable>: Encodable {
    var schemaVersion: Int
    var payload: T
}

private struct SessionFixture: Encodable {
    var id: UUID
    var kind: String
    var focusObject: String
    var intentionID: UUID?
    var intentionText: String?
    var scatterfocusMode: String?
    var plannedDuration: TimeInterval
    var startDate: Date
    var status: String
    var rating: Int?
    var note: String?
    var blockingSuspended = false
    var blocklistName: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, focusObject, intentionID, intentionText, scatterfocusMode
        case plannedDuration, startDate, plannedEndDate, actualEndDate
        case status, rating, note, blockingSuspended, blocklistName
    }

    init(
        id: UUID,
        kind: String,
        focusObject: String,
        intentionID: UUID? = nil,
        intentionText: String? = nil,
        scatterfocusMode: String? = nil,
        plannedDuration: TimeInterval,
        startDate: Date,
        status: String,
        rating: Int? = nil,
        note: String? = nil,
        blocklistName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.focusObject = focusObject
        self.intentionID = intentionID
        self.intentionText = intentionText
        self.scatterfocusMode = scatterfocusMode
        self.plannedDuration = plannedDuration
        self.startDate = startDate
        self.status = status
        self.rating = rating
        self.note = note
        self.blocklistName = blocklistName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(focusObject, forKey: .focusObject)
        try container.encodeIfPresent(intentionID, forKey: .intentionID)
        try container.encodeIfPresent(intentionText, forKey: .intentionText)
        try container.encodeIfPresent(scatterfocusMode, forKey: .scatterfocusMode)
        try container.encode(plannedDuration, forKey: .plannedDuration)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(startDate.addingTimeInterval(plannedDuration), forKey: .plannedEndDate)
        try container.encode(startDate.addingTimeInterval(plannedDuration), forKey: .actualEndDate)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(blockingSuspended, forKey: .blockingSuspended)
        try container.encodeIfPresent(blocklistName, forKey: .blocklistName)
    }
}

private struct IntentionFixture: Encodable {
    var id: UUID
    var text: String
    var day: Date
    var createdAt: Date
}

private struct IntentionFileFixture: Encodable {
    var intentions: [IntentionFixture]
    var skippedDays: [Date]
}

private struct CaptureFixture: Encodable {
    var id: UUID
    var text: String
    var createdAt: Date
    var sessionID: UUID?
    var source: String
}

private struct BlockedAttemptFixture: Encodable {
    var id: UUID
    var timestamp: Date
    var sessionID: UUID?
    var kind: String
    var identifier: String
    var displayName: String
    var browserName: String?
    var actionDetail: String?
}

private struct SettingsFixture: Encodable {
    var notificationsEnabled: Bool
    var blockApps: Bool
    var blockWebsites: Bool
    var presets: [PresetFixture]
    var selectedPresetID: UUID
}

private struct PresetFixture: Encodable {
    var id: UUID
    var name: String
    var websiteDomains: [String]
    var apps: [AppFixture]
    var isBuiltIn: Bool
}

private struct AppFixture: Encodable {
    var bundleID: String
    var name: String
}
