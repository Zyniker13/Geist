// MU-P8.3 thermal soak: 30 minutes of real-time play with thermal-state
// sampling. The gate budget is "no serious thermal state within 30
// minutes of play" on iPad (A16); the local substitute runs the app on
// the iPad simulator for 30 minutes and samples ProcessInfo.thermalState
// (which on a simulator reflects the host machine's thermal pressure —
// the signal the simulator can expose). Real-device verification is a
// maintainer item.
//
// The test gates itself on the MU_SOAK environment variable reaching the
// TEST RUNNER (xcodebuild forwards it with the TEST_RUNNER_ prefix; a
// bare MU_SOAK=1 on the xcodebuild command line does NOT reach the
// runner), and XCTSkips without it so the standard suite stays within
// its budget. Evidence command: TEST_RUNNER_MU_SOAK=1 xcodebuild test
// -only-testing:MUITests/ThermalSoakTests/testThirtyMinuteThermalSoak
//
// The sample log goes to the runner's temp directory and is printed in
// full at the end, so the evidence survives in the xcodebuild log even
// if the temp file is swept mid-run.

import XCTest

final class ThermalSoakTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        GameUITest.clearFileConfig()
    }

    override func tearDownWithError() throws {
        GameUITest.clearFileConfig()
    }

    func testThirtyMinuteThermalSoak() throws {
        guard ProcessInfo.processInfo.environment["MU_SOAK"] == "1" else {
            throw XCTSkip("thermal soak runs only under TEST_RUNNER_MU_SOAK=1 (30 min)")
        }

        // A large day count keeps the sim ticking for the whole soak; the
        // exact number does not matter because the run ends by timeout.
        GameUITest.launch(app: app, region: "meadow", days: 200)
        let fpsRow = GameUITest.overlayRow(app: app, identifier: "debug.fps")
        XCTAssertTrue(fpsRow.waitForExistence(timeout: 30), "overlay missing in soak run")

        let log = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mu-thermal-soak.log").path
        try "\(Date()) soak start\n".write(toFile: log, atomically: true, encoding: .utf8)

        let start = Date()
        var worstRaw = 0
        var samples = 0
        var fpsFloor = Int.max
        while Date().timeIntervalSince(start) < 30 * 60 {
            Thread.sleep(forTimeInterval: 30)
            let state = ProcessInfo.processInfo.thermalState
            worstRaw = max(worstRaw, state.rawValue)
            samples += 1
            let fps = GameUITest.intValue(of: fpsRow, prefix: "FPS") ?? 0
            if fps > 0 { fpsFloor = min(fpsFloor, fps) }
            let line = "[\(Int(-start.timeIntervalSinceNow))s] thermal=\(state.rawValue) fps=\(fps)"
            let existing = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
            try (existing + line + "\n").write(toFile: log, atomically: true, encoding: .utf8)
            // The app must still be alive and ticking.
            XCTAssertTrue(app.state == .runningForeground, "app left the foreground mid-soak")
        }

        let summary = "soak done samples=\(samples) worst=\(worstRaw) fpsFloor=\(fpsFloor == Int.max ? -1 : fpsFloor)\n"
        let existing = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
        try (existing + summary).write(toFile: log, atomically: true, encoding: .utf8)
        print("THERMAL-SOAK-LOG-BEGIN")
        print((try? String(contentsOfFile: log, encoding: .utf8)) ?? "log unreadable")
        print("THERMAL-SOAK-LOG-END")

        XCTAssertGreaterThanOrEqual(samples, 59, "soak collected too few samples")
        XCTAssertLessThan(
            worstRaw, ProcessInfo.ThermalState.serious.rawValue,
            "thermal state reached serious during the soak"
        )
    }
}
