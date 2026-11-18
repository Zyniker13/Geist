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
        app.launchArguments = args
        app.launch()
    }

    /// Wait for the program-done card and return the final hash label.
    static func finalHash(app: XCUIApplication, timeout: TimeInterval = 240) -> String {
        let final = app.otherElements["game.final"]
        XCTAssertTrue(
            final.waitForExistence(timeout: timeout),
            "the game never reached program done"
        )
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
}
