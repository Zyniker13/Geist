// Murmuration app — effective UI-test flags (single source of truth).
//
// macOS XCUI runners have dropped XCUIApplication.launchArguments in CI
// runs: the app sat on the menu, no trace file appeared, and every gate
// test timed out waiting for state that required -uitest-play. So on
// macOS the test harness also writes the flags to a file the app reads
// at startup. The file wins when present; otherwise the process
// arguments are used unchanged (local headless runs, iOS).

import Foundation

enum MULaunch {
    #if os(macOS)
        /// Bound to GameUITest's configPath in Tests/UITests/UITestSupport.swift.
        static let configPath = "/tmp/mu-uitest-config.txt"
        /// Unconditional diagnostic sink (launch facts, trace-write failures).
        static let notePath = "/tmp/mu-uitest-note.log"
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
            if let text = try? String(contentsOfFile: configPath, encoding: .utf8) {
                let flags = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                if !flags.isEmpty {
                    note("launch: using file config (\(flags.count) flags)")
                    return flags
                }
            }
            note("launch: no usable file config; using process arguments")
        #endif
        return ProcessInfo.processInfo.arguments
    }

    /// Appends a diagnostic line to notePath unconditionally on macOS:
    /// records the launch facts and trace-write failures that must be
    /// visible even when -uitest-trace never arrives. The runner reads
    /// this file through GameUITest.dumpTrace() on failure.
    static func note(_ line: String) {
        #if os(macOS)
            let stamped = "[\(Int(Date().timeIntervalSince1970))] \(line)\n"
            if !FileManager.default.fileExists(atPath: notePath) {
                FileManager.default.createFile(atPath: notePath, contents: Data(stamped.utf8))
                return
            }
            if let fh = FileHandle(forWritingAtPath: notePath) {
                defer { try? fh.close() }
                fh.seekToEndOfFile()
                fh.write(Data(stamped.utf8))
            }
        #endif
    }
}
