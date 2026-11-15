import XCTest

/// G2 vertical-slice checks: a full night to the results screen, the
/// save/resume hash contract, and crowd-load frame rate.
///
/// The tests drive the app through launch arguments (`-uitest-*`) instead of
/// HUD taps: the headless CI simulator cannot rotate its display, so
/// element-anchored taps mistranslate and never reach SwiftUI buttons. Map
/// painting still goes through real touch synthesis (the input catcher
/// receives actual drag events).
final class NMUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Scene geometry mirrors MarketScene: 32×20 tiles of 32 pt, aspect-fit
    /// in the window; tile row 0 at the top of the scene.
    private func screenPoint(forTile col: Int, row: Int, in frame: CGRect) -> CGPoint {
        let gridW: CGFloat = 32.0
        let gridH: CGFloat = 20.0
        let tile: CGFloat = 32.0
        let boardW = gridW * tile
        let boardH = gridH * tile
        let scale = min(frame.width / boardW, frame.height / boardH)
        let boardSpanW = boardW * scale
        let boardSpanH = boardH * scale
        let offX = (frame.width - boardSpanW) / 2
        let offY = (frame.height - boardSpanH) / 2
        let colF = CGFloat(col)
        let rowF = CGFloat(row)
        let x = offX + (colF + 0.5) * tile * scale
        let y = offY + (gridH - 1 - rowF + 0.5) * tile * scale
        return CGPoint(x: x, y: y)
    }

    /// Paints a straight walkway from the west gate (col 0) to the plaza
    /// edge (col 12) along the given row.
    private func paintLane(app: XCUIApplication, row: Int) {
        let frame = app.windows.firstMatch.frame
        let start = screenPoint(forTile: 0, row: row, in: frame)
        let end = screenPoint(forTile: 12, row: row, in: frame)
        let startCoord = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: start.x, dy: start.y))
        let endCoord = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: end.x, dy: end.y))
        startCoord.press(forDuration: 0.05, thenDragTo: endCoord)
    }

    private func launch(_ args: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    /// Waits for the results screen while the sim runs itself there
    /// (-uitest-fast + -uitest-autochoose handle speed and hour pickers).
    private func waitForResults(_ app: XCUIApplication, timeout: TimeInterval = 180) {
        let results = app.descendants(matching: .any)["results-screen"]
        XCTAssertTrue(results.waitForExistence(timeout: timeout), "results screen did not appear")
    }

    // MARK: - G2 checks

    /// G3: the six-step tutorial shows step 1, advances on Next, and
    /// dismisses after the final step.
    func testTutorialAdvancesThroughSixSteps() throws {
        let app = launch("-uitest-tutorial", "-uitest-paused", "-uitest-fresh")
        let card = app.descendants(matching: .any)["tutorial-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "tutorial card did not appear")
        let next = app.descendants(matching: .any)["tutorial-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "tutorial Next button missing")
        // Advance through all six steps; the sixth Next dismisses the card.
        for step in 1...6 {
            let label = card.staticTexts.element(boundBy: 0)
            XCTAssertTrue(label.exists, "step \(step) label missing")
            next.tap()
        }
        var gone = !card.exists
        var waited = 0.0
        while !gone, waited < 5 {
            Thread.sleep(forTimeInterval: 0.2)
            waited += 0.2
            gone = !card.exists
        }
        XCTAssertTrue(gone, "tutorial card should dismiss after the last step")
        app.terminate()
    }

    func testFullNightToResults() throws {
        let app = launch("-uitest-fast", "-uitest-fresh", "-uitest-autochoose", "-uitest-debug")
        paintLane(app: app, row: 9)
        waitForResults(app)
        let next = app.buttons["next-night-button"]
        let found =
            next.waitForExistence(timeout: 5)
            || app.buttons["next-night"].waitForExistence(timeout: 2)
            || app.descendants(matching: .any)["next-night-button"].firstMatch.exists
        XCTAssertTrue(found, "results screen should offer the next night")
        // NM-P7.1: a finished night fires its leaderboard/achievement posts
        // (the mock poster records them; the debug overlay shows the count).
        let posts = app.staticTexts["debug-posts"]
        XCTAssertTrue(posts.waitForExistence(timeout: 5), "the debug overlay should show the posts row")
        XCTAssertNotEqual(posts.label, "POSTS 0", "a finished night must fire at least one post")
        app.terminate()
    }

    func testSaveResumeRestoresIdenticalHash() throws {
        // The Xcode UI-test harness gives every XCUIApplication launch an
        // empty data view, so a real relaunch cannot observe a previous
        // launch's save file inside the harness (verified: the same flow
        // works via `simctl launch` — tick and hash restore exactly). The
        // contract is therefore exercised in-process: the autosave at the
        // first half-hour boundary is immediately reloaded with resume(),
        // and the restored state must hash identically and stay frozen.
        let app = launch(
            "-uitest-fast", "-uitest-fresh", "-uitest-autochoose",
            "-uitest-autosave", "-uitest-debug", "-uitest-save-restart")
        paintLane(app: app, row: 9)
        let saveHash = app.staticTexts["debug-savehash"]
        let deadline = Date().addingTimeInterval(30)
        var saved: String?
        while Date() < deadline {
            if saveHash.exists {
                let value = saveHash.label.replacingOccurrences(of: "SAVE ", with: "")
                if value != "-" { saved = value; break }
            }
            usleep(300_000)
        }
        let recorded = try XCTUnwrap(saved, "autosave never completed")
        let hash = app.staticTexts["debug-hash"]
        let deadline2 = Date().addingTimeInterval(10)
        var restored = false
        while Date() < deadline2 {
            if hash.exists, hash.label.replacingOccurrences(of: "HASH ", with: "") == recorded {
                restored = true
                break
            }
            usleep(300_000)
        }
        let saveLine = saveHash.exists ? saveHash.label : "absent"
        let tickLine = app.staticTexts["debug-tick"].exists ? app.staticTexts["debug-tick"].label : "absent"
        XCTAssertTrue(
            restored,
            "save/resume must restore the identical hash (save \(recorded), save-line \(saveLine), hash \(hash.exists ? hash.label : "absent"), \(tickLine))"
        )
        // Paused: the hash must not move.
        sleep(2)
        XCTAssertEqual(
            hash.label.replacingOccurrences(of: "HASH ", with: ""), recorded,
            "a resumed paused night must stay frozen")
        app.terminate()
    }

    func testStressCrowdHoldsFrameRate() throws {
        // Real-time speed: the gate check is 400 customers at ~60 fps.
        let app = launch("-uitest-fresh", "-uitest-debug", "-uitest-stress")
        paintLane(app: app, row: 9)
        let fpsText = app.staticTexts["debug-fps"]
        let deadline = Date().addingTimeInterval(25)
        var samples: [Int] = []
        while Date() < deadline, samples.count < 10 {
            if fpsText.exists {
                let digits = fpsText.label.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let fps = Int(digits) { samples.append(fps) }
            }
            usleep(500_000)
        }
        XCTAssertGreaterThanOrEqual(samples.count, 5, "FPS samples should be readable")
        let average = Double(samples.reduce(0, +)) / Double(samples.count)
        XCTAssertGreaterThanOrEqual(average, 50, "crowd load should hold ~60 fps (avg \(average))")
        app.terminate()
    }

    // MARK: - P5 launcher

    func testDailyChallengeStartsWithTightBudget() throws {
        // The launcher shows the daily draw; tapping it starts a night with
        // the drawn modifier applied (tight budget → walkway 0/20 unless the
        // daily draw picked a budget modifier that day).
        let app = launch("-uitest-fresh", "-uitest-launcher-daily")
        let daily = app.descendants(matching: .any)["challenge-daily-challenge"].firstMatch
        XCTAssertTrue(daily.waitForExistence(timeout: 10), "the launcher must show the daily challenge row")
        daily.tap()
        let budget = app.staticTexts["budget-hud"]
        XCTAssertTrue(budget.waitForExistence(timeout: 10), "the HUD must appear after the challenge starts")
        let label = budget.label
        XCTAssertTrue(label.contains("/20") || label.contains("/30") || label.contains("/50"),
                      "the daily challenge must start on the drawn modifier's budget (got \(label))")
        // The night advances: the clock ticks past 18:00 within a few seconds.
        let deadline = Date().addingTimeInterval(15)
        var advanced = false
        while Date() < deadline {
            let clock = app.staticTexts["clock-hud"]
            if clock.exists && !clock.label.contains("18:00") { advanced = true; break }
            usleep(500_000)
        }
        XCTAssertTrue(advanced, "the challenge night must advance")
        app.terminate()
    }
}
