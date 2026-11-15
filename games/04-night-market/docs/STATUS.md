# Night Market — docs/STATUS.md

## P0 (Setup)

- **Started:** 2026-11-15
- **Current phase:** P0
- **Last done:** all S0.1–S0.7 + NM-P0.1 + NM-P0.2; every gate re-verified green (see Gates)
- **Next:** G0 tag, then P1 (Rules Engine Prototype)
- **Blocked on:** nothing

### S0.1 — Repo layout
- [x] Directory tree created (Config, App, Packages, Resources, Tools, Tests, docs)
- [x] Bundle.xcconfig with `GEIST_BUNDLE_ID = com.example.night-market`
- [x] project.yml with 7 packages as SwiftPM product dependencies, 2 app targets, deployment targets 26.0
- [x] Makefile with gen/build/test/lint targets
- [x] 7× package.swift (platforms macOS 26 / iOS 26)

### S0.2 — SeededRNG + Fixed
- [x] SeededRNG (Xoshiro256** + SplitMix64)
- [x] Fixed (Q32.32) — arithmetic on stdlib Int128; round-half-away-from-zero; decimal description
- [x] FixedPoint2 — with tests (NM-P0.1)
- [x] Tile, Grid, WalkwayTile
- [x] Stall, StallColor, Shape, CustomerID
- [x] Gate, Weather, Clock
- [x] Customer, CustomerState
- [x] Fixture, FixtureKind
- [x] GameState + initial(seed:)
- [x] Action, Event, TimedAction, ReplayData/Replay
- [x] Reducer (paint, erase, place, move, upgrade, speed, pause, resume)
- [x] Tick (pause honored; clock advances by speedMultiplier; weather, spawn, move, service, overflow, score)
- [x] Spawner
- [x] FlowField (Dijkstra; unwalkable tiles skipped — fixes overflow crash)
- [x] Movement
- [x] Service, Overflow
- [x] Scoring

### S0.3 — Tools + lint
- [x] .swiftlint.yml (custom rules: banned_random, banned_date_uuid; 0 violations in 44 files)
- [x] .swift-format (formatter canonical; `swift-format format --in-place` applied to Packages/ App/)
- [x] Tools/check-imports.sh (banned-API backstop; runs clean)
- [x] Tools/content-lint (P0 skeleton; runs clean)
- [x] Test files in all 7 packages

### S0.4 — CI
- [x] .github/workflows/night-market.yml (lint, test, build-ios, build-macos; exit codes not tee-masked)

### S0.5 — Docs
- [x] README.md
- [x] docs/THIRD_PARTY.md
- [x] docs/OPEN_QUESTIONS.md
- [x] docs/DECISIONS.md (ADR-0001 Xoshiro256**, ADR-0002 Q32.32, ADR-0003 immutable GameState)
- [x] docs/HANDOFF.md
- [x] docs/RULES.md (roadmap §4 copied verbatim with R-1…R-17 and INV-1…INV-5)
- [x] docs/PERF.md (NM-P0.2 spike results)

### S0.6 — Replay
- [x] ReplayData (seed, contentVersion, actions) + Replay runner
- [x] "replay runs deterministically" test passes (part of 33-test NMCore suite)

### S0.7 — Debug overlay
- [x] DebugOverlay view: FPS / TICK / SEED / HASH
- [x] Toggle: three-finger double tap on iPad (window-level recognizer), ⌘⇧D on Mac (hidden keyboard shortcut)
- [x] Live FPS on iOS via CADisplayLink

### Game-specific
- [x] NM-P0.1 Fixed-point 2D vector type with tests (FixedPoint2Tests: 8 tests)
- [x] NM-P0.2 600-sprite SpriteKit spike → docs/PERF.md; frame-budget substitution recorded for the 60 Hz Mac display (maintainer item filed)

### Gates

All commands run with `set -o pipefail` semantics (`${PIPESTATUS[0]}` checked after pipes).

- **swift test (NMCore):** `Test run with 33 tests in 8 suites passed after 0.005 seconds` — exit 0
- **swift test (NMContent):** `Test run with 1 test in 1 suite passed` — exit 0
- **swift test (NMAI):** `Test run with 2 tests in 1 suite passed` — exit 0
- **swiftlint --strict:** `Found 0 violations, 0 serious in 45 files` — exit 0
- **swift-format lint:** clean, exit 0
- **xcodebuild build NM (iPad Pro 13-inch (M5) simulator):** `** BUILD SUCCEEDED **`
- **xcodebuild build NM-macOS (macOS):** `** BUILD SUCCEEDED **`
- **xcodebuild test -scheme NM (UI smoke, iPad sim):** `** TEST SUCCEEDED **` — `Executed 1 test, with 0 failures`
- **Tools/check-imports.sh:** `check-imports: clean` — exit 0

### G0: pending tag
