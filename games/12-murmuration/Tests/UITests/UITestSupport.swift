import XCTest

/// Shared helpers for the G2 UI tests (three-day autoplay, pause/resume
/// hashes, and the 3,000-bird perf probe).
enum GameUITest {
    /// Launch args that start the game immediately with the Autoplayer.
    static func launch(
        app: XCUIApplication,
        region: String = "meadow",
        days: Int = 1,
        fast: Int? = nil,
        pauseAt: Int? = nil,
        birds: Int? = nil,
        hash: Bool = false
    ) {
        var args = [
            "-uitest-overlay",
            "-uitest-play",
            "-uitest-autoplay",
            "-uitest-region", region,
            "-uitest-days", String(days),
        ]
        if let fast {
            args += ["-uitest-fast", String(fast)]
        }
        if let pauseAt {
            args += ["-uitest-pause-at", String(pauseAt)]
        }
        if let birds {
            args += ["-uitest-birds", String(birds)]
        }
        if hash {
            args += ["-uitest-hash"]
        }
        args += ["-uitest-trace"]
        app.launchArguments = args
        app.launch()
        #if os(macOS)
        // A background/occluded window pauses MTKView's display link, so the
        // gate run must hold the frontmost window for ticks to flow.
        app.activate()
        #endif
    }

    /// The program-done card, queried platform-agnostically (the SwiftUI
    /// container exposes as different element types on iOS and macOS).
    static func finalElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "game.final").firstMatch
    }

    /// Wait for the program-done card and return the final hash label.
    static func finalHash(app: XCUIApplication, timeout: TimeInterval = 240) -> String {
        let final = finalElement(app)
        guard final.waitForExistence(timeout: timeout) else {
            dumpTrace()
            XCTFail("the game never reached program done")
            return ""
        }
        let hashRow = app.staticTexts["debug.hash"]
        guard hashRow.waitForExistence(timeout: 10) else {
            return ""
        }
        let label = hashRow.label
        // "hash <16 hex>" — strip the prefix.
        if let space = label.firstIndex(of: " ") {
            return String(label[label.index(after: space)...])
        }
        return label
    }

    /// Read an integer from an overlay row labelled "<prefix> <value>".
    static func intValue(of row: XCUIElement, prefix: String) -> Int? {
        guard row.exists else { return nil }
        let label = row.label
        guard label.hasPrefix(prefix) else { return nil }
        let rest = label.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return Int(rest.split(separator: " ").first.map(String.init) ?? "")
    }

    /// Peak FPS over independent ~2 s overlay windows: CI runners dip under
    /// co-tenant load, so a single-window read flakes; the peak shows what
    /// the machine sustains in at least one quiet window.
    static func sampleFpsPeak(
        row: XCUIElement, reads: Int = 6, spacing: TimeInterval = 2
    ) -> Int? {
        var peak: Int?
        for _ in 0..<reads {
            if let value = intValue(of: row, prefix: "FPS") {
                peak = max(peak ?? 0, value)
            }
            Thread.sleep(forTimeInterval: spacing)
        }
        return peak
    }

    /// Prints the app-side trace mirror into the runner log on failure:
    /// the launched app's stdout is not captured on macOS, so the gate
    /// tests surface its playback trace through the runner instead.
    static func dumpTrace() {
        #if os(macOS)
        let path = "/tmp/mu-uitest-trace.log"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8), !text.isEmpty else {
            print("[MU-TRACE] no trace file at \(path) (app never wrote one)")
            return
        }
        print("[MU-TRACE] begin")
        for line in text.split(separator: "\n") {
            print("[MU-TRACE] \(line)")
        }
        print("[MU-TRACE] end")
        #endif
    }
}
