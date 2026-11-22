import XCTest

/// Shared helpers for the G2 UI tests (three-day autoplay, pause/resume
/// hashes, and the 3,000-bird perf probe).
enum GameUITest {
    /// The app's own defaults domain, shared with the runner through
    /// UserDefaults(suiteName:) — a flags channel independent of /tmp
    /// (MULaunch.swift reads it when the config file is unusable).
    static let defaultsSuite = "com.example.murmuration"
    /// A runner-written file the app never writes: MULaunch records
    /// whether the app can see it, which distinguishes a /tmp access
    /// failure from a never-running startup path.
    static let probePath = "/tmp/mu-uitest-probe.txt"

    /// Launch args that start the game immediately with the Autoplayer.
    static func launch(
        app: XCUIApplication,
        region: String = "meadow",
        days: Int = 1,
        fast: Int? = nil,
        pauseAt: Int? = nil,
        birds: Int? = nil,
        falcons: Int? = nil,
        hash: Bool = false,
        tutorial: Bool = false,
        versus: Bool = false,
        autoplay: Bool = true,
        difficulty: String? = nil
    ) {
        var args = [
            "-uitest-overlay",
            "-uitest-play",
        ]
        if autoplay {
            args += ["-uitest-autoplay"]
        }
        args += ["-uitest-region", region, "-uitest-days", String(days)]
        if tutorial {
            args += ["-uitest-tutorial"]
        }
        if versus {
            args += ["-uitest-versus"]
        }
        if let difficulty {
            args += ["-uitest-difficulty", difficulty]
        }
        // Trace the app's own log lines ([MU] …) into the xcodebuild output so
        // a failing tutorial run can be diagnosed after the fact.
        args += ["-uitest-trace"]
        if let fast {
            args += ["-uitest-fast", String(fast)]
        }
        if let pauseAt {
            args += ["-uitest-pause-at", String(pauseAt)]
        }
        if let birds {
            args += ["-uitest-birds", String(birds)]
        }
        if let falcons {
            args += ["-uitest-falcons", String(falcons)]
        }
        if hash {
            args += ["-uitest-hash"]
        }
        args += ["-uitest-trace"]
        #if os(macOS)
            // The macOS runner has dropped launchArguments in CI (the app sat on
            // the menu with no trace file), and locally a bare-exec launch with
            // this flag set in argv can stall the SwiftUI scene pipeline before
            // the root view builds (see ADR-0015). So on macOS the flags travel
            // ONLY by file and by the app's defaults domain; MULaunch prefers
            // the file, then the defaults channel, then an environment-variable
            // channel (MU_UITEST_FLAGS) that always works on CI. Bound to
            // MULaunch.configPath/defaultsSuiteKey/envKey.
            try? args.joined(separator: "\n").write(
                toFile: "/tmp/mu-uitest-config.txt", atomically: true, encoding: .utf8
            )
            try? "probe".write(toFile: GameUITest.probePath, atomically: true, encoding: .utf8)
            let suite = UserDefaults(suiteName: GameUITest.defaultsSuite)
            suite?.set(args, forKey: "mu-flags")
        #else
            app.launchArguments = args
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
            try? FileManager.default.removeItem(atPath: GameUITest.probePath)
            let suite = UserDefaults(suiteName: GameUITest.defaultsSuite)
            suite?.removeObject(forKey: "mu-flags")
            suite?.removeObject(forKey: "mu-note")
        #endif
    }

