import XCTest

/// G2 vertical-slice checks on macOS: a full night runs to the results
/// screen, and real mouse/keyboard input drives the map and HUD.
///
/// The Mac harness allows genuine clicks and key events (the headless
/// iPad-simulator rotation problem does not apply), so element interactions
/// are used directly instead of launch arguments.
final class NMUITestsMac: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    /// "Walkway N/M" from the HUD's budget line.
    private func budgetUsed(_ app: XCUIApplication) -> Int? {
        let label = app.staticTexts["budget-hud"].label
        let digits = label.components(separatedBy: CharacterSet.decimalDigits.inverted)
        guard let used = digits.first, let value = Int(used) else { return nil }
        return value
    }

    func testFullNightToResultsMac() throws {
        let app = launch("-uitest-fast", "-uitest-fresh", "-uitest-autochoose", "-uitest-debug")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        app.activate()

        // Real mouse drag paints a lane from the west edge toward the plaza
        // (NM-P2.6: click-drag paint). A first click wakes the view; the
        // drag is deliberately slow so mouseDragged events fan out.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        usleep(300_000)
        for dy in [0.5, 0.55] {
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: dy))
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: dy))
            start.press(forDuration: 0.4, thenDragTo: end)
            let deadline = Date().addingTimeInterval(6)
            while Date() < deadline {
                if let used = budgetUsed(app), used > 0 { break }
                usleep(300_000)
            }
            if let used = budgetUsed(app), used > 0 { break }
        }
        XCTAssertGreaterThan(
            budgetUsed(app) ?? 0, 0,
            "mouse drag should paint walkway tiles (window \(window.frame))")

        // Real click pauses and resumes (NM-P2.6: space pause / HUD pause).
        let pause = app.buttons["pause-button"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        pause.click()
        XCTAssertEqual(pause.label, "paused", "clicking pause must pause the night")
        pause.click()
        XCTAssertEqual(pause.label, "running", "clicking pause again must resume")

        // The scripted fast night runs itself to the results screen.
        let results = app.descendants(matching: .any)["results-screen"]
        XCTAssertTrue(results.waitForExistence(timeout: 180), "results screen did not appear")
        let next = app.buttons["next-night-button"]
        let found =
            next.waitForExistence(timeout: 5)
            || app.buttons["next-night"].waitForExistence(timeout: 2)
            || app.descendants(matching: .any)["next-night-button"].firstMatch.exists
        XCTAssertTrue(found, "results screen should offer the next night")
        app.terminate()
    }
}
