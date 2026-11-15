# Night Market — Handoff

Kept current at every gate. What a new engineer (or agent) needs to resume.

## P0 Setup — state at G0

- **Branch:** `night-market/phase/P0-setup`
- **Status:** all S0.1–S0.7, NM-P0.1, NM-P0.2 complete; every gate green except the final UI-test rerun (in flight at the time of writing); G0 tag pending
- **Architecture:** 7 SwiftPM packages (NMCore root; NMContent→NMCore; NMAI→NMCore+NMContent; NMRender/NMAudio/NMPlatform/NMMeta→NMCore). App targets (`NM` iOS, `NM-macOS`) depend on the package products via XcodeGen; package sources are NOT compiled into the app targets.
- **Determinism:** `SeededRNG` (Xoshiro256**/SplitMix64) is the only randomness source; `Fixed` is Q32.32 on `Int64` with stdlib-`Int128` mul/div; `FixedPoint2` is 1 tile = 1,024 units. Banned-API lint rules (`banned_random`, `banned_date_uuid`) plus `Tools/check-imports.sh` backstop.
- **Sim constants:** ticksPerHour 1800; night 18:00→06:00; hourly spawn rates [6,9,12,16,20,24,28,32,36,40,44,48]; serviceTicks 90; baseSpeed 48 units/tick; maxQueue 6; patience 600; rain +12 without awning within 1 tile.
- **Initial map:** 32×20; canals rows 7 & 12 cols 10..<22; plaza rows 8..<13 cols 12..<20; gates (0,9),(0,10); six stalls.
- **Debug overlay (S0.7):** FPS/TICK/SEED/HASH; three-finger double-tap (iPad), ⌘⇧D (Mac). `DebugState.shared` is the wiring point for P1+ sim updates.
- **Perf (NM-P0.2):** see `docs/PERF.md`. Frame-budget substitution for the 60 Hz Mac display; maintainer item filed in `STATUS.md`.
- **Gotchas learned here:**
  - SwiftPM testing on this toolchain: a single crashing test (SIGTRAP, e.g. arithmetic overflow) kills the whole `swift test` run and SwiftPM reports only "test targets reported failures" with no failing-test line — bisect with `--filter <funcName>` (function names, not display names).
  - Never pipe `xcodebuild`/`swift test` through `tee` and trust the exit code; check `${PIPESTATUS[0]}`.
  - Background shells do not inherit `DEVELOPER_DIR`; export the full `/Applications/Xcode.app/Contents/Developer` path (the short form breaks `simctl`).
  - swift-format (604) adds trailing commas to multiline literals; SwiftLint's `trailing_comma` therefore disabled here.
  - `.build` directories must be excluded per-package in `.swiftlint.yml`; a `Packages/.build` wildcard is insufficient.
- **CI:** `.github/workflows/night-market.yml` (lint/test/build-ios/build-macos), pinned SHAs required before merge per AGENTS.md — workflow currently uses `@v4`/`@v2` tags; pin before or at first push if red.
- **Next:** G0 tag → P1 Rules Engine Prototype (see ROADMAP.md §8).
