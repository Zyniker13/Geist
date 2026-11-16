# Night Market — Handoff

Kept current at every gate. What a new engineer (or agent) needs to resume.

## P0 Setup — state at G0

- **Branch:** `night-market/phase/P0-setup`
- **Status:** all S0.1–S0.7, NM-P0.1, NM-P0.2 complete; every gate green except the final UI-test rerun (in flight at the time of writing); G0 tag pending
- **Architecture:** 7 SwiftPM packages (NMCore root; NMContent→NMCore; NMAI→NMCore+NMContent; NMRender/NMAudio/NMPlatform/NMMeta→NMCore). App targets (`NM` iOS, `NM-macOS`) depend on the package products via XcodeGen; package sources are NOT compiled into the app targets.
- **Determinism:** `SeededRNG` (Xoshiro256**/SplitMix64) is the only randomness source; `Fixed` is Q32.32 on `Int64` with stdlib-`Int128` mul/div; `FixedPoint2` is 1 tile = 1,024 units. Banned-API lint rules (`banned_random`, `banned_date_uuid`) plus `Tools/check-imports.sh` backstop.
- **Sim constants:** ticksPerHour 1800; night 18:00→06:00; hourly spawn rates [6,9,12,16,20,24,28,32,36,40,44,48]; serviceTicks 90; baseSpeed 48 units/tick; maxQueue 6; patience 600; rain +12 without awning within 1 tile.
- **Initial map:** 32×20; canals rows 7 & 12 cols 14..<17 (painted AFTER the plaza so they cut through it — ADR-0008); plaza rows 8..<13 cols 12..<20; gates (0,9),(0,10); six stalls.
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

## P1 Rules Engine — state at G1

- **Status:** COMPLETE; G1 green; tagged `night-market/gate-G1-pass` (9637a24).
- **Rules engine:** `GameState` immutable value with `rainSchedule`, `pendingOffers`, `fieldVersion`/`pathFields` cache. Flow fields are per-stall-color + gate Dijkstras over (tile, direction-of-arrival) states; edge costs base 10, dark +6 (no lantern within radius 3), rain-without-awning +12, busker −3, corner turn +2, floor 4. Movement descends the fields; density speeds 48/40/33/…/floor 12 (integer only); `moveToward` is Newton integer-sqrt.
- **Edits never strand customers** (ADR-0006): `Reducer.relocateStranded(off:in:)` relocates after erase/bridge-move and retargets seat-seekers; the 500-night sweep enforced INV-1…INV-5.
- **Headless sim:** `Tools/sim` (`--seed/--nights/--invariants/--invariant-sweep N/--golden N --golden-out DIR`). Full night ≈ 1.1 s CPU. Hot-path rule: use `Tile.forEachNeighbor` (allocation-free); never let `Set` iteration order reach the RNG.
- **Golden replays:** `Packages/NMCore/Tests/NMCoreTests/GoldenReplays/` (10 nights, Bundle.module resource). Canonical replay semantics in ADR-0007: `chooseUpgrade` sorts first among same-tick actions; checkpoints hash after the advance and before the boundary choice; recordings contain applied actions only.
- **Debug/Release parity:** sorted walkway hashing in `StateHash.digest` (ADR-0008); seed 42 hash identical in both configurations.

## P2 Vertical Slice — state at G2

