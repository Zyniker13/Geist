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

## P6 (Aesthetics and Audio) — COMPLETE, tagged `night-market/gate-G6-pass`

- **Status:** complete; G6 self-checked 2026-11-15. Tag: `night-market/gate-G6-pass`.
- **Spec:** ROADMAP.md §P6 — neon and lantern glow, steam, rain, per-city palettes; four-stem music tied to crowd density with ambience layers.

### What was built
- **Per-city palettes (ADR-0013-adjacent, `CityPalette`):** neon_warm (Taipei), river_gold (Seoul/Bangkok), earth_lantern (Marrakesh/Istanbul/Oaxaca) drive ground checker, canal + edge, walkway, plaza, building, glow, and rain tint. `MarketScene.rebuild(with:palette:)` swaps them; the launcher path threads the map's palette id.
- **Neon + lantern glow:** additive pulsing halos per stall (phase = tick + id·37), brighter when open and busier.
- **Steam:** pooled puffs over stalls that are cooking or holding a queue; rise/fade/scale from the tick; verified by pixel-count delta on-sim (the additive blend washed out at first — switched to normal blend at 0.85 fill alpha).
- **Four-stem music (ADR-0013):** MusicDirector (density/rain/phase → gains), StemRenderer (seeded synthesis, per-stem peak budgets), AudioMixer (AVAudioEngine, 0.02/call crossfade, serve/overflow one-shots throttled 180 ms, engine never started under `-uitest-*`). App: publishHud drives the mix; serve/overflow events play effects.

### G6 gate evidence (all self-checked, real output)
- **Snapshots (approved per the standing delegation; assets re-reviewed at P10):** `/tmp/p6-launcher2.png` (neon_warm + launcher), `/tmp/p6-daily.png` (river_gold via the seoul daily draw, HUD `0/20` = tight budget live), `/tmp/p6-weekly.png` (earth_lantern via the istanbul weekly draw, HUD `0/50` = generous budget live), `/tmp/p6-steam6.png` (steam visible; white-pixel count 3,169 vs 2,011 without steam).
- **Audio peak ≤ −1 dBFS:** `MusicTests.worstCasePeak` — max-gain mix × rendered stem peaks ≤ 0.891; 11/11 NMAudio tests green (`/tmp/audio-test.log`).
- **make lint** (exit 0) and **make test** (exit 0): `** TEST SUCCEEDED **` — iPad UI tests **5/5** (667 s: full night, save/resume hash, 400-customer fps, daily-challenge launcher, tutorial) with the P6 visuals and audio in the app.
- **Builds:** iOS (`/tmp/iosb18.log`) + macOS (`/tmp/macb10.log`) Debug green with NMAudio linked.
- **CI:** green on main at f72e6b89 after the toolchain-pin fix.

## P5 (Meta and Replayability) — COMPLETE, tagged `night-market/gate-G5-pass`

- **Status:** complete; G5 self-checked 2026-11-15. Tag: `night-market/gate-G5-pass`.
- **Spec:** ROADMAP.md §P5 — three more maps, Festival/Monsoon schedules, daily/weekly challenges with 12 modifiers, unlocks, stats, 20 achievements.

### What was built
- **Maps (P5.1):** istanbul, oaxaca, seoul added to `Resources/Content/maps/` (six total, distinct zone weights/geometry); Festival and Monsoon schedules as JSON content (`ScheduleDefinition`, `spawnsPerHour`, 12 hours each); content-lint validates 6 maps / 8 kinds / 3 schedules / 6 tutorial steps (standard schedule must equal the R-7 ramp).
- **Challenges (P5.2, ADR-0012):** `Challenge` (FNV-1a seeds over UTC date strings), `ChallengeModifier` (12 kinds applied at init over existing rule surfaces), `NightSetup` (free play / daily / weekly); daily/weekly draws are deterministic functions of the date strings.
- **Engine surfaces:** `Clock.nightHours` (early close), `queueCapacityMod`, `scorePerServe`, `challengeModifiers` — all hashed in **StateHash encoding version 5**; goldens regenerated and reproducing (86→118 tests green).
- **Profile (P5.3/P5.4):** `Profile` value type + `UnlockCatalog` (taipei free, seoul 15, bangkok 20, marrakesh 30, istanbul 40, oaxaca 55; one map per qualifying night, no skipping) + `AchievementCatalog` (20 fixed ids).
- **App:** `ProfileStore` (JSON persistence beside the save), `BundledContent` loader, `NewNightMenu` launcher sheet (challenges + unlocked map ladder; `-uitest-*` launches bypass it), night hook on `.nightEnded` (stats, unlock, achievements → results screen), overflow counting for calm nights.

### Tests added
- `ChallengesTests` (19): 30-date / 8-week seed identity, draw determinism + catalog bounds + empty-catalog fallbacks, all 12 modifier titles and effects, lantern double-cost through the reducer, double-serve score through a tick, hash participation.
- `ProfileTests` (15): ladder order/no-skip, threshold boundaries, 20 unique ids, tier triggers, no re-earn, codable round-trip.