    /// The program-done card, queried platform-agnostically (the SwiftUI
    /// container exposes as different element types on iOS and macOS).
    static func finalElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "game.final").firstMatch
    }

    /// The tutorial completion banner (P3.2), queried platform-agnostically.
    static func tutorialCompleteElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tutorial.complete").firstMatch
    }

    /// Wait for the program-done card and return the final hash label.
    static func finalHash(app: XCUIApplication, timeout: TimeInterval = 240) -> String {
        let final = finalElement(app)
        guard final.waitForExistence(timeout: timeout) else {
            dumpTrace()
            XCTFail("the game never reached program done")
            return ""
        }
        // Re-resolve the row on every read: an element reference captured
        // before the final card appeared can serve a stale snapshot whose
        // label is empty even though a fresh query sees the value (the
        // runner log of run 44403531737 shows both behaviors minutes apart).
        let hashRow = overlayRow(app: app, identifier: "debug.hash")
        guard hashRow.waitForExistence(timeout: 10) else {
            dumpTree(app)
            return ""
        }
        let label = rowText(of: hashRow)
        // "hash <16 hex>" — strip the prefix.
        if let space = label.firstIndex(of: " ") {
            return String(label[label.index(after: space)...])
        }
        return label
    }

    /// Overlay rows expose their identifier and text on one element per
    /// platform (ADR-0019, final): the app publishes each row as a
    /// `.accessibilityElement(children: .ignore)` leaf with an explicit
    /// `.accessibilityLabel`, so the identifier and the text land on the
    /// same element on both platforms (iOS StaticText, macOS Other). The
    /// earlier shapes (identifier on a wrapper, or text only as value) came
    /// from relying on SwiftUI synthesis; the CI AX-tree dump in run
    /// 44445425461 shows the macOS leaf previously carried only the
    /// identifier. Find by identifier across element types and read the
    /// text through rowText: value first, then label, then the first
    /// StaticText child.
    static func overlayRow(app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The overlay row's readable text. The app sets an explicit
    /// accessibilityLabel on each row (ADR-0019), so label is the primary
    /// read after value; the first StaticText child remains a fallback for
    /// any element that still surfaces a synthesized text child.
    static func rowText(of row: XCUIElement) -> String {
        if let value = row.value as? String, !value.isEmpty {
            return value
        }
        let label = row.label
        if !label.isEmpty {
            return label
        }
        return row.staticTexts.firstMatch.label
    }

    /// A row text that has stopped changing. The overlay polls the model
    /// every 0.5 s, so a read right after pausing can still carry the
    /// pre-pause snapshot (the poll fires late on a slow runner); aiming a
    /// gesture at that stale string is the run-44921826085 flake. Read,
    /// wait one poll cycle, and re-read until two consecutive reads agree
    /// (or give up after `rounds` and return the last read).
    static func stableRowText(
        of row: XCUIElement, rounds: Int = 4, interval: TimeInterval = 0.6
    ) -> String {
        var last = rowText(of: row)
        for _ in 0..<rounds {
            Thread.sleep(forTimeInterval: interval)
            let next = rowText(of: row)
            if next == last { return next }
            last = next
        }
        return last
    }

    /// Read an integer from an overlay row labelled "<prefix> <value>".
    static func intValue(of row: XCUIElement, prefix: String) -> Int? {
        guard row.exists else { return nil }
        let label = rowText(of: row)
        guard label.hasPrefix(prefix) else { return nil }
        let rest = label.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return Int(rest.split(separator: " ").first.map(String.init) ?? "")
    }

    /// Normalized (0–1) position in the app frame for a world point, inverting
    /// the render transform (`FlockRenderer.worldPoint`). The MTKView fills the
    /// frame, so the normalized position is independent of the screen scale:
    /// it depends only on the frame's aspect ratio and the world size.
    static func normalizedPoint(
        forWorld world: (x: Double, y: Double),
        worldSize: (w: Double, h: Double),
        app: XCUIApplication
    ) -> CGPoint {
        let frame = app.windows.firstMatch.frame
        let viewW = frame.width
        let viewH = frame.height
        let worldW = worldSize.w
        let worldH = worldSize.h
        let s = min(viewW / worldW, viewH / worldH)
        let sx = 2 * s / viewW
        let sy = 2 * s / viewH
        let nx = (world.x - worldW / 2) * sx
        let ny = (worldH / 2 - world.y) * sy
        return CGPoint(x: (nx + 1) / 2, y: (1 - ny) / 2)
    }

    /// Parse "L0 x,y L1 x,y" leader labels into per-flock world positions.
    /// The label alternates id and position tokens.
    static func parseLeaders(_ text: String) -> [(x: Double, y: Double)] {
        var result: [(x: Double, y: Double)] = []
        let tokens = text.split(separator: " ")
        var index = 0
        while index + 1 < tokens.count {
            let id = tokens[index]
            let position = tokens[index + 1]
            if id.hasPrefix("L"), id.count > 1, Int(id.dropFirst()) != nil {
                let parts = position.split(separator: ",")
                if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
                    result.append((x, y))
                }
            }
            index += 2
        }
        return result
    }

    /// Peak FPS over independent ~2 s overlay windows: CI runners dip under
    /// co-tenant load, so a single-window read flakes; the peak shows what
    /// the machine sustains in at least one quiet window. Each read
    /// re-resolves the row by identifier: a captured reference goes stale
    /// while the sampled overlay re-renders (2 Hz) and its label reads back
    /// empty even though a fresh query sees the value.
    static func sampleFpsPeak(
        app: XCUIApplication, identifier: String, reads: Int = 6, spacing: TimeInterval = 2
    ) -> Int? {
        var peak: Int?
        for _ in 0..<reads {
            if let row = resolvedRow(app: app, identifier: identifier),
                let value = intValue(of: row, prefix: "FPS")
            {
                peak = max(peak ?? 0, value)
            }
            Thread.sleep(forTimeInterval: spacing)
        }
        return peak
    }

    /// Median frame-build ms over independent ~2 s overlay windows: a single
    /// sample spikes under co-tenant load, so the median (robust to transient
    /// spikes) is the gate metric; it still fails if the typical frame build
    /// exceeds budget (ADR-0014). Re-resolves the row per read (see
    /// sampleFpsPeak).
    static func sampleFrameMedian(
        app: XCUIApplication, identifier: String, reads: Int = 6, spacing: TimeInterval = 2
    ) -> Double? {
        var samples: [Double] = []
        for _ in 0..<reads {
            if let row = resolvedRow(app: app, identifier: identifier),
                let value = frameMs(of: row)
            {
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

    /// A fresh element query: the caller must not reuse a reference across
    /// overlay re-renders, because the cached AX snapshot can serve an empty
    /// label for a row that a new query reads correctly.
    private static func resolvedRow(app: XCUIApplication, identifier: String) -> XCUIElement? {
        let row = overlayRow(app: app, identifier: identifier)
        return row.exists ? row : nil
    }

    /// Parse "frame 3.21ms" → 3.21.
    private static func frameMs(of row: XCUIElement) -> Double? {
        let label = rowText(of: row)
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
            dumpDefaults()
        #endif
    }

    /// Prints the app's accessibility element tree into the runner log:
    /// the ground truth for "which overlay rows exist and what their
    /// labels read" (ADR-0015 debugging, macOS AX churn diagnosis).
    static func dumpTree(_ app: XCUIApplication) {
        print("[MU-TREE] begin")
        print(app.debugDescription)
        print("[MU-TREE] end")
    }

    #if os(macOS)
        /// The defaults mirror lives in the app's prefs plist — a channel
        /// independent of /tmp. Empty here means either the app's startup
        /// code never ran or the app is sandboxed (its defaults would live
        /// inside the container instead, which the container check and the
        /// direct plist read below still surface).
        private static func dumpDefaults() {
            let suite = UserDefaults(suiteName: GameUITest.defaultsSuite)
            let note = suite?.stringArray(forKey: "mu-note") ?? []
            if note.isEmpty {
                print("[MU-NOTE-DEFAULTS] empty (app never wrote, or its defaults are containerized)")
            } else {
                print("[MU-NOTE-DEFAULTS] begin")
                for line in note {
                    print("[MU-NOTE-DEFAULTS] \(line)")
                }
                print("[MU-NOTE-DEFAULTS] end")
            }
            let container = NSString(
                string: "~/Library/Containers/com.example.murmuration"
            ).expandingTildeInPath
            let sandboxed = FileManager.default.fileExists(atPath: container)
            print(
                "[MU-SANDBOX] app container exists=\(sandboxed)"
                    + " (true ⇒ the app is sandboxed on this machine)"
            )
            let containerPlist = container + "/Data/Library/Preferences/com.example.murmuration.plist"
            if let data = FileManager.default.contents(atPath: containerPlist),
                let plist = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil
                ) as? [String: Any],
                let note = plist["mu-note"] as? [String]
            {
                print("[MU-NOTE-CONTAINER] begin")
                for line in note {
                    print("[MU-NOTE-CONTAINER] \(line)")
                }
                print("[MU-NOTE-CONTAINER] end")
            } else {
                print("[MU-NOTE-CONTAINER] no container plist note")
            }
        }
    #endif

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
