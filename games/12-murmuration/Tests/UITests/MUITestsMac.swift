import XCTest

/// Mac smoke: the placeholder menu launches, and ⌘⇧D toggles the debug overlay (S0.4, S0.7).
final class MUITestsMac: XCTestCase {
    func testMenuLaunches() throws {
        GameUITest.clearFileConfig()
        let app = XCUIApplication()
        app.launch()

        let play = app.buttons["menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "placeholder menu Play button missing")

        let overlay = app.otherElements["debug.overlay"]
        XCTAssertFalse(overlay.exists, "debug overlay must be hidden by default")
    }

    func testCommandShiftDTogglesOverlay() throws {
        GameUITest.clearFileConfig()
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["menu.play"].waitForExistence(timeout: 10))
        app.typeKey("d", modifierFlags: [.command, .shift])

        let overlay = app.otherElements["debug.overlay"]
        let seedRow = GameUITest.overlayRow(app: app, identifier: "debug.seed")
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
        let final = GameUITest.finalElement(app)
        guard final.waitForExistence(timeout: 240) else {
            GameUITest.dumpTrace()
            XCTFail("three autoplay days never completed")
            return
        }
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
        // The FPS row only exists in the live game overlay; waiting on it is
        // platform-agnostic and, if the session never started, the fps
        // assertion below still fails on the 0 from the menu overlay.
        let fpsRow = GameUITest.overlayRow(app: app, identifier: "debug.fps")
        guard fpsRow.waitForExistence(timeout: 15) else {
            GameUITest.dumpTrace()
            GameUITest.dumpTree(app)
            XCTFail("overlay missing in perf run")
            return
        }

        Thread.sleep(forTimeInterval: 2)
        let fps = GameUITest.sampleFpsPeak(app: app, identifier: "debug.fps")
        XCTAssertNotNil(fps, "no FPS reading over six sampled windows")
        XCTAssertGreaterThanOrEqual(fps ?? 0, 55, "fps below the 60 Hz display cap")

        // Median frame-build ms over independent ~2 s windows: a single sample
        // spikes under co-tenant load (ADR-0014). The budget is the display
        // slot of the host the test runs on. The CI runner's virtual display
        // is 60 Hz (ADR-0017): 16.0 ms fits its 16.67 ms slot with margin. The
        // roadmap's 120 fps Mac check (≤8.33 ms build) needs real 120 Hz
        // hardware — maintainer issue, local substitute recorded there.
        let frameMs = GameUITest.sampleFrameMedian(app: app, identifier: "debug.frame")
        guard let frameMs else {
            GameUITest.dumpTrace()
            GameUITest.dumpTree(app)
            XCTFail("no frame-cost reading over six sampled windows")
            return
        }
        XCTAssertLessThanOrEqual(
            frameMs, 16.0,
            "frame build \(frameMs)ms exceeds the 60 Hz display slot (16.67 ms)"
        )
    }
}
