# Night Market — docs/STATUS.md

## P0 (Setup) — COMPLETE, tagged `night-market/gate-G0-pass` (local; push blocked)

- All S0.1–S0.7 + NM-P0.1 + NM-P0.2 green; evidence below. P0 committed on `main` (4 commits + merge).

### Gates

All commands run with `set -o pipefail` semantics (`${PIPESTATUS[0]}` checked after pipes).

- **swift test (NMCore):** 33 tests / 8 suites passed — exit 0
- **swift test (NMContent):** 1 test passed — exit 0
- **swift test (NMAI):** 2 tests passed — exit 0
- **swiftlint --strict:** `0 violations, 0 serious in 45 files` — exit 0
- **swift-format lint:** clean, exit 0
- **xcodebuild build NM (iPad Pro 13-inch (M5) simulator):** `** BUILD SUCCEEDED **`
- **xcodebuild build NM-macOS (macOS):** `** BUILD SUCCEEDED **`
- **xcodebuild test -scheme NM (UI smoke, iPad sim):** `** TEST SUCCEEDED **` — `Executed 1 test, with 0 failures`
- **Tools/check-imports.sh:** clean — exit 0

## P1 (Rules Engine Prototype) — COMPLETE, tagged `night-market/gate-G1-pass`

### S1.1 — Rules tests (R-1…R-17)
- [x] `RulesTests.swift` + `RulesLateTests.swift` (split for lint body limit): one or more tests per rule ID R-1…R-17
- [x] Invariant property tests (INV-2, INV-3) in suite
- [x] 71 tests / 11 suites in NMCore, all passing

### S1.2 — Simulation core
- [x] R-3 start state (2 stalls open, gate 0 active, budget 30, 2 lanterns), R-6 gate/schedule ticks, R-7 spawner with seeded jitter and hourly ramp
- [x] Flow fields: per-stall-color + gate Dijkstra over (tile, direction) states; edge costs base 10 / dark +6 / rain-no-awning +12 / busker −3 / corner +2 / floor 4; version-keyed cache invalidated on edits
- [x] Movement: flow-field descent, density slowdown (48/40/33/…/floor 12, integer math), integer-only `moveToward` (Newton integerSqrt)
- [x] Service (90-tick service, queue capacity 6 + attributed waiting), overflow, scoring (serve +1, dawn bonus 25%)
- [x] Fixtures R-15 (lantern r3, busker r2, awning 3×3, bridge 1–3 water tiles straight-line with land landing) and rain R-17 (0–3/night, 90–180 s, never before 19:00)
- [x] Edits never strand customers (ADR-0006): erase/bridge-move relocation + seat-seeker retarget (caught by the sweep, fixed TDD)

### S1.3 — Tools/sim (headless)
- [x] `Tools/sim` SwiftPM executable: `--seed/--nights/--invariants/--invariant-sweep N/--golden N --golden-out DIR`
- [x] Deterministic random-legal-move policy; connectivity-guarded erases; INV-1…INV-5 checks per tick
- [x] Perf: **1.07–1.12 s user CPU per full night (target ≤ 1.5 s)** after allocation-free `Tile.forEachNeighbor` hot paths (profiled with `sample`; the old `neighbors` array churn was the hotspot)
- [x] Makefile `sim` target (no tee-masking, no `|| true`), `coverage` target writing docs/COVERAGE.md

### S1.4 — Golden replays
- [x] 10 committed golden replays (`Packages/NMCore/Tests/NMCoreTests/GoldenReplays/`, Bundle.module `.copy` resource)
- [x] `GoldenReplayTests`: each replay run twice (identical), final hash + 12 checkpoint hashes match the committed expectations, 0 skipped actions
- [x] Canonical ordering fixed and documented (ADR-0007): upgrades sort first among same-tick actions; checkpoints hashed before the boundary choice; recordings contain applied actions only

### Determinism evidence
- [x] Same binary, two runs: identical hashes (within one process; golden tests re-run each replay twice)
- [x] **Debug ≡ Release:** both build configurations produce hash `acb48762f60f2db6` for seed 42 (after ADR-0008: sorted walkway hashing, no Set order in RNG paths)
- [x] 500-night sweep (final binary): `INVARIANT_SWEEP OK nights=500 servedTotal=148783 survived=500`, 0 violations — 1068.64 s user for 500 nights (2.14 s/night incl. per-tick invariant checks; the gate metric is the single plain night below)

### Gates (G1 evidence)

- **swift test (NMCore):** `Test run with 71 tests in 11 suites passed` — exit 0
- **NMCore line coverage:** **94.95%** (`llvm-cov report` TOTAL Lines 2753/139 missed) — ≥ 90% gate met
- **swiftlint --strict:** `Found 0 violations, 0 serious in 52 files` — exit 0
- **swift-format lint:** exit 0 (clean)
- **Headless night:** 1.07–1.12 s user CPU (Mac, Release) — ≤ 1.5 s gate met
- **Checkpoint hashes:** identical across two runs and Debug/Release builds — see Determinism above

