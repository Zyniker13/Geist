// Murmuration app — effective UI-test flags (single source of truth).
//
// macOS XCUI runners have dropped XCUIApplication.launchArguments in CI
// runs: the app sat on the menu, no trace file appeared, and every gate
// test timed out waiting for state that required -uitest-play. So on
// macOS the test harness also publishes the flags on two channels the
// app reads at startup — a file and the app's own defaults domain
// (UserDefaults(suiteName:) from the runner shares the app's plist).
// Resolution order: file, then defaults, then process arguments
// unchanged (local headless runs, iOS). The note log mirrors everything
// into the defaults domain too, so the runner can read the app's own
// launch facts back even when the /tmp file write fails.

import Foundation

enum MULaunch {
    #if os(macOS)
        /// Bound to GameUITest's configPath in Tests/UITests/UITestSupport.swift.
        static let configPath = "/tmp/mu-uitest-config.txt"
        /// Unconditional diagnostic sink (launch facts, trace-write failures).
        static let notePath = "/tmp/mu-uitest-note.log"
        /// Written by the runner before launch; if the app cannot see it,
        /// runner-written /tmp files are out of reach for this process.
        static let probePath = "/tmp/mu-uitest-probe.txt"
        /// Defaults keys shared with the runner (GameUITest.defaultsSuite).
        static let defaultsSuiteKey = "mu-flags"
        static let defaultsNoteKey = "mu-note"
    #endif

    /// Resolved once, on first use. All readers run on the main thread
    /// (SwiftUI launch paths), so no locking is needed.
    nonisolated(unsafe) private static var cached: [String]?

    static func arguments() -> [String] {
        if let cached { return cached }
        let resolved = resolve()
        cached = resolved
        return resolved
    }

    private static func resolve() -> [String] {
        #if os(macOS)
            note("launch: argv=\(ProcessInfo.processInfo.arguments.joined(separator: " "))")
            note(
                "launch: probe=\(FileManager.default.fileExists(atPath: probePath) ? "readable" : "absent")"
            )
            if let text = try? String(contentsOfFile: configPath, encoding: .utf8) {
                let flags = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                if !flags.isEmpty {
                    note("launch: using file config (\(flags.count) flags)")
                    return flags
                }
            }
            note("launch: no usable file config")
            if let flags = UserDefaults.standard.stringArray(forKey: defaultsSuiteKey),
                !flags.isEmpty
            {
                note("launch: using defaults channel (\(flags.count) flags)")
                return flags
            }
            note("launch: no defaults flags; using process arguments")
            // Environment-variable channel: always available on CI (unlike
            // /tmp which can be inaccessible and unlike defaults which
            // requires a valid app-group suite name).
            if let env = ProcessInfo.processInfo.environment["MU_UITEST_FLAGS"],
                !env.isEmpty
            {
                let flags = env.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                if !flags.isEmpty {
                    note("launch: using env channel (\(flags.count) flags)")
                    return flags
                }
            }
        #endif
        return ProcessInfo.processInfo.arguments
    }

    /// Appends a diagnostic line to notePath unconditionally on macOS and
    /// mirrors it into the app's defaults domain. The defaults mirror is
    /// readable by the runner through GameUITest.dumpTrace() even when the
    /// /tmp file write fails, so it records the launch facts either way.
    static func note(_ line: String) {
        #if os(macOS)
            let stamped = "[\(Int(Date().timeIntervalSince1970))] \(line)\n"
            var fileWriteOK = false
            if !FileManager.default.fileExists(atPath: notePath) {
                fileWriteOK = FileManager.default.createFile(
                    atPath: notePath, contents: Data(stamped.utf8)
                )
            } else if let fh = FileHandle(forWritingAtPath: notePath) {
                defer { try? fh.close() }
                fh.seekToEndOfFile()
                fh.write(Data(stamped.utf8))
                fileWriteOK = true
            }
            var mirrored = UserDefaults.standard.stringArray(forKey: defaultsNoteKey) ?? []
            mirrored.append(
                "[file \(fileWriteOK ? "ok" : "failed")] "
                    + stamped.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            UserDefaults.standard.set(Array(mirrored.suffix(40)), forKey: defaultsNoteKey)
        #endif
    }
}
