import XCTest

final class MenuBarLayoutUITests: XCTestCase {
    private var app: XCUIApplication!
    private var testDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )

        app = XCUIApplication()
        app.launchEnvironment["FOCUSBAR_UI_TEST_DIR"] = testDirectory.path
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }

    func testMenuBarPopoverLayout() throws {
        app.launch()

        let identifiedItem = app.statusItems["focusBarMenuBarItem"]
        if identifiedItem.waitForExistence(timeout: 10) {
            identifiedItem.click()
        } else {
            let labeledItem = app.statusItems["FocusBar idle"]
            XCTAssertTrue(
                labeledItem.waitForExistence(timeout: 5),
                "FocusBar did not expose a menu bar status item"
            )
            labeledItem.click()
        }

        XCTAssertTrue(app.staticTexts["FocusBar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What deserves your full attention?"].exists)
        XCTAssertTrue(app.staticTexts["ONE SPECIFIC FOCUS"].exists)
        XCTAssertTrue(app.buttons["History"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Quit"].exists)
        XCTAssertTrue(app.buttons["Enter a focus to start"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "FocusBar menu bar popover"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
