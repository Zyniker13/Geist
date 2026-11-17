import XCTest

/// Mac smoke: the placeholder menu launches, and ⌘⇧D toggles the debug overlay (S0.4, S0.7).
final class MUITestsMac: XCTestCase {
    func testMenuLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        let play = app.buttons["menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "placeholder menu Play button missing")

        let overlay = app.otherElements["debug.overlay"]
        XCTAssertFalse(overlay.exists, "debug overlay must be hidden by default")
    }

    func testCommandShiftDTogglesOverlay() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["menu.play"].waitForExistence(timeout: 10))
        app.typeKey("d", modifierFlags: [.command, .shift])

        let overlay = app.otherElements["debug.overlay"]
        let seedRow = app.staticTexts["debug.seed"]
        XCTAssertTrue(
            overlay.waitForExistence(timeout: 5) || seedRow.waitForExistence(timeout: 5),
            "⌘⇧D did not reveal the debug overlay"
        )

        app.typeKey("d", modifierFlags: [.command, .shift])
        XCTAssertFalse(overlay.waitForExistence(timeout: 2), "⌘⇧D did not hide the debug overlay")
    }
}
