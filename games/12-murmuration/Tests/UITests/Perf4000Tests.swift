// MU-P8.3 / G8: 4,000-bird performance evidence on the largest region the
// engine ships. The GATE asks for 120 fps on iPad Pro M4 and 60 fps on
// iPad (A16); both are real-device checks (issue #11). The simulator
// substitutes: display-link fps is capped by the host refresh (60 Hz), and
// the meaningful local signal is the FRAME-BUILD MEDIAN staying inside the
// 60 Hz slot (16 ms) with fps at the host cap. Env-gated with
// TEST_RUNNER_MU_G8PERF=1 so CI stays fast; the G8 evidence run invokes it
// explicitly.

import XCTest

final class Perf4000Tests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        GameUITest.clearFileConfig()
    }

    override func tearDownWithError() throws {
        GameUITest.clearFileConfig()
    }

    func testFrameBudgetWithFourThousandBirds() throws {
        guard ProcessInfo.processInfo.environment["MU_G8PERF"] == "1" else {
            throw XCTSkip("4,000-bird perf runs only under TEST_RUNNER_MU_G8PERF=1")
        }

        GameUITest.launch(app: app, region: "meadow", birds: 4000)
        let fpsRow = GameUITest.overlayRow(app: app, identifier: "debug.fps")
        XCTAssertTrue(fpsRow.waitForExistence(timeout: 30), "overlay missing in 4000-bird perf run")

        // Several independent ~2 s windows; fps takes the peak, frame ms
        // the median (ADR-0014).
        Thread.sleep(forTimeInterval: 2)
        let fps = GameUITest.sampleFpsPeak(app: app, identifier: "debug.fps")
        XCTAssertNotNil(fps, "no FPS reading at 4,000 birds")
        XCTAssertGreaterThanOrEqual(fps ?? 0, 55, "fps below the 60 Hz display cap at 4,000 birds")

        let frameMs = GameUITest.sampleFrameMedian(app: app, identifier: "debug.frame")
        guard let frameMs else {
            XCTFail("no frame-cost reading at 4,000 birds")
            return
        }
        XCTAssertLessThanOrEqual(
            frameMs, 16.0,
            "frame build \(frameMs)ms at 4,000 birds exceeds the 16.0 ms (60 Hz) budget (ADR-0017)"
        )
        print("MU-G8PERF fps=\(fps ?? -1) frameMs=\(frameMs)")
    }
}
