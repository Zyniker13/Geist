// MU-P8.1 accessibility UI tests.
//
// The launch-argument path proves the flags reach the model and the
// renderer (the debug overlay's `a11y` row is the observable surface);
// the menu-toggle path proves the in-app toggles persist and light the
// same rows. Both run on the standard overlay launch.

import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        GameUITest.clearFileConfig()
    }

    override func tearDownWithError() throws {
        GameUITest.clearFileConfig()
    }

    /// `-uitest-reduce-motion` lights the overlay's `a11y rm` row: the
    /// flag reached the model, which the surfaces relay to the renderer
    /// (1-in-4 decimation + flutter snap).
    func testReduceMotionLaunchArgument() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 1,
            extra: ["-uitest-reduce-motion"]
        )
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "a11y row never appeared")
        XCTAssertTrue(
            GameUITest.rowText(of: row).contains("rm"),
            "expected the rm flag, got: \(GameUITest.rowText(of: row))"
        )
    }

    /// `-uitest-high-contrast` lights `a11y hc`.
    func testHighContrastLaunchArgument() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 1,
            extra: ["-uitest-high-contrast"]
        )
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "a11y row never appeared")
        XCTAssertTrue(
            GameUITest.rowText(of: row).contains("hc"),
            "expected the hc flag, got: \(GameUITest.rowText(of: row))"
        )
    }

    /// The menu toggles persist: toggling Reduce Motion, launching a day,
    /// then relaunching fresh (no flags) still shows `rm` — and the menu
    /// toggle comes back on.
    func testMenuTogglePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest-overlay",
            "-uitest-region", "meadow",
            "-uitest-days", "1",
            "-uitest-trace",
        ]
        app.launch()

        let play = app.buttons["menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "menu Play button missing")
        let toggle = app.switches["menu.reduceMotion"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Reduce Motion toggle missing")
        toggle.tap()
        play.tap()

        // The play session carries the setting.
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "a11y row never appeared")
        XCTAssertTrue(
            GameUITest.rowText(of: row).contains("rm"),
            "expected rm in the play session, got: \(GameUITest.rowText(of: row))"
        )

        // Relaunch with no arguments: the persisted profile re-applies it.
        GameUITest.clearFileConfig()
        app.terminate()
        app.launchArguments = [
            "-uitest-overlay",
            "-uitest-region", "meadow",
            "-uitest-days", "1",
            "-uitest-trace",
        ]
        app.launch()
        let play2 = app.buttons["menu.play"]
        XCTAssertTrue(play2.waitForExistence(timeout: 10), "menu Play button missing on relaunch")
        let toggle2 = app.switches["menu.reduceMotion"]
        XCTAssertTrue(
            toggle2.waitForExistence(timeout: 10),
            "Reduce Motion toggle missing on relaunch"
        )
        let value2 = toggle2.value as? String
        XCTAssertEqual(value2, "1", "toggle did not persist across relaunch: \(String(describing: value2))")
        play2.tap()
        let row2 = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row2.waitForExistence(timeout: 30), "a11y row missing after relaunch")
        XCTAssertTrue(
            GameUITest.rowText(of: row2).contains("rm"),
            "rm did not survive the relaunch"
        )

        // Leave the profile clean for other tests.
        toggle2.tap()
        var metaClean = false
        for _ in 0..<10 where (app.switches["menu.reduceMotion"].value as? String) == "0" {
            metaClean = true
            break
        }
        XCTAssertTrue(metaClean, "toggle did not clear")
    }
}
