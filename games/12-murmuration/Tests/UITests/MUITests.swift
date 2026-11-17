import XCTest

/// iPad smoke: the placeholder menu launches and the debug overlay is present when
/// requested via launch argument (S0.4, S0.7).
final class MUITests: XCTestCase {
    func testMenuLaunchesWithOverlay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-overlay"]
        app.launch()

        let overlay = app.otherElements["debug.overlay"]
        let seedRow = app.staticTexts["debug.seed"]
        XCTAssertTrue(
            overlay.waitForExistence(timeout: 10) || seedRow.waitForExistence(timeout: 5),
            "debug overlay did not appear with -uitest-overlay"
        )

        let play = app.buttons["menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "placeholder menu Play button missing")
    }

    func testMenuLaunchesWithoutOverlay() throws {
        let app = XCUIApplication()
        app.launch()

        let play = app.buttons["menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "placeholder menu Play button missing")

        let overlay = app.otherElements["debug.overlay"]
        XCTAssertFalse(overlay.exists, "debug overlay must be hidden by default")
    }
}