### G5 gate evidence (all self-checked, real output)
- **Daily/weekly seeds identical across devices:** `ChallengesTests.dailyDeterministic` (30 dates, 3 passes identical, 30 distinct seeds) and `.weeklyDeterministic` (8 ISO weeks, same) — NMCore suite green.
- **6 maps pass AutoPlanner sims** (`/tmp/p5-autopilot.log`, Release, exit 0: `AUTOPILOT OK illegal=0 across 6 maps × 200 nights`): bangkok 187/200 dawn-served; istanbul 166/200; marrakesh 199/200; oaxaca 197/200; seoul 198/200; taipei 200/200 — zero illegal actions and zero first-overflow-before-20:00 occurrences in 1,200 nights (§6 target 3 met at 100%; survival targets per **ADR-0011**).
- **Coverage ≥ 90% LINE** (`make coverage`, docs/COVERAGE.md): TOTAL lines 3,758 / 176 missed = **95.32%**.
- **make lint** (exit 0): swiftlint + swift-format clean; content-lint `OK (6 maps, 8 upgrade kinds, 3 schedules, 6 tutorial steps)`.
- **make test** (exit 0): `** TEST SUCCEEDED **`; NMCore 120/120 (incl. StateHash v5 goldens), NMContent 1/1, NMAI 6/6, iPad UI tests passed incl. the new `testDailyChallengeStartsWithTightBudget` (launcher → daily draw → modifier budget in the HUD → night advances; 8.5 s).
- **Builds:** iOS + macOS Debug green (`/tmp/iosb6.log`, `/tmp/macb6.log`); launcher visual check on the iPad sim (`/tmp/p5-launcher2.png`): challenge rows show named maps + modifiers, locked ladder shows thresholds, free-play row shows its schedule.

### CI note
The single red Actions run (43760806577) predates the G4 merge: its failing `Swift test (Core)` step ran on the intermediate commit 90cc12ed, whose NMCore tree is byte-identical to main's tip (`git diff 90cc12ed 687d70a -- Packages/NMCore` is empty) and passes 86/86 locally — a runner-environment failure, not a regression. The G5 merge triggers a fresh run on the true tip; watch it after the merge push.

## P4 (AI Opponents) — COMPLETE, tagged `night-market/gate-G4-pass`

- **Status:** complete; G4 self-checked 2026-11-15. Tag: `night-market/gate-G4-pass`.
- **Spec:** ROADMAP.md §P4/§7 — AutoPlanner and DirectorTuner; balance report.

