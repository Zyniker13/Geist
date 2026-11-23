// MU-P8.3 thermal soak: 30 minutes of real-time play with thermal-state
// sampling. The gate budget is "no serious thermal state within 30
// minutes of play" on iPad (A16); the local substitute runs the app on
// the iPad simulator for 30 minutes and samples ProcessInfo.thermalState
// (which on a simulator reflects the host machine's thermal pressure —
// the signal the simulator can expose). Real-device verification is a
// maintainer item.
//
// The test is env-gated (MU_SOAK=1) and XCTSkips otherwise so the
// standard suite stays within its budget; the soak is launched
// explicitly for the G8 evidence run.

import XCTest

final class ThermalSoakTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        GameUITest.clearFileConfig()
    }

    override func tearDownWithError() throws {
        GameUITest.clearFileConfig()
    }

    func testThirtyMinuteThermalSoak() throws {
        guard ProcessInfo.processInfo.environment["MU_SOAK"] == "1" else {
            throw XCTSkip("thermal soak runs only under MU_SOAK=1 (30 min)")
        }

        let app = XCUIApplication()
        // A long day count keeps the day loop running for the whole soak;
        // the exact number does not matter because the run ends by timeout.
        GameUITest.launch(app: app, region: "meadow", days: 40)
        let fpsRow = GameUITest.overlayRow(app: app, identifier: "debug.fps")
        XCTAssertTrue(fpsRow.waitForExistence(timeout: 30), "overlay missing in soak run")

        let log = "/tmp/mu-thermal-soak.log"
        try "\(Date()) soak start\n".write(toFile: log, atomically: true, encoding: .utf8)

        let start = Date()
        var worst: ProcessInfo.ThermalState = .nominal
        var samples = 0
        var fpsFloor = Int.max
        while Date().timeIntervalSince(start) < 30 * 60 {
            Thread.sleep(forTimeInterval: 30)
            let state = ProcessInfo.processInfo.thermalState
            worst = max(worst, state)
            samples += 1
            let fps = GameUITest.intValue(of: fpsRow, prefix: "FPS") ?? 0
            if fps > 0 { fpsFloor = min(fpsFloor, fps) }
            let line = "[\(Int(-start.timeIntervalSinceNow))s] thermal=\(state) fps=\(fps)"
            let existing = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
            try (existing + line + "\n").write(toFile: log, atomically: true, encoding: .utf8)
            // The app must still be alive and ticking.
            XCTAssertTrue(app.state == .runningForeground, "app left the foreground mid-soak")
        }

        let summary = "soak done samples=\(samples) worst=\(worst.rawValue) fpsFloor=\(fpsFloor == Int.max ? -1 : fpsFloor)\n"
        let existing = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
        try (existing + summary).write(toFile: log, atomically: true, encoding: .utf8)

        XCTAssertGreaterThanOrEqual(samples, 59, "soak collected too few samples")
        XCTAssertLessThan(
            worst.rawValue, ProcessInfo.ThermalState.serious.rawValue,
            "thermal state reached serious during the soak"
        )
    }
}
