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

/// G2 gate checks (Mac).
final class MUGateTestsMac: XCTestCase {
    /// Plays three days with Autoplayer-generated actions.
    func testThreeDayAutoplay() throws {
        let app = XCUIApplication()
        GameUITest.launch(app: app, region: "meadow", days: 3, fast: 120)
        let final = app.otherElements["game.final"]
        XCTAssertTrue(
            final.waitForExistence(timeout: 240),
            "three autoplay days never completed"
        )
    }

    /// A self-pause + resume at mid-day must not perturb the deterministic
    /// stream: the final hash equals an uninterrupted run's.
    func testPauseResumePreservesHash() throws {
        let appA = XCUIApplication()
        GameUITest.launch(app: appA, region: "meadow", days: 1, fast: 60, hash: true)
        let hashA = GameUITest.finalHash(app: appA)
        appA.terminate()

        let appB = XCUIApplication()
        GameUITest.launch(
            app: appB, region: "meadow", days: 1, fast: 60, pauseAt: 2400, hash: true
        )
        let hashB = GameUITest.finalHash(app: appB)

        XCTAssertFalse(hashA.isEmpty, "run A produced no hash")
        XCTAssertEqual(hashA, hashB, "pause/resume changed the final state hash")
    }

    /// 3,000 birds at the display refresh with frame budget to spare. The
    /// host display is 60 Hz (P0 finding); real 120 fps hardware is issue #11.
    func testPerfFrameBudgetWithThreeThousandBirds() throws {
        let app = XCUIApplication()
        GameUITest.launch(app: app, region: "meadow", birds: 3000)
        let overlay = app.otherElements["debug.overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 15), "overlay missing in perf run")

        Thread.sleep(forTimeInterval: 5)

        let fpsRow = app.staticTexts["debug.fps"]
        let frameRow = app.staticTexts["debug.frame"]
        let fps = GameUITest.intValue(of: fpsRow, prefix: "FPS")
        XCTAssertNotNil(fps, "no FPS reading: \(fpsRow.label)")
        XCTAssertGreaterThanOrEqual(fps!, 55, "fps below the 60 Hz display cap")

        let frameLabel = frameRow.exists ? frameRow.label : ""
        let frameMs = frameLabel
            .replacingOccurrences(of: "frame ", with: "")
            .replacingOccurrences(of: "ms", with: "")
        if let value = Double(frameMs) {
            XCTAssertLessThanOrEqual(
                value, 8.4,
                "frame build \(value)ms exceeds the 8.33 ms (120 fps) budget"
            )
        } else {
            XCTFail("no frame-cost reading: \(frameLabel)")
        }
    }
}