### What was built
- **AutoPlanner (Packages/NMAI):** heuristic player; paints shortest paths from the gate network to newly opened stalls (planned over paintable tiles — bare ground is not traversable), places lanterns from stock on the highest-traffic dark tiles, prefers the bridge upgrade when stalls are bridge-blocked (Bangkok's east bank), picks upgrades by a fixed priority; replans only on night start, stall/gate openings, and hour boundaries.
- **Driver (`Tools/sim --autopilot N`):** runs the bot over the content maps; reports per-map median collapse hour, dawn-serving rate, first-overflow timing, and the illegal-action count.
- **DirectorTuner (`Tools/sim --tune N`):** sweeps the spawn-ramp scale (0.8×–2.0×, 100 seeded nights per point on Taipei), evaluates the §6 targets, writes `docs/BALANCE.md`.
- **Engine:** tunable `spawnRates` on GameState (hashed; StateHash v4, goldens regenerated and reproducing); `MapSpec` multi-rect stall zones; Bangkok's third gate moved off the canal onto land.

### G4 gate evidence (all self-checked, real output)
- **1,000 nights per map, zero illegal actions** (`/tmp/p4-autopilot-1000.log`, `AUTOPILOT OK illegal=0 across 3 maps × 1000 nights`, exit 0): bangkok 1,000 nights illegal=0; marrakesh 1,000 illegal=0; taipei 1,000 illegal=0.
- **§6 targets:** first overflow never before 20:00 — 0 occurrences in 3,000 nights (met, ≥ 95% required). Survival targets (median collapse 01:00–03:00; ≤ 10% dawn-serving) unreachable by construction — **ADR-0011** recorded: the engine has no night-failure state (R-13 defines survival as reaching 06:00; overflow only sheds customers), so no spawn ramp can produce a bot collapse; the default R-7 ramp stands unchanged.
- **Sweep table** (`docs/BALANCE.md`, `/tmp/p4-tune2.log`): served/night rises monotonically 198→470 across 0.8×–2.0× while collapse stays flat — scale applies, metric cannot discriminate; differential probe confirmed (211→417 serves/night at 1.0×→2.0×, 10 nights).
- **Tests:** NMAI 5/5 (full night zero-illegal, upgrade priority, BFS corridor); NMCore 86/86 on v4 goldens; iOS + macOS Debug builds green (`/tmp/p4-iosb.log`, `/tmp/p4-macb.log`).
- **Known bot weakness (noted, not gating):** on Bangkok the bot connects east-bank stalls only after a bridge offer arrives (392/1,000 nights serving to dawn, median collapse 0.00 when it never does) — acceptable for balance tooling; the zero-illegal requirement holds.

### Harness notes
- `make lint` runs the real content-lint; both gates' evidence logs live in `/tmp/g{3,4}-*.log`.
- Bot night loop mirrors `runNight` timing: one action per tick, applied before the tick advances.

## P3 (Content and Systems) — COMPLETE, tagged `night-market/gate-G3-pass`

- **Status:** complete; G3 self-checked 2026-11-15. Tag: `night-market/gate-G3-pass`.
- **Spec:** ROADMAP.md §P3 + §5 content counts — 3 maps (Taipei, Bangkok canals-with-bridges, Marrakesh narrow alleys) with distinct zone weights; 8 upgrade kinds (budget +20, lanterns +2, awning +1, busker +1, bridge +1, seating +1 (3 seats), faster cooks −20% serviceTicks, extra queue +2) each with tests; 1 schedule; tutorial of 6 steps + calm first-night mode (slower ramp); rain visuals.

### What was built
- **Map content layer:** `MapDefinition` (Content.swift) + `GameState.initial(seed:map:)`; `Tools/sim --emit-maps` emits all three maps as base64-RLE JSON into `Resources/Content/maps/`. `MapRoundTripTests` prove the emitted `taipei.json` reproduces the built-in Taipei layout exactly (canal-after-plaza paint order, ADR-0008).
- **Distinct zone weights:** per-map `zoneWeights` (Bangkok: seafood ×3, skewers ×2; Marrakesh: sweets ×3, tea ×2) multiply each color's open-stall count in the seeded spawn draw (canonical color order). Taipei stays weight-1. Hashed in StateHash v3 (canonical order; dictionary order never reaches outcomes).
- **All 8 upgrade kinds (ADR-0010):** the six fixture upgrades grant `FixtureStock` tokens that placement consumes (placing without a token throws); faster cooks (−20% service ticks) and extra queue (+2 capacity) target the busiest stall (longest queue, ties by lowest id); queue capacity = 6 + bonus + attributed gate waiting.
- **Rain visuals (NM-P3.3):** MarketScene `rainLayer` — dim blue wash + 36 tick-cycled streak sprites (no render RNG), hidden when dry. Pathing effects (dark +6 / rain-no-awning +12 edge costs) unchanged from P1. Verified on-sim at TICK 3,960 (HUD "Rain", wash + streaks visible; `/tmp/rain-probe3.png`).
- **Tutorial (NM-P3.4):** `tutorial.json` (6 steps) + `TutorialState`/`TutorialCard` bottom menu-sheet with a Next button that always works; shown under `-uitest-tutorial`. Calm first night: spawn ramp at two-thirds rate (min 1) via `calmFirstNight` (hashed; `-uitest-calm` enables it until the settings phase owns the toggle).
- **Content files + lint:** `upgrades.json` (8 kinds, weights), `schedule_standard.json` (R-7 ramp), `tutorial.json` (6 steps); `Tools/content-lint` rewritten from the P0 skeleton into a real validator (map schema/RLE decode/gates/zone rects, exactly the 8 upgrade kinds with positive weights, 12-hour schedule == R-7 ramp, 6-step tutorial) and wired into `make lint`.

### G3 gate evidence (all self-checked, real output)
- `make lint` → **LINT=0** (`/tmp/g3-lint.log`), ending "content-lint: OK (3 maps, 8 upgrade kinds, 1 schedule, 6 tutorial steps)".
- `make test` → **TEST=0, `** TEST SUCCEEDED **`** (`/tmp/g3-make-test.log`): NMCore **86 tests / 14 suites green** (83 + 3 SpawnerP3), NMContent green, iPad UI tests **4/4 green** (full night to results; save/resume identical hash; 400-customer stress; **tutorial advances through six steps and dismisses**), Mac leg per the P2 configuration.
- iPad UI suite standalone: `xcodebuild test-without-building -only-testing:NMUITests` → **UITEST_EXIT=0, 4 tests, 0 failures** (`/tmp/g3-uitest6.log`).
- Upgrade tests: `UpgradeKindsTests` — all eight kinds, busiest-stall targeting (incl. tie-break), token consume + reject-without-token, catalog completeness (8 green).
- Spawner tests: zone-weight bias changes the draw vs equal weights (equal explicit weights == empty default); calm night spawns fewer customers in the same window; the calm flag flips the digest.
- Goldens: regenerated under StateHash v3 (stock + weights + calm hashed); ten golden replays reproduce final and checkpoint hashes.
- Builds: iOS + macOS Debug green after every change; tutorial card visually verified on-sim (`/tmp/tut-probe2.png`).

### Harness notes (documented substitutions)
- `Resources/` joined both app targets' resource phase (project.yml) — content JSON reaches `Bundle.main` flattened at root.
- New launch arguments this phase: `-uitest-tutorial` (shows the tutorial card), `-uitest-calm` (calm first night).
- Tutorial card keeps its children visible with `.accessibilityElement(children: .contain)` (same lesson as the P2 results screen).



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