- **Status:** S2.1–S2.5 complete; G2 checks green (iPad XCUITest 3/3; Mac scripted runs); tagged `night-market/gate-G2-pass`.
- **Architecture of the slice:** `MarketScene` (NMRender) renders `GameState` snapshots into 6 layers (map/heat/walkway/fixture/stall/customer) with node pools; `GameController` (App/Shared) owns the 30 Hz tick loop, reducer calls, and HUD publishing (`publishHud` throttled ~10 Hz); `GameScreen` (SwiftUI) is HUD/tray/picker/results; `MapInputCatcher` (iOS) forwards map touches to the scene's programmatic drag API; `MacMarketView` (macOS) takes mouse/keyboard directly.
- **Save/resume:** `SaveData{state, rng, nightNumber, servesTotal, hash}` → Application Support/NightMarket/save.json; the state hash includes `isPaused`, so saves taken while paused restore to the identical hash; `restart` re-applies `NightScenario.taipeiSlice.overrides`.
- **UI-test affordances (`-uitest-*`):** fast/fresh/paused/stress/autochoose/autosave/save-restart/autolane/debug/shot — see ADR-0009 and `docs/STATUS.md` harness notes. Accessibility ids: pause-button, save-button, offer-button, upgrade-picker, results-screen, next-night-button, budget-hud, debug-{fps,tick,hash,savehash}.
- **Known gaps:** Mac XCUITest blocked (issue #6); stall art is placeholder glyphs; upgrade offers are not context-aware; night number not surfaced in the HUD — all carried to P3 in `docs/SLICE_ASSESSMENT.md`.
- **Next:** P3 Content and Systems — Bangkok/Marrakesh maps, all 8 upgrade kinds, rain visuals, content JSON + content-lint (see ROADMAP.md §P3).

## P3 Content and Systems — state at G3

- **Status:** COMPLETE; tagged `night-market/gate-G3-pass`. Evidence in `docs/STATUS.md`.
- **Content layer:** `MapDefinition` (base64-RLE tiles, gates, zones, lanternSpots, palette, `zoneWeights`) + `GameState.initial(seed:map:contentVersion:spawnRates:overrides:)`; `--emit-maps` regenerates the six JSONs. Content lives in `Resources/Content/` and reaches the app via a resources build phase on BOTH app targets (files land flattened at bundle root; use `BundledContent`).
- **Token economy (ADR-0010):** upgrades grant `FixtureStock` tokens; placement consumes them; bridges need a token; faster-cooks/extra-queue hit the busiest stall (longest queue, ties by lowest id). `queueCapacity = 6 + bonus + attributedWaiting`.
- **Rain visuals:** `MarketScene` rainLayer (36 pooled streaks, tick-cycled, no RNG in render). Tutorial: 6-step `tutorial.json` wrapped in `{"steps":[...]}` (`TutorialFile`), calm first night via `-uitest-calm`.

## P4 AI Opponents — state at G4

- **Status:** COMPLETE; tagged `night-market/gate-G4-pass`. Evidence in `docs/STATUS.md`; balance report in `docs/BALANCE.md`.
- **AutoPlanner (NMAI):** event-driven replans (night start / openings / hour boundaries); paints shortest paths from the gate network over PAINTABLE tiles (bare ground is not traversable) — the path ALWAYS includes its start tile; tries each neighbor as the path start (a stall's south neighbor may be a building). Sims/tuning only — never shipped input.
- **DirectorTuner:** `--tune N` writes `docs/BALANCE.md`; `--autopilot N` reports per-map collapse/serves/illegal counts. §6 survival targets are unreachable by construction (ADR-0011); the default R-7 ramp stands.

## P5 Meta and Replayability — state at G5 (in progress)

- **Status:** code-complete; G5 evidence being collected (see `docs/STATUS.md`).
- **Challenges (ADR-0012):** `Challenge.dailySeed(yyyymmddUTC:)` / `weeklySeed(isoWeekUTC:)` are FNV-1a over `"NM-daily-" + yyyyMMdd` / `"NM-weekly-" + isoWeek` — the app formats the date (`BundledContent.ChallengeClock`), the core only sees strings. `Challenge.draw(seed:mapIds:scheduleIds:)` picks map + schedule + exactly one of 12 `ChallengeModifier`s; modifiers apply at init over existing rule surfaces and hash into StateHash (**encoding version 5** — bump + regenerate goldens whenever the hashed field set changes).
- **Profile:** `Profile` (Codable value), `UnlockCatalog` (taipei free → seoul 15 → bangkok 20 → marrakesh 30 → istanbul 40 → oaxaca 55; one map per qualifying night, no skipping), `AchievementCatalog` (20 fixed ids; earned ids never revoked). Persistence: `ProfileStore.shared` → Application Support/NightMarket/profile.json.
- **Launcher:** `NewNightMenu` shows daily/weekly (challenges bypass map locks by design) + free play over unlocked maps; `-uitest-*` launches bypass the launcher entirely; `-uitest-launcher-daily` forces it for the UI test. New accessibility ids: `new-night-menu`, `challenge-daily-challenge`, `challenge-weekly-challenge`, `map-<id>`, `clock-hud`.
- **Next:** collect G5 evidence (6-map autopilot, coverage ≥ 90%, make test/lint), close G5, then P6 aesthetics/audio.

## P6 Aesthetics and Audio — state at G6 (in progress)

- **Status:** code-complete; G6 close pending (see `docs/STATUS.md`).
- **Palettes:** `CityPalette` (neon_warm / river_gold / earth_lantern) — set at `MarketScene` init or via `rebuild(with:palette:)`; the launcher path threads `map.palette`. Unknown ids fall back to neon_warm. `Palette` statics remain the global HUD/stall colors; per-city ground/canal/walkway/glow/rain live on the struct.
- **FX:** neon halos (`fxLayer`, additive, phase = tick + id·37) and steam puffs (`steamLayer`, pooled 18, over stalls with a queue or service in progress). Both tick-driven, RNG-free. Steam learned the hard way: additive white on dark washes out — use normal blending with a 0.85 fill.
- **Audio (ADR-0013):** `MusicDirector.mix(density:isRaining:hourProgress:)` → `StemMix`; `AudioMixer` crossfades (0.02/call) and owns the AVAudioEngine (never started under `-uitest-*`). All sounds are seeded synthesis in `StemRenderer` with per-stem peak budgets; the worst-case mix is unit-tested ≤ 0.891 (−1 dBFS). Adding a stem = new case + budget + re-check the peak test.
- **Test affordances added:** `-uitest-start-daily` / `-uitest-start-weekly` (auto-start a challenge night), `-uitest-launcher-daily` (show the launcher). New ids: `new-night-menu`, `challenge-daily-challenge`, `challenge-weekly-challenge`, `map-<id>`, `clock-hud`.

## P7 Platform Features — state at G7

- **Status:** complete; tagged `night-market/gate-G7-pass`. Sandbox verification is the maintainer's (issue #9): Game Center sandbox posting, an iCloud account round-trip, and the Pencil hardware check.
- **Game Center:** `ScoresPosting` protocol; `GameCenterPoster` (GameKit, compiled) vs `MockPoster` (deterministic, under any `-uitest` arg). `LeaderboardPlan.posts(for:)` maps a finished night to `nm.map.<id>`, `nm.challenge.daily`/`weekly` (context = modifier id) and the 20 achievement ids. Posts fire in `GameController.postNightLeaderboards`; the count shows in the debug overlay (`debug-posts`, asserted non-zero by `testFullNightToResults`).
- **iCloud:** `ProfileSyncing` (`ICloudSync` on NSUbiquitousKeyValueStore, `MockSync` in tests). `ProfileStore` writes through on every persist and restores on first launch when the local file is missing. Placeholder entitlements in `App/NM.entitlements` (iOS target only — macOS needs a real profile, see issue #9).
- **Pencil:** `PencilInputModel` (squeeze toggles erase; unit-tested without hardware) + `PencilBridge` (UIPencilInteraction + UIHoverGestureRecognizer → tile highlight).
- **Mac:** `Game` menu via NotificationCenter (pause ⌘P, save ⌘S, new night ⇧⌘N, debug ⇧⌘D); window is resize-safe (aspect-fit letterboxing).

## P8 Polish, Accessibility, Performance — state at G8

- **Status:** complete; tagged `night-market/gate-G8-pass`. Device frame-rate targets (120 fps M4, 60 fps A16) are the maintainer's — issue #8.
- **Stall shapes:** each cuisine has its own canopy silhouette (`makeCanopyPath`): noodles scalloped, tea round, skewers peaked, dumplings dome, sweets hexagon, seafood trapezoid. High contrast: `Palette.highContrast` (static, set before scene build; menu toggle or `-uitest-highcontrast`) — thicker outlines, max-saturation accents. Presentation-only, never hashed.
- **Assist:** `NightSetup.assist` → `GameState.assistMode` → R-12 grace 600 → 900 ticks. **StateHash encoding version 6** — hashed; the ten golden `.expected.json` files were regenerated (temporary regen test pattern: env `NM_REGEN=1`, then delete). Bump again for any new hashed field.
- **VoiceOver:** `GameController.queueSummary(for:)` ("Noodles: 2 waiting, cooking, 40 percent done. …") published every tick; spoken via the `queue-summary` accessibility element in GameScreen.
- **Perf:** `-uitest-metrics <path>` appends `fps N` per second + one `firstFrame T` line; stress injection is 600 customers (`injectStressCrowd`). Evidence in `docs/STATUS.md` P8.
- **Color-blind review:** `Tools/colorblind-check.py` — Machado 2009 simulation + ΔE ≥ 12 gate. It is a hard gate: rerun it after any accent change. The dumplings/sweets pair was corrected to blue `0x2E7FFF` / magenta `0xF062C8`.