### G1: PASS — tagged `night-market/gate-G1-pass`

## P2 (Core Loop Vertical Slice) — COMPLETE pending tag

- **Started:** 2026-11-15
- **Last done:** S2.1–S2.5 built; G2 checks green on iPad (XCUITest) and Mac (scripted runs); docs written
- **Next:** tag `night-market/gate-G2-pass`, then P3

### S2.1 — Scene + primary interaction (NM-P2.1/P2.2/P2.3/P2.6)
- [x] `MarketScene` (NMRender): Taipei map (ground checker, canals rows 7/12, plaza block, two west gates with arch art), six stall nodes with color/shape glyphs, lantern glow (additive), customers as colored dots; `rebuild(with:)` for restart/restore
- [x] Walkway painting by drag, tile-snapped, 16-mask autotile atlas (`TileArt`); two-finger drag erases; budget counter (`budget-hud`)
- [x] Tray: Lantern / Awning / Busker / Seats arms `placementTool`; tap places; long-press stall → queue/service stats sheet (`selectStall(nearScenePoint:)`)
- [x] Mac input (NM-P2.6): `MacMarketView` left-drag paints, right-drag erases, space pauses, 1/2/3 speeds; iOS uses `MapInputCatcher` (transparent touch view; SKView presentation-only)

### S2.2 — HUD/picker/results (NM-P2.4/P2.5)
- [x] HUD: clock, score, walkway budget, customer count, speed chips, pause/save buttons; `publishHud` throttled to ~10 Hz (every-frame publish starved SpriteKit under load)
- [x] Hour-boundary upgrade picker (`offer-button`/`upgrade-picker`); results screen with served count, survival verdict, final score, heatmap layer, next-night button

### S2.3 — Challenge source
- [x] `NightScenario` (NMContent): `.taipeiSlice` pins one rain shower (startTick 3600, 1350 ticks) via `GameStateOverrides.rainSchedule`; `.clear`; 3 tests green. Scenarios pin weather/timing only — spawn pressure stays R-7 (rules-engine contract)

### S2.4 — Save/resume
- [x] `SaveData{state, rng, nightNumber, servesTotal, hash}` → Application Support/NightMarket/save.json (atomic); save()/resume()/deleteSave(); HUD save button; resume pauses the restored night
- [x] Hash contract: the saved state's `StateHash.hex` equals the restored state's hash — verified in-process (see G2) and by NMCore `SaveResumeTests` round-trip

### S2.5 — Recording
- [x] `docs/media/slice.mp4` — 72 s simulator recording (1x speed, stress crowd + autolane + autochoose), H.264, 12.3 MB

### G2 evidence (iPad, real XCUITest)

```
xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -configuration Debug -only-testing:NMUITests
EXIT=0  (** TEST SUCCEEDED **)
  testFullNightToResults            passed (18.9 s)  # full night -> results screen, next-night button
  testSaveResumeRestoresIdenticalHash passed (7.6 s) # save c1ebecbb… == restored hash, frozen while paused
  testStressCrowdHoldsFrameRate     passed (11.9 s)  # 400-customer load, avg >= 50 fps (display cap 60)
```
- Full-suite `make test`: NMCore (71 tests) + NMContent + NMAI + NMUITests all passed; lint 0 violations.

### G2 evidence (Mac, scripted runs — see docs/SLICE_ASSESSMENT.md for why)

- Full night to results: `open -a NM-macOS.app --args -uitest-fast -uitest-fresh -uitest-autochoose -uitest-debug -uitest-shot /tmp/mac-results.png` → results screen "Night survived! / Served 0 customers / Final score 0" with Next night button, TICK 21,600 (screenshot `/tmp/mac-results.png`)
- Save/resume: `-uitest-save-restart -uitest-autolane` run → paused at TICK 900, **SAVE `11de3037ecde737d` == HASH `11de3037ecde737d`**, Walkway 12/30 (screenshot `/tmp/mac-save.png`)
- Mac XCUITest blocked by the automation-mode TCC timeout — maintainer issue #6; the test (`Tests/UITests/NMUITestsMac.swift`) is written and compiles

### Harness notes (documented substitutions)

- XCUITest launches start with an empty data view: cross-launch save restore is untestable in-harness; G2 exercises save→resume in-process; the real relaunch path verified manually via `simctl launch` (tick 8,100 + hash restored exactly)
- Headless iPad sim cannot rotate while XCUITest stays portrait: checks are launch-arg-driven; map input goes through `MapInputCatcher`
- `-uitest-*` affordances live in `GameController`/`GameScreen` (fast, fresh, paused, stress, autochoose, autosave, save-restart, autolane, debug, shot) — never set by gameplay


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

