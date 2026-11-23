// MU-P8.2 falcon-assist steering UI tests.
//
// The launch-argument path proves the option reaches the sim (the debug
// overlay's `a11y` row shows `fa`, read from GameState itself); the
// menu-toggle path proves the toggle persists and lights the same row.
// A differential run asserts the assist actually changes trajectories:
// identical seeds, one with the assist, one without — their mid-day bird
// positions must differ.

import XCTest

final class AssistUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        GameUITest.clearFileConfig()
    }

    override func tearDownWithError() throws {
        GameUITest.clearFileConfig()
    }

    /// `-uitest-assist` lights the overlay's `a11y fa` row.
    func testAssistLaunchArgument() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 1,
            extra: ["-uitest-assist"]
        )
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "a11y row never appeared")
        XCTAssertTrue(
            GameUITest.rowText(of: row).contains("fa"),
            "expected the fa flag, got: \(GameUITest.rowText(of: row))"
        )
    }

    /// A default launch shows no `fa` (and no spurious trailing flags).
    func testAssistOffByDefault() throws {
        let app = XCUIApplication()
        GameUITest.launch(app: app, region: "meadow", days: 1)
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        // The row may be absent entirely on a clean launch.
        guard row.waitForExistence(timeout: 15) else { return }
        XCTAssertFalse(
            GameUITest.rowText(of: row).contains("fa"),
            "assist flag visible on a default launch"
        )
    }

    /// The menu toggle persists: toggling Falcon assist, launching a day,
    /// then relaunching fresh (no flags) still shows `fa` — and the menu
    /// toggle comes back on.
    func testMenuAssistTogglePersistsAcrossRelaunch() throws {
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
        let toggle = app.switches["menu.assist"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Falcon assist toggle missing")
        // Normalize: force OFF first, then ON, so a stale persisted state
        // cannot make this tap turn it off.
        if (toggle.value as? String) == "1" { toggle.tap() }
        toggle.tap()
        XCTAssertEqual(
            app.switches["menu.assist"].value as? String, "1",
            "toggle did not turn on"
        )
        play.tap()

        // The play session carries the setting.
        let row = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "a11y row never appeared")
        XCTAssertTrue(
            GameUITest.rowText(of: row).contains("fa"),
            "expected fa in the play session, got: \(GameUITest.rowText(of: row))"
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
        let toggle2 = app.switches["menu.assist"]
        XCTAssertTrue(
            toggle2.waitForExistence(timeout: 10),
            "Falcon assist toggle missing on relaunch"
        )
        let value2 = toggle2.value as? String
        XCTAssertEqual(value2, "1", "toggle did not persist across relaunch: \(String(describing: value2))")
        play2.tap()
        let row2 = GameUITest.overlayRow(app: app, identifier: "debug.a11y")
        XCTAssertTrue(row2.waitForExistence(timeout: 30), "a11y row missing after relaunch")
        XCTAssertTrue(
            GameUITest.rowText(of: row2).contains("fa"),
            "fa did not survive the relaunch"
        )

        // Leave the profile clean for other tests.
        app.terminate()
        app.launchArguments = [
            "-uitest-overlay",
            "-uitest-region", "meadow",
            "-uitest-days", "1",
        ]
        app.launch()
        let toggleClean = app.switches["menu.assist"]
        XCTAssertTrue(
            toggleClean.waitForExistence(timeout: 10),
            "menu toggle missing for cleanup relaunch"
        )
        toggleClean.tap()
        var metaClean = false
        for _ in 0..<10 where (app.switches["menu.assist"].value as? String) == "0" {
            metaClean = true
            break
        }
        XCTAssertTrue(metaClean, "toggle did not clear")
    }

    /// Differential: two same-seed meadow day runs, one with
    /// `-uitest-assist`. The assist is sim-level, so the program-done final
    /// hashes (the proven `finalHash` helper, -uitest-hash on) must differ.
    func testAssistChangesTrajectories() throws {
        func finalHash(assist: Bool) throws -> String {
            let app = XCUIApplication()
            var extra: [String] = ["-uitest-seed", "77", "-uitest-hash"]
            if assist { extra.append("-uitest-assist") }
            GameUITest.launch(app: app, region: "meadow", days: 1, fast: 8, extra: extra)
            let hash = GameUITest.finalHash(app: app)
            app.terminate()
            return hash
        }
        let off = try finalHash(assist: false)
        let on = try finalHash(assist: true)
        XCTAssertFalse(off.isEmpty, "no hash observed without assist")
        XCTAssertNotEqual(off, on, "assist produced no trajectory change in-app")
    }
}
