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
        #if os(macOS)
            // The macOS runner has dropped launchArguments in CI (the app sat on
            // the menu with no trace file), so the flags also travel by file;
            // the app's MULaunch prefers the file when present. Bound to
            // MULaunch.configPath in the app.
            try? args.joined(separator: "\n").write(
                toFile: "/tmp/mu-uitest-config.txt", atomically: true, encoding: .utf8
            )
        #endif
        app.launch()
        #if os(macOS)
            // A background/occluded window pauses MTKView's display link, so the
            // gate run must hold the frontmost window for ticks to flow.
            app.activate()
        #endif
    }

    /// Plain app.launch() paths (menu tests) must not inherit a stale config
    /// file from an earlier gate test, or the app would auto-play.
    static func clearFileConfig() {
        #if os(macOS)
            try? FileManager.default.removeItem(atPath: "/tmp/mu-uitest-config.txt")
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

    /// Median frame-build ms over independent ~2 s overlay windows: a single
    /// sample spikes under co-tenant load, so the median (robust to transient
    /// spikes) is the gate metric; it still fails if the typical frame build
    /// exceeds budget (ADR-0014).
    static func sampleFrameMedian(
        row: XCUIElement, reads: Int = 6, spacing: TimeInterval = 2
    ) -> Double? {
        var samples: [Double] = []
        for _ in 0..<reads {
            if row.exists, let value = frameMs(of: row) {
                samples.append(value)
            }
            Thread.sleep(forTimeInterval: spacing)
        }
        guard !samples.isEmpty else { return nil }
        samples.sort()
        let mid = samples.count / 2
        return samples.count.isMultiple(of: 2)
            ? (samples[mid - 1] + samples[mid]) / 2
            : samples[mid]
    }

    /// Parse "frame 3.21ms" → 3.21.
    private static func frameMs(of row: XCUIElement) -> Double? {
        let label = row.label
        guard let start = label.range(of: "frame ") else { return nil }
        let rest = label[start.upperBound...]
        guard let end = rest.range(of: "ms") else { return nil }
        return Double(rest[..<end.lowerBound].trimmingCharacters(in: .whitespaces))
    }

    /// Prints the app-side diagnostic files into the runner log on failure:
    /// the launched app's stdout is not captured on macOS, so the gate
    /// tests surface its playback trace through the runner instead. The
    /// note file is unconditional (launch facts, trace-write failures);
    /// the trace file only exists when -uitest-trace took effect.
    static func dumpTrace() {
        #if os(macOS)
            dump(file: "/tmp/mu-uitest-note.log", tag: "MU-NOTE")
            dump(file: "/tmp/mu-uitest-trace.log", tag: "MU-TRACE")
        #endif
    }

    #if os(macOS)
        private static func dump(file: String, tag: String) {
            guard let text = try? String(contentsOfFile: file, encoding: .utf8), !text.isEmpty else {
                print("[\(tag)] no file at \(file) (app never wrote one)")
                return
            }
            print("[\(tag)] begin")
            for line in text.split(separator: "\n") {
                print("[\(tag)] \(line)")
            }
            print("[\(tag)] end")
        }
    #endif
}
