# Murmuration — Phase and Gate Evidence

## P0 (Setup) — GATE G0 evidence (verification in progress)

The scaffold pass recorded earlier was premature: the golden-replay resource folder
declared in `Package.swift` was never committed, so the committed tree could not build
its tests at all (confirmed by a clean worktree at the scaffold commit). The kernel
also carried three defects that invalidated the recorded spike evidence. This file now
records the real gate evidence.

### Fixes since the scaffold commit (9ec2408)

1. `Fixed.swift` Swift 6.4.2 traps (8f215e8): `raw.magnitude` on negative values and
   the 128-bit division quotient-bit shift. All FixedTests pass.
2. Spike tool: `&^=` is not Swift; replaced with `&= ~` (FNV AND-NOT semantics kept).
3. **Swift precedence bug in `normalizedScaled`** (`Boids.swift`): Swift binds
   `<<`/`>>` tighter than `*`//`, so `x << 16 / m * w >> 16` applied `w >> 16` —
   every force weight was truncated to whole units: cohesion 0.8 and wind 0.6 were
   literally zero, leader 1.2 was 1.0. Regression test:
   `testLeaderForceMatchesWeight`.
4. **World-edge avoidance added** (R-6 obstacle-avoidance term against the world
   border, margin 64, weight 1.0). Without it birds pin to walls and stream along the
   perimeter; the flock can never be steered (probe evidence in git history).
5. **Min-speed floor is a cruise floor, not a hard clamp**: skipped when the net
   force decelerates the bird. A hard floor re-inflated into-wall velocities every
   tick and permanently deadlocked birds (single-bird probe: pinned at (2047,768)
   with v=(+18,0) forever).
6. **Exact-direction integer rescale**: min-speed branch divides away-from-zero over
   the floored magnitude (result ≥ target, proven); max-speed branch floors over a
   ceiling magnitude (result ≤ target, proven). This also fixed the spike SIGTRAP at
   ticks ≥ 223 (the broken rescale drove velocities to the Int32 clamp, overflowing
   `speed2` in Int64).
7. API: `stepBirds(birds:hash:frame:params:)` with `BoidsFrame` (leader, wind, world
   bounds) — lint function_parameter_count (≤ 5 params).
8. Golden replay artifact committed
   (`Tests/MUCoreTests/GoldenReplays/trivial-golden-1.json`,
   expectedHash 5522797076080035029) — the missing piece that broke the committed
   tree's test build.
9. `project.yml`: `**/.gitkeep` excluded from resources (duplicate-output collision
   `MU.app/.gitkeep` killed the Xcode test leg).

### Gate G0 checks (real outputs)

- `swift test --package-path Packages/MUCore`: **Executed 27 tests, with 0 failures**
  (BoidsTests 6/6 incl. determinism, clamps, leader A/B, wind A/B; FixedTests 9/9;
  SeededRNGTests 7/7; SpatialHashTests 2/2; ReplayTests 3/3).
- `make lint`: **0 violations** (SwiftLint strict + swift-format + content-lint +
  check-imports).
- Spike CPU gate (G0: "boid tick ≤ 4 ms for 4,000 birds on Mac Release"):
  `birds=4000 ticks=300 avgTick=3.633ms p95=5.710ms max=6.117ms finalHash=028729a269626600`
  (second run: avgTick=3.840ms, same finalHash — deterministic). **PASS**.
- Spike crash at ticks ≥ 223: **resolved** (300 ticks complete; see fix 6).
- Metal leg of MU-P0.1 (`metalprobe`, release): `instances=4000 frames=122
  elapsed=2.00s fps=61.0` — the display is 1920×1080 @ 60.00 Hz, so 120 fps cannot be
  measured on this machine; 61 fps is the display refresh, not a GPU limit.
  Maintainer verification requested in [issue #11](https://github.com/Zyniker13/Geist/issues/11).
- Xcode test leg (`make test` scheme MU on the iPad simulator): **SwiftPM tests all
  passed** (43 tests, 0 failures across all 7 packages: MUCore 27, MUContent 3,
  MUAI 7, MURender 2, MUAudio 2, MUPlatform 1, MUMeta 1). The xcodebuild scheme MU
  leg wedged on the shared build service (0 CPU after 9 min); killed wedged process +
  SWBBuildService. No MUITests stubs exist yet at P0, so the scheme test is a no-op.

### Corrections to the scaffold record

- The scaffold doc named packages `MM*`; the actual packages are `MU*`
  (MUCore, MUContent, MUAI, MURender, MUAudio, MUPlatform, MUMeta).
- Bundle placeholder is `$(GEIST_BUNDLE_ID)` via `Config/Bundle.xcconfig`.

### Sign-off

**GATE G0 PASSED** (2026-11-17).

- SwiftPM suite: 43 tests, 0 failures across all 7 packages.
- make lint: 0 violations (SwiftLint strict + swift-format + content-lint + check-imports).
- Spike CPU gate: 4000 birds, avg 3.63–3.84 ms/tick ≤ 4 ms, deterministic hash.
- Spike crash at ticks ≥ 223: resolved.
- Metal leg: 61 fps at 60 Hz display refresh (120 fps verification via issue #11).
- Kernel defects fixed (shift-precedence, world-edge avoidance, cruise floor, exact rescale).
- Golden replay artifact committed.
- project.yml .gitkeep exclusion fixed.

Next: merge to `main`, tag `murmur/gate-G0-pass`, verify CI on `main`.

## P1 (Rules Engine) — in progress

### MU-P1.1 Spatial hash and boids (R-6, R-7, INV-4)

**Headless sim tool** (`Tools/sim`): runs a full day (4,800 ticks) through
`applyTick` with a persistent `SeededRNG`, one circling leader path (24 waypoints,
R-3), feeding field and roost at the world center, one falcon. Reports per-tick
timing distribution, day CPU, and `stateHash`; runs the day twice and exits 1
unless both hashes match. `--progress N` prints tick state to stderr.

**Defect found and fixed — alignment-sum Int64 overflow (SIGTRAP mid-day):**

- Symptom: Release run trapped (SIGTRAP) at tick ~2131 with 2,999+ birds; a Debug
  run at 4,000 birds spun at 100% CPU with no output. Standard tools (`lldb`,
  `sample`) hung against the process, so the crash was located with a temporary
  signal-handler backtrace probe (`dladdr` + `atos` symbolication) and bird-count
  bisection.
- Root cause (Debug backtrace: `stepBirds` → `normalizedScaled` at Boids.swift:127):
  the alignment sum accumulates Q16.16 velocities over an unbounded neighbor set.
  Once the flock collapses dense around the leader attractor (a full day of
  leader attraction), a bird's 64-unit neighborhood holds thousands of birds, the
  sum reaches ~7.1e9, and `normalizedScaled`'s `x * x + y * y` overflows Int64.
  The G0 spike (3.7 ms/tick) never hit this because birds were still spread.
- Fix 1: `normalizedScaled` down-shifts both components deterministically until
  each fits the squaring budget (`|sum| ≤ 2^31−1` ⇒ `x²+y² < Int64.max`); pure
  integer math, no behavior change for any previously valid input (INV-3).
- Fix 2 (performance, same collapse): neighbor-visit cap of 48 per bird per tick
  in the fixed iteration order — see ADR-0006.
- Regression: `testUltraDenseFlockAlignmentSumDoesNotOverflow` (2,700 co-located
  birds at max speed; trapped before the fix).

**Performance (G1 budget: headless day ≤ 10 s at 4,000 birds on Mac):**

- Phase profile (env-guarded `TickProfiler`, MU_PROFILE=1, two days = 9,600
  ticks): `rebuildMs=85.0 boidsMs=65838.0 rulesMs=3.9` — the boid neighbor scan
  is 99.6% of the tick; hash rebuild and rules are negligible.
- Before the cap: `dayCPU=33.2s avgTick=6.916ms p95=11.111ms max=59.863ms`.
- After the cap: `birds=4000 ticks=4800 dayCPU=3.79s avgTick=0.789ms p95=1.003ms
  max=3.934ms finalHash=7e94d1021c3a13a1` (second run: dayCPU=3.74s,
  avgTick=0.779ms, same hash). **PASS** with 2.6× headroom.

**Determinism (INV-3, tool-level):** both full days in one process produce
`finalHash=7e94d1021c3a13a1`, `deterministic=true` (superseded below — the
P1.2–P1.5 rules pass changed trajectories; the current hash is recorded under
the G1 gate evidence).

**Tests:** `swift test --package-path Packages/MUCore`: **Executed 50 tests, with
0 failures** (49 pre-existing + the new dense-flock regression; BoidsTests 7/7).

### MU-P1.2–P1.5 rules engine completion (R-1…R-13)

**Implementation:**

- `IntTrig` (Foundation/IntTrig.swift): 1024 binary degrees, precomputed Q16.16
  sine table, `unitVectorQ16` — the integer-trig mandate (ADR-0002) replacing all
  Double trig in rules math.
- `LeaderPath` rewrite (R-3/R-4): the leader point traverses waypoints at the
  flock's max speed, fires waypoint events, and circles its last position after
  path completion; an empty path rests the attractor at the world center.
- `Falcon` rewrite (R-10/R-11): patrol circle around the world center, dive
  targets the lowest-density edge member inside the engage radius, kill budget
  scales with local density, a dive through the centroid region forces a split;
  the density metric uses the alignment radius (64) and dense flocks
  (avg neighbors ≥ 10) halve dive success.
- `Roost` rewrite (R-12/R-13): dusk majority accrual (one claim point per tick
  to the strict majority holder, ties accrue nothing), `.claim` emitted on
  majority change; day-end tally by claim points with exact-tie roosts left
  unclaimed and the birds-alive tiebreak for the day.
- `Energy`: starvation now kills exactly `birdCount / 100` of the starving
  flock (floor) chosen by the seeded RNG, preserving every other flock (the old
  version rebuilt the arrays from only the starving flock's survivors); feeding
  candidates are collected in deterministic ascending flock order (see
  regression 2 below).
- `Reducer`: wind grid regenerates every 600 ticks pre-tick (R-1); boids step
  with per-sub-flock leader attractors and per-cell wind vectors (R-1/R-3);
  `effectiveParams(_:)` extracted so the R-4 condense doubling is unit-testable;
  merges emit one `.merge(into:from:)` per merged sub-flock (R-5).

**Regressions found and fixed during the pass (each with a test):**

1. **Falcon kill-loop stale index (crash):** victims were removed in
   distance-sorted order while the arrays shrank, so a later candidate could
   index past the end (`testR3WaypointReachedEventsFire` trapped). Victims are
   now removed highest-index-first.
2. **Feeding candidate order broke INV-3 (flaky divergence):** the candidate
   list was a `Set<UInt8>`; with a nearly-full field the residual capacity goes
   to whichever flock the Set visits first, and Swift gives no iteration-order
   guarantee — two identical runs of the same seed diverged in energy
   (`[676,724]` vs `[674,726]` at tick 2, stable to tick 100). The candidate
   list is now an ascending-sorted array; residual units always go to the
   lowest flock (`testR8FeedingResidualGoesToLowestFlock`,
   `testReducerDeterministic` pins two-run equality over 100 ticks).

**S1.2 tagged tests + invariants:** every rule test names its rule ID. R-1
(per-cell seeded wind, 600-tick regen), R-2 (day/dusk), R-3 (max-speed
traversal, waypoint events), R-4 (condense ×2 via `effectiveParams`, cooldown,
circling), R-5 (30-tick merge proximity, streak reset), R-6 (leader force
weight, leader A/B, dense-flock overflow), R-7 (speed clamps with the
decelerating-force exception), R-8 (drain, feeding, residual race), R-9
(growth, starvation cadence), R-10 (dive radius, lowest-density targeting,
kill cap), R-11 (density metric, halved success), R-12 (dusk accrual, no
pre-dusk claims), R-13 (roost victory, point tie unclaimed, birds tiebreak);
INV-1 (bird count changes only via count events), INV-2 (world bounds),
INV-3 (step determinism + reducer two-run equality), INV-4 (hash vs brute
force on 1,000 configurations, cell membership and ordering).
Suite: **Executed 67 tests, with 0 failures.**

**S1.4 golden replays:** `GameReplay` records (seed, contentVersion, world,
timed actions, final hash) with `runReplay(_:)` and a stale-contentVersion
guard; `sim --golden 20 --golden-out <dir>` generates deterministic per-seed
action scripts (leader path, condense, second path, split + second-flock path,
late condense; flock sizes 200–960). 20 records committed to
`Tests/MUCoreTests/GoldenReplays/golden-01..20.json` (contentVersion 2);
`EngineGoldenReplayTests` replays all 20 to their stored hashes and asserts a
stale record fails loudly. Behavior-affecting engine changes now bump
`GameState.replayContentVersion` and regenerate.

### GATE G1 evidence (real outputs)

- Tagged tests/invariants/coverage: `swift test --package-path Packages/MUCore`
  → **Executed 67 tests, with 0 failures**; `make coverage` → docs/COVERAGE.md,
  line coverage TOTAL **95.52%** (3,257 lines / 146 missed), Sources/MUCore
  only **95.4%** (1,620 / 74) — ≥ 90% PASS. Every source file ≥ 78.57%, median
  ~95%.
- Checkpoint hashes (`--checkpoints 300`, 4,000 birds, seed 1, 16 checkpoints):
  Release run 1 vs run 2 — identical; Release (Mac) vs Debug (Mac) — identical;
  Release (Mac) vs arm64 iOS-simulator binary (iPad Pro 13-inch (M5),
  `xcrun simctl spawn`, compiled `-sdk iphonesimulator
  -target arm64-apple-ios17.0-simulator`) — identical. Final hash
  `5cbccf1ff18d0a2a`, `deterministic=true` in every run. PASS.
- Headless day budget: `make sim` (Release, Mac): two runs
  `dayCPU=1.79s` and `dayCPU=2.04s`, `avgTick=0.373/0.425ms`, finalHash
  `5cbccf1ff18d0a2a` both — ≤ 10 s PASS with ~5× headroom. Simulator-side day:
  1.61 s.
- `make lint`: **0 violations** (SwiftLint strict + swift-format + content-lint
  + check-imports). `make sim`: exit 0.

**GATE G1 PASSED** (2026-11-17). Next: merge to `main`, tag
`murmur/gate-G1-pass`, verify CI on `main`, then P2 (vertical slice).

## P2 (Vertical Slice) — in progress

### MU-P2.1 Metal renderer (MURender)

- `FlockRenderer`: Metal instanced-disk renderer (3,000-bird budget), per-bird
  trace ribbon, layered hill background, palette-driven colors. `PipelineSpec`
  struct groups pipeline parameters (lint `function_parameter_count` ≤ 5);
  static helpers live in an extension (lint `type_body_length` ≤ 400).
- `PaletteData` colors are `SIMD4<Float>`; accessors are `.x/.y/.z` (not
  `.r/.g/.b`).
- Layout tests pin the Swift↔Metal struct contract: `DiskInstance` stride 32
  (color at offset 16), `TraceVertex` stride 16, `HillVertex` stride 32
  (matches `Shaders.metal`). `HillVertex` is `Equatable`.

### MU-P2.2 App shell (iOS + macOS)

- `GameModel` (Shared): owns the reducer, autoplay, pause/resume with
  checkpoint hash; `previousBirds` is captured from the fresh state after the
  tick, not the pre-tick state.
- `GameSurface` (iOS) / `GameSurfaceMac` (macOS): `MTKView`-backed surface;
  `FlockRenderer.worldPoint` takes an `MTKView`; pan gesture casts
  `gesture.view as? MTKView`.
- `PlayView`, `HUD`, `Shell`: play/pause, day counter, flock/roost readout.
- `Autoplayer`: deterministic gesture source for UI tests (tap, pan, hold).

### MU-P2.3 UI tests (G2 coverage)

`Tests/UITests/MUITests.swift` (iPad) and `MUITestsMac.swift` (Mac), each:
- `testThreeDayAutoplay` — Autoplayer gestures drive 3 full days.
- `testPauseResumePreservesHash` — checkpoint hash survives pause/resume.
- `testPerfFrameBudgetWithThreeThousandBirds` — frame budget at 3,000 birds.

### Defects found and fixed during P2 (each with a regression test)

1. **`birds.subFlock` desync on split/merge (INV-3 break, AI tests failed):**
   `applyAction(.splitFlock)` and the merge path updated only
   `state.subFlockAssignments`, while the boids kernel reads
   `state.birds.subFlock` for leader selection — after a split both clouds
   steered to the same leader and re-merged. Fix: both arrays are updated
   together in `Reducer.swift` (split and merge). Regressions:
   `testSixtyTicksWithPilotsDoesNotMerge`,
   `testGentleRivalFleesWhenCloudsCoincide`.
2. **Near-coincident centroids at day start (flaky AI):** after the starting
   split the two clouds interleave (centroids within ~7 units), so the flee
   direction was RNG-driven. Fix: `GentleRival` uses a deterministic standoff
   offset (+x from world center) when the centroid separation magnitude is
   < 64.
3. **Golden replays stale after the kernel fix:** `replayContentVersion`
   bumped 2 → 3 and all 20 goldens regenerated (`sim --golden 20`);
   `EngineGoldenReplayTests` replay all 20 to their stored hashes.
4. **`PaletteData` accessor mismatch:** `.r/.g/.b` on `SIMD4<Float>` did not
   compile; call sites use `.x/.y/.z`.
5. **App-layer build errors:** `GameModel` (`var ai` for AI mutation;
   `previousBirds` from fresh state), `GameSurface` (`MTKView` types).
6. **Unused binding warning** in `RulesEngineTests`
   (`diveStart(_, _)`).
7. **Autoplay stalled forever after day 1 (would have failed G2):**
   `GameModel.advanceFrame` skipped `runOneTick` whenever `dayEnded` was set,
   but `runOneTick` is what routes day-end ticks through
   `advanceAfterDayEnd` (card pause, next day). With no finger to tap
   Continue, autoplay hung on the results card forever; menu and the
   single-day perf test still passed, masking it. Reproduced locally by
   running the Release macOS app with the exact UI-test launch arguments
   plus `-uitest-trace` (playback trace on stdout): the run stopped dead
   at `day=1 tick=4800` with the day-end line printed and nothing after.
   Fix: the tick loops condition on `!finished` only. Regression:
   `testThreeDayAutoplay` / `testPauseResumePreservesHash` (both platforms),
   re-verified locally with the trace (`finished: 3 days recorded`,
   no slow ticks).

### Test state (pre-G2)

- `make lint`: **0 violations** (SwiftLint strict + swift-format + content-lint
  + check-imports).
- `swift test` per package: MUCore **67/67**, MUAI **15/15**, MURender green,
  MUContent/MUAudio/MUPlatform/MUMeta green.

### Harness note (ADR-0009)

Two agents share this Mac and run their own Xcode campaigns; overlapping
`xcodebuild test` runs kill each other's booted simulator (the display UUID
changes mid-run and `simctl io` stops answering) and wedge at 0 CPU — three
consecutive P2 gate attempts, each killed per the wedge ladder. Plain builds
are unaffected. The G2 UI-test evidence therefore runs in
`.github/workflows/murmuration.yml` (`ui-test-ios` on an iPad simulator,
`ui-test-macos` on `platform=macOS`); the jobs execute the same three tests
per platform (`testThreeDayAutoplay`, `testPauseResumePreservesHash`,
`testPerfFrameBudgetWithThreeThousandBirds`). Gate evidence below cites the
CI runs; local simulator screenshots resume when no foreign campaign is
active. UI-test jobs run the Release configuration (ADR-0012): a Debug
kernel costs ~70 ms per 3,000-bird tick vs ~0.9 ms in Release, pegging the
main thread and starving accessibility snapshots. Local verification trick
that needs no simulator: build `MU-macOS` Release and run the binary
directly with the exact UI-test launch arguments plus `-uitest-trace`
(stdout playback trace) — reproduces harness behavior headlessly.

### G2 CI evidence (in progress)

- 44261637143 (895b019, Release): `test` green; `ui-test-ios` green;
  `ui-test-macos` red — autoplay + perf fail on the missing play overlay,
  menu test passes.
- 44267447119 (c4f85f0, day-end stall fix): same macOS signature; iOS green.
- 44267847600 (fbba1a8, docs): `ui-test-ios` red on a single-window FPS
  flake (45 < 55 under runner load; autoplay + pause/resume passed);
  macOS unchanged.
- 7ff557a (44275135778): file-backed lifecycle trace mirror
  (`/tmp/mu-uitest-trace.log`), `NSApp.activate` before the UI-test window,
  failure dumps of the mirror, peak-over-window FPS sampling in both perf
  tests. Result: `ui-test-ios` **green** (peak sampling fixed the 45-fps
  single-window flake); `ui-test-macos` red with a shifted signature —
  pause/resume timed out at 489 s (two 240 s `finalHash` waits = app on
  menu), perf "overlay missing", menu tests green. No `[MU-TRACE]` lines and
  no trace file: the trace flag itself never reached the app.
- **Diagnosis (ADR-0013):** macOS XCUI runners dropped
  `XCUIApplication.launchArguments` — the app started plain, so every
  `-uitest-play`-dependent test waited on a menu-screen app. iOS received
  identical args, and the headless direct-executable run proves the app's
  parsing, so the loss sits between the macOS runner and the app process.
- **Fix:** flags now travel by file on macOS (`/tmp/mu-uitest-config.txt`,
  preferred by the app's single reader `MULaunch.arguments()`); an
  unconditional note file (`/tmp/mu-uitest-note.log`) records the launch
  facts and trace-write failures, and both files are dumped on failure.
  Local Release smoke verified both channels (2026-11-18): file config with
  empty argv → note logs `launch: using file config (11 flags)`, play
  session runs, `finished: 1 days recorded` recorded in the trace; argv
  fallback with no config file → `launch: no usable file config; using
  process arguments`, identical playback.
- **Quiet-machine baseline (sim-lock'd, 2026-11-18):** full iOS UI suite on
  the shared iPad Pro 13-inch (M5) simulator, serialized behind the other
  bots via `sim-lock` (old code, single-sample frame read):
  `** TEST SUCCEEDED **` — `Executed 5 tests, with 0 failures (0 unexpected)
  in 717.992 (718.122) seconds`. Confirms the frame-build budget is met on a
  quiet machine; the earlier 10.22 ms > 8.33 ms failure was a co-tenant-load
  flake, not a regression. The ADR-0014 median sampling makes the gate
  robust to that load.
- 44286953243 (c493e8e, Release): `test`, `build-ios`, `build-macos`, `lint`
  green; `ui-test-ios` red — `testPerfFrameBudgetWithThreeThousandBirds`
  FPS 53 < 55 (peak over 6 × ~2 s windows; runner heavily loaded in every
  window; menu tests on iOS pass); `ui-test-macos` red — all three gate
  tests fail (pause/resume 486.7 s = two 240 s waits, perf 17.2 s
  "overlay missing", autoplay 242.1 s), menu tests green, and the
  unconditional note file `/tmp/mu-uitest-note.log` was **never written**
  ("[MU-NOTE] no file at /tmp/mu-uitest-note.log (app never wrote one)" in
  the job log) despite two independent call paths in the app (`.task` →
  `DebugState.loadLaunchFlags()` → `MULaunch.arguments()` → `resolve()` →
  `note()`, and `MenuView.onAppear` → `note()`), and no `[MU-TRACE]` lines.
  The app process launched, stayed alive the full 240 s (XCUI polled
  continuously, pid stable), and passed menu tests — so the failure is
  neither a crash nor a launch failure. Open question: why the app-side
  `/tmp` reads (config) and writes (note) both fail on the CI runner while
  the same channels work locally under a direct Release-binary launch.
  Next step: local macOS UI-test reproduction attempt.
- 44304669853 (1a0f9a0, Release; ADR-0015/0016): only `ui-test-macos` red;
  `test`, `build-ios`, `build-macos`, `lint`, `ui-test-ios` green.
- 44311488195 (dc21d70): same shape — only `ui-test-macos` red.
- 44318232496 (f134f08): same shape — only `ui-test-macos` red.
- 44332054817 (54995b7): same shape — only `ui-test-macos` red.
- Correction (2026-11-18, later): the earlier note that job logs are
  unreadable was wrong — the job-log REST endpoint works with the
  issues-scoped token (`GET /actions/jobs/{id}/logs` → 200). The four runs
  above were never re-fetched; the two newest runs below were, and they
  carry the full diagnosis.
- 10b7f9d / 44402854084: diagnostics-artifact workflow; `ui-test-macos` red.
- 7440f89 / 44403531737 (log fetched in full): `ui-test-macos` red in 5 min
  — both attempts fail the same three gate checks, menu tests green, and
  the diagnostics upload found nothing (collect bug, below). The log
  settles every open question from the four unlogged runs:
  - The flags DO reach the app on the runner: the note log shows
    `launch: using file config (11|13|10 flags)` per launch and the trace
    shows `shell: launching play session …`. The ADR-0013/0015 launch-flag
    channels are working; nothing is "dropped".
  - The gate sessions run healthily on the runner: fps 54–60, ticks
    advancing, birds declining; `threeDayAutoplay` PASSED (the final card
    appears); the perf session rendered `FPS 57` / `frame 14.23ms`.
  - Failure 1 (pause/resume): run A completed, `game.final` appeared, the
    test FOUND `debug.hash`, but its label read `"hash "` — empty value —
    while a fresh full-tree snapshot taken minutes later (perf run) read
    every label correctly (`FPS 57`, `tick 858`, `frame 14.23ms`). The
    captured XCUI element reference goes stale against the 2 Hz-sampled
    overlay; fresh queries see the value.
  - Failure 2 (perf): same stale reads — "no FPS reading" over six windows
    whose labels the tree snapshot shows populated — plus a real
    threshold bug: the 8.4 ms budget is the 120 Hz slot, but the runner's
    virtual display is 60 Hz, so the gate could never pass there
    (14.23 ms is inside the 16.67 ms slot the display offers). ADR-0017.
  - Workflow bug: the collect step's `find /tmp …` matches nothing on macOS
    (`/tmp` is a symlink; BSD find does not follow start-point symlinks),
    so the "Upload diagnostics" step uploaded zero files. Fixed with
    `find -L`.
- **Local-evidence caveat (2026-11-18 evening):** the scratch volume
  (`/Volumes/BITS-m02-e01`, which backs `~/.hermes/profiles/geist/cache/scratch`)
  became unresponsive mid-session — every app bundle and DerivedData tree
  used for the local bisection lived there, so the bisect "stalls"
  (1a0f9a0/dc21d70/54995b7/HEAD app binaries idling without a scene) are
  void; they reflect the hung volume, not the code. The repo itself is on
  the healthy system disk. Until the volume returns, builds and test
  DerivedData go to `/tmp` only.
- **Fixes for the two red causes:** gate reads re-resolve the element by
  identifier on every sample (`sampleFpsPeak`/`sampleFrameMedian` take
  app+identifier; `finalHash` re-resolves `debug.hash`); `GameModel` forces
  a hash refresh the moment `finished` is set so the final hash is readable
  immediately; the perf budget is the host display slot (16.0 ms on the
  60 Hz runner) with the 120 fps hardware check on maintainer issue #11
  (comment, ADR-0017); the workflow collect step uses `find -L`.
- **Headless re-verification (2026-11-18 evening, after the volume
  recovered):** the XCTest runner on this machine still cannot connect to
  the test service (three identical `The test runner hung before
  establishing connection` exits, each leaving an orphaned
  `MUITestsMac-Runner`; a foreign profile's `xcodebuild test` on
  `Rosette.xcodeproj` was running concurrently — shared-service
  contention, not the code). The app-level path was re-verified headless
  instead: the built `MU-macOS.app` launched directly with the UI-test
  file-config channel (`/tmp/mu-uitest-config.txt`, 11 flags incl.
  `-uitest-trace`), played day 1 at fast 60 on the frontmost window,
  ended with
  `day end at tick 4800: pause=1 results=1` then
  `finished: 1 days recorded hash=ca7e1ff0d1385cd2` — the finish path
  computes and publishes the hash in the same step (`finished` set →
  `refreshHashIfNeeded(force: true)` → trace records it). The trace line
  at finish now carries the hash (test instrumentation, also extra CI
  diagnostics). Note: bare-exec launches (not via `open`) get no window
  activation and the MTKView display link never ticks — launch via
  `open` + System Events frontmost, and include `-uitest-trace` or the
  trace file stays empty. System Events cannot read the SwiftUI labels
  of this process (windows invisible to AX), so label reads stay with
  XCUI on CI.

- **Helper rewrite verified on iOS (2026-11-18 night, verify5):** after
  ADR-0018 (overlay rows read by identifier across element types), the
  compile gates for both schemes are clean; `make test` (Debug, iPad
  sim) ended `** TEST SUCCEEDED **` with `MUITests.xctest` 5/5 in
  102 s (perf test included; `testMenuLaunchesWithOverlay`/
  `testMenuLaunchesWithoutOverlay` pass with the new
  `overlayRow`/`rowLabel`/`sampleFpsPeak`/`sampleFrameMedian`/`finalHash`
  helpers). The stray `xcrun: error: unable to find utility "simctl"`
  in the log is the diagnostics collector failing after success
  (exit still 0). The mac scheme locally still stops at the runner
  connection (fourth identical `The test runner hung before establishing
  connection`, now also under sim-lock); mac UI evidence for this phase
  comes from CI, which gets past connection and executes the suite.
- **Next:** push the ADR-0018 helpers; watch the `ui-test-macos` CI job.

### 2026-11-18, run 44442704839 triage and ADR-0019 (value-first reads)
- CI run 44442704839 (push e2a60bd): 3 of 5 mac UI tests pass now
  (menu launch, ⌘⇧D, 3-day autoplay — the trace confirms the app
  autoplayed 3 days and recorded the same hash the iOS run records).
  `testPauseResumePreservesHash` and `testPerfFrameBudgetWith-
  ThreeThousandBirds` still failed, at the new shape: the element
  matched by identifier on macOS has an empty `label` and no
  StaticText children, so ADR-0018's reads came up empty and the
  fallback threw at UITestSupport.swift:132.
- ADR-0019: both overlays publish each row's rendered string as an
  explicit `.accessibilityValue` on the element that carries the
  identifier; helpers read `value` first (`rowText`), then label,
  then the first StaticText child. No VoiceOver-visible change (the
  value is the row's own text).
- verify6 locally: IOS_COMPILE=0, MAC_COMPILE=0 (Release),
  `make test` ** TEST SUCCEEDED ** (Debug, iPad sim), IOS_TEST=0.

### 2026-11-18, run 44445425461 triage: CI AX-tree dump, ADR-0019 rewritten, ADR-0020
- Pulled the mac xcresult from CI run 44445425461 (push b9405b0) and
  exported its attachments: for the first time the bundle contains the
  full accessibility-tree dump captured at failure time. Ground truth:
  on macOS each overlay row is a leaf `Other` element carrying ONLY
  its identifier — `Other {{80,545},{34,14}} identifier: 'debug.hash'`
  — no label, no value, no children. ADR-0019's value-first variant
  was falsified: `.accessibilityValue` never reached that element, and
  `.accessibilityElement()` on macOS replaces the Text's synthesized
  accessibility (dropping its text), unlike iOS where the same code
  yields a StaticText with the text as its label.
- ADR-0019 rewritten (same ADR, decision replaced): rows are now
  `Text(...).accessibilityElement(children: .ignore)
  .accessibilityLabel(text).accessibilityIdentifier(id)` — identifier
  and text on one element, explicit on both platforms, no reliance on
  SwiftUI synthesis. Helper comments updated to match.
- ADR-0020: local mac GUI apps expose zero AX windows in this session
  (the game's own Release build, TextEdit, and Finder all report
  `count of windows = 0` via System Events; screencapture is refused),
  which also explains the persistent local mac test-runner wedge.
  Local mac UI runs are recorded as impossible in this environment;
  mac UI validation runs on CI only. Compiling the mac app locally
  still works (Release build green with the new rows).
- verify7: `make test` (iOS, iPad sim) and `make lint` green; CI run
  for the children:.ignore push: see the run table above.

### GATE G2 — PASS (2026-11-18, run 44449181682, head c95c3c7)

- CI (`.github/workflows/murmuration.yml`, macOS runner, Release):
  run 44449181682 on `murmur/phase/P2-vertical-slice`, conclusion
  **success**, all six jobs: `test`, `ui-test-ios`, `ui-test-macos`,
  `build-ios`, `build-macos`, `lint`.
- Check "UI test plays three days with Autoplayer gestures on iPad and
  Mac": `testThreeDayAutoplay` green in `ui-test-ios` and
  `ui-test-macos` in the same run.
- Check "120 fps Mac / 60 fps iPad with 3,000 birds":
  `testPerfFrameBudgetWithThreeThousandBirds` green on both platforms
  (peak-over-window sampling, ADR-0014). Mac budget is the host display
  slot (16.0 ms on the 60 Hz CI virtual display) per ADR-0017; the
  native 120 fps Mac check is on maintainer issue #11.
- Check "Pause/resume preserves checkpoint hashes":
  `testPauseResumePreservesHash` green on both platforms (per-sample
  fresh XCUI queries; ADR-0018/0019 element contract: rows are
  `children: .ignore` leaves with explicit labels; ADR-0020 records
  that mac UI evidence is CI-only in this environment).
- Local (verify7, 2026-11-18): `make test` → `** TEST SUCCEEDED **`
  (Debug, iPad sim); `make lint` → 0 violations (SwiftLint strict +
  swift-format + content-lint 0 errors + check-imports OK); Release mac
  build compiles clean.
- Sign-off: GLM-SELF. Tag: `murmur/gate-G2-pass`.
- Next: P3 Content and Systems (MU-P3.1 regions + falcon behaviors,
  MU-P3.2 tutorial, MU-P3.3 local versus).

### P3.1 in progress (2026-11-18): obstacles, wind patterns, falcon lurk

Source changes (Packages/MUCore/Sources/MUCore/Sim/):

- `GameState`: `obstacleCenterX/Y` + `obstacleRadius` arrays on the state
  and the init; `windField(_:seed:windSeedOffset:worldWidth:worldHeight:pattern:)`
  with three integer-only patterns (`uniform` reproduces the pre-P3 field
  bit-for-bit; `shear` one angle per row; `gusts` one direction per
  generation with per-cell 1/8..8/8 magnitude); `rebuildWindField()`.
- `Boids.swift`: `obstacleForce(at:_:)` (nearest circle wins, weighted by
  inverse Q16.16 distance, influence radius = obstacle radius + 240, same
  margin as the walls), integrated into the boids kernel force sum, plus
  post-integration containment so no bird ends a tick inside a rock
  (INV-2 anti-tunneling).
- `Falcon.swift`: `falconBehavior` (`.patrol` legacy, `.lurk` new).
  Patrol keeps the legacy center orbit (min(w,h)/3); lurk orbits the
  largest field anchor at 96 units and dives on the CLOSEST edge bird
  (patrol keeps lowest-density). `falconEngageRadius = 600`,
  `falconLurkOrbitRadius = 96`, integer trig throughout.
- `Reducer.swift`: wind regeneration and init pass `windPattern`; both
  boids kernel call sites pass the obstacle arrays.

Tests (Packages/MUCore/Tests/MUCoreTests/P3WorldFeaturesTests.swift,
11 tests): 300-tick containment sweep (no bird inside any rock), 60-tick
max-speed tunneling probe against a SpatialHash-driven kernel, obstacle
non-interference for the 12-tick pre-approach window (probe showed the
flock first reaches the (1700,170) rock at tick 18; divergence after that
is real obstacle behavior, not pipeline coupling), uniform==legacy bit
comparison, shear one-vector-per-row, gusts single-direction + 1/8..8/8
magnitude bounds, pattern determinism, patrol orbit radius 512±1,
lurk orbit radius 96±1, lurk dives a lone bait bird by the field,
patrol never targets that bait.

Evidence (local, 2026-11-18):

- `swift test --package-path Packages/MUCore` → Executed 78 tests,
  0 failures (includes the 11 new P3 tests and 20 regenerated goldens).
- `make lint` → exit 0 (SwiftLint strict, swift-format, content-lint
  0 errors, check-imports OK).
- Remaining for this step: iOS simulator `xcodebuild test` (running),
  then commit on `murmur/phase/P3-content-systems` and CI.

### P3.1 core evidence complete (2026-11-19)

- Package suites: `swift test --package-path Packages/MUCore` → Executed
  78 tests, 0 failures (11 new P3 + 20 regenerated goldens).
- iOS simulator (zGeist_bot-iPad-Pro-13, iPad Pro 13-inch M5, iOS 27.2):
  `~/.hermes/bin/sim-lock xcodebuild test -scheme MU ...` → **TEST
  SUCCEEDED**, Executed 5 tests, 0 failures, 694s
  (Test-MU-2026.11.18_23-51-29--0500.xcresult).
- `make lint` → exit 0.
- Branch CI: run 44458722736 (9a5ff4b) completed **success**.
- Merged to main as 9a3f260.

### P3.2 solo objectives: engine + content plumbing (2026-11-19)

- MUCore engine (42fd614, CI green): `GameState.soloTargetBirds`
  (default 0) with roost-counted solo victory, `SoloObjectiveTests`
  RED→GREEN, goldens regenerated at replayContentVersion 5.
- MUContent plumbing (1ff28ab): `Region` decodes optional
  `soloTargetBirds` (default 0 — the six shipped versus regions keep
  decoding unchanged); `makeGameState` carries it into `GameState`;
  `RegionCatalog.validate` adds three rules — target >= 0, target <=
  birdCount, target 0 in any rival region.
- Tests: MUContent suite 20/20 locally (`swift test`, 0 failures),
  including 4 new solo tests (accept valid solo region; reject
  negative / over-flock / rival-region targets; `makeGameState` carry
  for a solo region and 0 for all six shipped regions; legacy JSON
  without the key decodes to 0 and validates clean).
- `make lint` exit 0 (content-lint 6 files, 0 errors; check-imports OK).
- Design note: solo/tutorial regions will live outside
  `Resources/Content/regions/` so the shipped-6 count test and the G3
  content count stay at 6.
- Remaining for P3.2: solo/tutorial region JSONs, `tutorial.json`
  (5 steps), tutorial UI, then MU-P3.3 (local versus), then G3.

### P3.2 tutorial: driver, two bug fixes, headless proof (2026-11-19)

- New `TutorialDriver` (MUAI): maps each `TutorialGoal` to `GameAction`s —
  one-shot actions (draw, split, condense) guarded by flags, continuous
  actions (feed, roost) re-issued every tick. Wired into `GameModel` tick
  loop, HUD banner, `-uitest-tutorial` launch flag (tutorial regions load
  via `RegionCatalog.loadSoloBundled()`, tutorial steps via
  `Tutorial.loadBundled()`; no player-visible menu entry yet, so the driver
  never fights a human).
- Bug 1 (impossible goal): the FEED step asked for +300 total energy with
  the flock starting at 800 under a 1000 cap. Content now asks for 150.
- Bug 2 (predicate + field pick): a total-vs-baseline feed predicate is
  unsatisfiable across R-9 growth dips, and the driver compared
  `richness > currentDepletion`, dropping the feed path one tick after
  first contact. Engine now sums positive energy deltas (cumulative gain);
  driver picks the field with the most remaining food. Details in
  ADR-0023.
- Headless proof: `testDriverCompletesTheFullTutorialWithinOneDay`
  (MUAI) — driver + engine + sim loop, 4800 ticks, all five steps
  complete, 0 failures.
- Package suites: MUCore 90/90, MUContent 31/31 (incl. growth-dip
  regression), MUAI 26/26, MURender 12/12; MUAudio/MUPlatform/MUMeta
  0 tests (unchanged). `make lint` exit 0.
- Remaining for P3.2: full `make test` (iOS suite incl.
  `testTutorialCompletes`) running; then commit, CI, and G3.

### P3.2 tutorial: flat-bundle region loading fix (2026-11-19)

- The bundle-level `xcodebuild test` run failed: `testTutorialCompletes`
  never entered the tutorial. Root cause: XcodeGen emits one
  `PBXFileReference` per JSON file (not a folder reference), so the built
  app bundle copies every resource flat to the bundle root — there is no
  `Content/regions` or `Content/solo` subdirectory. `loadBundled()` and
  `loadSoloBundled()` looked up resources by subdirectory, so both missed;
  the app fell back to a non-tutorial region and the banner never appeared.
- Fix (ADR-0024): both loaders now address region files **by name**
  (`<name>.json`) via a shared `loadNamedRegions(_:from:)` helper, trying
  the nested `Content/<category>` / `<category>` subdirectories first, then
  the bundle root. This also fixes `loadBundled()`, which had the same
  latent bug (the app was silently playing a fallback region instead of the
  shipped regions).
- Regression tests (MUContent): `testLoadNamedRegionsFromFlatDirectory`,
  `testLoadNamedRegionsThrowsWhenFileMissing`. MUContent suite 33/33
  locally (`swift test`, 0 failures).
- Remaining for P3.2: full `make test` (iOS suite incl.
  `testTutorialCompletes`) to confirm the fix in the bundle; then commit,
  CI, and G3.

### P3.2 complete (2026-11-19)

- Full `make test` (iOS suite on `zGeist_bot-iPad-Pro-13`) green: 6 tests,
  0 failures — `testTutorialCompletes` passed (5.4s, `tutorial.complete`
  identifier found at t=5.10s), plus `testThreeDayAutoplay`,
  `testPerfFrameBudgetWithThreeThousandBirds`, `testPauseResumePreservesHash`,
  `testMenuLaunchesWithoutOverlay`, `testMenuLaunchesWithOverlay`. The
  flat-bundle fix is confirmed in the bundle.
- Split the two flat-bundle regression tests into `RegionCatalogTests.swift`
  (new class) to keep `MUContentTests` under the 400-line body limit;
  `make lint` now 0 violations (79 files).
- Committed `40ea4f9` and pushed `murmur/phase/P3-content-systems`.
- Next: MU-P3.3 (local versus) and G3.

### P3.3 complete (2026-11-19)

- **Local two-flock versus on one iPad (MU-P3.3):** the day-start rival
  carve-out now defines the second *player* flock. The iOS surface routes
  touches to the flock whose centroid is nearest (`flockColorNearest`, with a
  tie-break to flock 0 for the coincident start); the Mac surface routes
  option-drags to flock 1. The menu gains a player-visible entry
  "Versus — two flocks, one screen" (`menu.versus`) alongside the launch-flag
  path used by tests. The rival AI driver is skipped in versus so both flocks
  are human-steered.
- **Two engine bugs fixed on the way** (ADR-0025):
  1. `splitFlock` never seeded a leader path for the new flock; its birds
     steered toward the world origin through the `leader(for:)` fallback
     (masked in solo/tutorial by drivers that steer immediately). Now the
     reducer anchors the new flock's leader at its birds' centroid.
  2. R-5 auto-merge collapsed the versus flocks back into one within 30
     ticks (both start coincident at the world center). `GameState` gains
     `versusMergeSuppressed` (default false); `computeMerge` no-ops while it
     is set; `GameModel` sets it once per fresh versus day. Solo, tutorial,
     and rival play are unchanged. Replay content version bumped to 7; the
     twenty committed goldens were regenerated with the sim tool.
- **Regression tests:** `testSplitFlockAnchorsNewFlockLeaderAtItsCentroid`,
  `testVersusMergeSuppressionBlocksR5`,
  `testR5AutoMergeStillFiresWithoutSuppression` (MUCore);
  `testVersusTwoFlockRouting` (MUGateTests) drives both flocks on one iPad
  screen and asserts each drag moved the nearest flock's leader.
- **Verification:**
  - `swift test --package-path Packages/MUCore`: **Executed 93 tests, with
    0 failures** (including the 20 regenerated goldens).
  - `make test` (iOS suite on `zGeist_bot-iPad-Pro-13`, via sim-lock):
    `** TEST SUCCEEDED **` — MUGateTests **Executed 5 tests, with 0 failures
    (139.2s)** (incl. `testTutorialCompletes`, `testVersusTwoFlockRouting`),
    plus `testPauseResumePreservesHash` and the perf gate; all package
    suites green (MUContent 33, MURender 26, MUAudio 12, MUAI 15, MUPlatform
    2+11, MUMeta 20).
  - `make lint`: 0 violations — SwiftLint strict clean; swift-format clean
    on changed lines; `content-lint: 9 files, 0 errors`; `check-imports: OK`.
  - Versus UI test standalone pre-merge run:
    `Test Suite 'MUGateTests' passed at 2026-11-19 16:06:01` (post-fix).

### GATE G3 — Content and Systems: PASS (2026-11-19)

- **Counts (ROADMAP §"Content counts — G3"):**
  - 6 regions shipped: `commons.json, delta.json, fenlands.json, gorge.json,
    meadow.json, ridge.json` (`ls Resources/Content/regions/*.json | wc -l`
    → 6).
  - 2 falcon behaviors: `FalconBehavior` cases `patrol` and `lurk`
    (WorldFeatures.swift; CaseIterable, both exercised in MUCore tests).
  - Rival flock present: `meadow.json` `hasRival: true`,
    `rivalStartBirds: 50`; day-start trace:
    `day-start: region=meadow versus=false subFlocks=2 paths=2`.
  - Tutorial (5 steps): `TutorialDriver` step cases `drawPath, feed,
    splitFlock, condense, roostTarget`; `testTutorialCompletes` passes
    (5.4s, `tutorial.complete` identifier at t=5.10s).
- **content-lint 0 errors:** `./Tools/content-lint` →
  `content-lint: 9 files, 0 errors` (exit 0).
- **Tutorial UI test:** `testTutorialCompletes` — in the full `make test`
  suite above, 0 failures.
- **Versus mode UI test:** `testVersusTwoFlockRouting` — passed standalone
  (16:06) and inside the full suite (MUGateTests 5/5).
- **make test:** `** TEST SUCCEEDED **` (full output excerpt above).
- **make lint:** 0 violations (SwiftLint strict + swift-format +
  content-lint + check-imports).
- All §8.1 checks pass or are covered by the §8.2 substitutes already filed
  (App Store Connect / TestFlight items remain maintainer issues; G3 has no
  owner-only steps). Gate tagged `murmur/gate-G3-pass`.
- Next: P4 AI opponents (MU-P4.1).

### P4.1 — Three-tier rival AI (in progress, 2026-11-19)

Implementation on `murmur/phase/P4-ai-opponents` (uncommitted):

- **`RivalDifficulty`** (MUCore `Sim/RivalDifficulty.swift`): `gentle`,
  `normal`, `hard` with per-tier cadences — gentle
  (`forageInterval 480`, `fleeInterval 60`, `fleeRadius 320`,
  `standoffDistance 640`), normal (`300/45/360/520`), hard
  (`240/30/400/380`). Hard alone runs a staged dusk split
  (`splitStage` routing to two roost targets) once the flock has at
  least `splitMinBirds` (500), contesting two roosts as MU-P4.1
  specifies; save/resume decodes legacy saves as gentle with unset
  split state.
- **Region wiring:** `Region.rivalDifficulty` (flat JSON key, default
  `gentle`, decode throws on unknown tiers) decoded in MUContent; all
  six shipped regions set explicitly
  (`meadow`, `ridge` gentle; `fenlands`, `gorge` normal; `commons`,
  `delta` hard — the default menu region is gentle).
  `RivalDifficultyDecodingTests` locks the shipped tiers, the gentle
  default, and the unknown-tier failure.
- **`GentleRival` rewrite** (MUAI): tier-driven cadences, hard split
  action, falcon-avoidance standoff, forage/flee/roost behavior per tier.
- **Player-visible picker:** menu segmented control `menu.difficulty`
  (Shell), `GameModel` takes `rivalDifficulty` (falls back to the region
  default), `-uitest-difficulty <tier>` launch arg (PlayView),
  `debug.difficulty` overlay row (rival regions only).
- **UI tests (MUITests):** `testDifficultyPickerSelectsTier` (picker
  offers all three tiers; selecting Hard reaches the game and the rival
  flock is alive) and `testDifficultyLaunchArgument`
  (`-uitest-difficulty gentle` end to end).

Engine bugs found by the P4.1 tests and fixed, each with a regression
test:

1. **`splitFlock` used the whole-world bird count** to size the split,
   which emptied the rival flock (a sub-flock is a subset of the world).
   Now computed from the source flock's own count
   (`ReducerTests.testSplitFlockSizesFromSourceFlock`).
2. **R-13 tiebreak still carried the P3 `rivalBirds = 0` placeholder**,
   so a tied day always went to the player. Now counts live rival birds
   from `subFlockAssignments` (`RulesEngineTests` R-13 tiebreak cases).
3. **R-5 auto-merge collapsed the rival flock in rival mode** (flocks
   start coincident; the 30-tick proximity merge absorbed all 300 rival
   birds by tick 480 in the balance harness). `versusMergeSuppressed` is
   now set for rival mode as well (GameModel + sim harness;
   `testR5MergeRequires30TickProximity` updated).

**AI budget (G4 check, Release build):** `sim --balance normal --days 2
--regions meadow` reports `autoplayerNsPerTick=68, rivalNsPerTick=1756`
(≈ 0.068 µs and 1.76 µs per tick) — both far under the 0.5 ms/tick
budget. (The CSV header previously mislabeled the columns as µs; fixed to
ns.)

### P4.1 — Forage economy rework (2026-11-20, ADR-0029/0030)

The dusk flock still collapsed in the balance setup, so the forage
directive was reworked before the sweep could mean anything
(ADR-0029, ADR-0030 in `docs/DECISIONS.md`):

- **Commitment:** the autoplayer holds its current field while it is
  worth a trip, or — starving — while any food remains (finish the
  meal); the starve branch flies only for food a field holds now
  (≥ 150), never projected regrowth (nibbling a ramped crumb restarts
  its ramp and pins every field at a trickle).
- **Standoff:** deterministic grid scan — nearest point clearing all
  fields by radius+200 (was: centroid push-out that swung and dragged
  the flock across fields, grazing them); the directive reuses a
  still-clear point.
- **Condense by day (ADR-0030):** the autoplayer re-issues condense
  whenever the target holds and the 120-tick cooldown has lapsed; a
  parked cloud mills within ~200 units, so standoffMargin is 200.
- New RED→GREEN tests: starve standoff, crumb refusal, meal
  finishing, near standoff, day condense; `skipsRepath`/
  `holdsWhileFoodRemains` updated to the no-repath contract.
- MUAI 53/53, MUCore, MUContent all green.

**Diagnostics (temporary, uncommitted at this point):**
`TravelDiagnosticsAI` (MUAI) runs an AI day with `MU_AI=1` and a
parked-cloud probe without it; during the work its `applyAction`
results were discarded, which had invalidated earlier traces (fixed).
The fixed AI probe on the commons settles into a strip→park→strip
pulse holding ~850–1,200 birds with the bank cycling 0–600; the
dusk target (1,000–2,500) is close but not yet reliably met — the
remaining levers are the staggered rotation (never waiting at a far
standoff) and rival interaction, measured next with the real
`sim --balance` harness (which includes the rival; the probe does
not).

**Lint fix (2026-11-20, 501df5d):** the branch CI lint job failed with 11
violations in the new code; all fixed — `ForageScoring.directive` now takes
`flock: (x:y:birds:)` and `pilot: PilotPrior` (parameter count), `planHard`
takes a `leader` tuple, the two condense tests moved to
`AutoplayerCondenseTests`, over-long diagnostic lines split, alignments and
an empty enum argument fixed. MUAI 52/52, MUCore 99/99, MUContent 37/37,
`make lint` clean.

**G4 balance sweep (pending re-run):** `sim --balance <tier> --days 500` over all
six regions, output `docs/balance/<tier>.csv`. Targets: player win rate
≈ 85% gentle / 60% normal / 35% hard, dusk flock 1,000–2,500, falcon
losses 5–20% of peak. Results and the balance report to be recorded here
when the sweep completes.

**Boid leader brake (2026-11-20, 81580cd + 7318e7d, ADR-0031):** the
R-6 leader force was a constant-magnitude pull with no damping — an
undamped oscillator — so a parked flock pendulummed around the leader
point (worst centroid offset 135 units after 600 ticks) and the
balance sweep pinned at ~63–67% for every tier with no separation:
the flock never sat inside a field long enough to feed. The kernel
now brakes velocity near the leader point (`leaderBrakeRadius` 800,
`leaderBrakeQ` 0.5/tick at the point, ramping linearly to zero at the
edge). The flat first cut (81580cd) damped whole day-start trips to a
crawl (4–5 units/tick) and the day-start clouds merged on tick 29
before the pilots could separate them — diagnosed with a per-tick
separation dump (`MergeDiagnostics`, `MU_MERGE_DIAG=1`); the ramp
(7318e7d) restores cruise-speed transit and clears the merge window
at tick 26. `replayContentVersion` 8→10, goldens regenerated,
`testR6LeaderForceMatchesWeight`/`testR1WindDriftsFlockDownwind`/
`testUltraDenseOverflow` re-anchored, plus a new
`testFlockConvergesToStationaryLeader` regression (RED 135 → GREEN <80).
All packages green: MUCore 100/100, MUAI 53/53 (1 env-gated skip),
MUContent 37/37; `make lint` clean. `testVersusTwoFlockRouting`
failed once in the full gate re-run (pre-brake binary) and passes on
the new binary — treated as a timing flake, re-verified. CI on
81580cd: lint/build/ui-test jobs all pass; only the SPM `test` job
failed on the pre-ramp merge test (fixed by 7318e7d). Balance sweeps
re-running on the ramped binary.

**Hard-tier crash fixed (2026-11-20, 335fc3c):** the G4 hard-tier
balance sweep (500 days × 6 regions) crashed deterministically with
exit 133 (SIGTRAP, Swift runtime failure: Index out of range) in
`computeRoostClaims(state:)` called from `applyTick` — trap at
line 94 `state.roostClaims[roostIdx][majority] += 1`. Root cause: the
hard rival splits, minting a third sub-flock, but claim rows were
hard-sized `[0, 0]` at state creation (R-12). Gentle/normal never
split → no crash. The ramped-brake commit (7318e7d) un-starved the
flock, enabling the split path for the first time in the hard tier.
Fix: `Reducer.splitFlock` now appends a zero slot to every roost
claim row so the third sub-flock's dusk claim does not trap. Test:
`testR12ThirdFlockClaimsDoNotTrapAfterSplit` (RED → GREEN). Golden:
v10→v11 (20 replays re-anchored with wider claim rows). Verified:
`sim --balance hard --days 240 --regions commons` exits 0 (was
crash). All packages green: MUCore 101/101, MUAI 53/53, MUContent
37/37, MURender 12/12, MUAudio 1/1, MUPlatform 1/1; `make lint`
clean. CI green on 335fc3c. Balance sweep to be re-run.

**Energy model rework (2026-11-20, in progress):** the G4 sweep on
the ramped binary still showed every flock starving (energy cycling
0→X→0 all day, both sides at 0 through the 900-tick dusk; hard tier
61–100% player wins vs the 35% target). Two causes, both fixed
(ADR-0032): (1) the grazing rate was capped below the flight drain
— the field budget `richness*10` (~650) with 13/100-tick regrowth
bounds feed at ~3.7/tick vs a ~5/tick drain; (2) the drain applied
unconditionally though R-8 pins it "while in flight", so dusk
(900 ticks, no roost overlaps any field) burned every flock to the
bird-count tiebreak. Changes: field budget `richness*10`→`*20`
(GameState default), feed divisor 10→7 (Energy), and
`computeEnergyDrain` now skips the drain while the sub-flock
centroid sits within 2× a roost radius (per sub-flock, so a parked
straggler can't shelter a flying flock). `replayContentVersion`
11→12. Rule tests re-anchored to /7; new settled-drain regressions
both pass; the full suite waits on golden regeneration (sim
rebuild is sequenced behind the running balance sweep so the
running binary isn't swapped). G4 sweep (100 days × 6 regions × 3
tiers, with new `playerDusk`/`rivalDusk` columns for the
1,000–2,500 dusk-flock target) running; results and the remaining
tuning follow.

### P4.1 — G4 sweep rerun on the ownership-fixed engine, falcon stoop rework (2026-11-20/21)

**balg4 sweep results (100 days × 6 regions × 3 tiers, engine v13,
scratch `balg4_*.csv`):** player win rates gentle **75.7%**, normal
**85.0%**, hard **90.3%** (targets 85/60/35) — the difficulty ordering is
still inverted after ADR-0033. Rival dusk-flock medians: gentle 550,
normal 480, hard 424, against player medians 920/1085/1157 (player dusk
inside the 1,000–2,500 window for normal/hard; gentle a touch under).
Per-region player win rate: commons 56/68/72%, delta 67/76/91%, gorge
70/84/90%, ridge 77/91/93%, fenlands 84/91/96%, meadow 100/100/100%.
Every rival win comes from a 2-roost day against the player's 1 (rival
roosts med 2 on rival-win days); on tied-roost days the player wins
~78% on the bird-count tiebreak.

**Why stronger tiers play weaker:** the tier table's only effective day
levers are `standoffDistance` (640/520/380) and the flee cadence
(60/45/30). `forageInterval` is vestigial — `forageIfNeeded` re-decides
through `ForageScoring.directive` every tick and never reads it (the
pre-fix probe grid's identical forage rows confirmed it). A small
standoff makes the rival graze the player's fields (shared budget) and
fly more (the ADR-0032 drain applies in flight), so the hard rival
starves to ~0.47× the player, trips its own `playerBirds ≤ 2·rivalBirds`
contest guard, and stops claiming roosts entirely (rival roosts med 0).
The large standoff farms uncontested fields instead. The dusk-claim
gates, not the forage cadence, are the levers — retune planned as
ADR-0035 with `claimGate`/`contestRatio` as separate tunables.

**Falcon stoop rework (ADR-0034, contentVersion 14):** kills now land
within `diveRadius` of the falcon→target→2×diveRadius segment instead of
the dive point, the grab budget scales with the target flock's size
(`flockSize·8/1000`, density-throttled, floor 1), the forced-split check
runs against the path, and `diveResult` carries the kill count so the
sweep counts birds taken. `FalconStoopTests` (5 tests) added; the three
R-10 tests moved out of `RulesEngineTests`. MUCore full suite green
(131 tests, 0 failures, EXIT=0 at 00:55); sim tool rebuilds clean.

**ADR-0035 probe round 1 (2026-11-21, scratch `p2_*`, hard tier,
30 days × commons+meadow):** no dusk-tunable cell moves the win rate
toward the 35% target — commons stays 73–87% player wins across
`contestRatio` 2–6, standoff 380–640, splitmin 200–500; meadow stays
100% in every cell. Two structural findings: (1) `planHard`'s dusk split
is rejected by the ADR-0033 per-side cap whenever a falcon forcedSplit
already minted a second rival flock during the day — the dusk plan is
spent with neither flock routed, and the trace shows both rival flocks
contesting the SAME roost (`claim r0 sf1` → `claim r0 sf2` flips). Fixed:
planHard routes the two existing flocks to the two top roosts instead of
issuing a split that cannot apply (regression test
`testHardRoutesTwoExistingFlocksToTwoRoosts`). (2) The third leader in
`testVersusTwoFlockRouting` on CI is the same mechanism on the player
side — a legitimate ADR-0033 mint, not the subject of that test — so the
versus fixture now runs falcon-free via a new `-uitest-falcons` launch
override (`Region.withFalconCount`).

**Probe rounds 2–3 and the v15 trigger correction (2026-11-21
morning):** probe round 2 (gate cells) showed `--rival-gate` alone moves
normal little on commons (73.3 → 70.0%); gate 320 **plus standoff 640**
is the strong combination — commons normal drops to **63.3%** (the
rival out-grows the player, 836 vs 654, and wins bird-count tiebreaks).
Probe round 3 with the two-flock routing active moved hard from 73.3 to
**60.0%** on commons (ratio 3 + standoff 640). The falcon grab budget
probe (8/20/32/48 per 1,000) produced identical days — the stoop's
sparse-edge targeting means the corridor, not the budget, binds kills at
~5–11/day (~1–2% of peak); a 100-per-1,000 budget does diverge
(~291 kills on its probe day), so the 5–20% falcon-loss band is
reachable but only with a much larger budget — recorded in
docs/BALANCE.md as a corridor-vs-budget finding.

**The big round-1/2 surprise:** the v14 corridor-based forced-split
catchment (2× `diveRadius` around the whole stoop path) minted a second
flock on nearly every successful dive — the falcon preferentially
strikes the bigger flock, so on multi-roost maps the mints handed the
leading side extra roosts; gentle commons fell to 43.3% player wins
(rival roosts median 2.0). ADR-0035 tightens the R-10 trigger back to
the rule's intent — the stoop path must pass within `diveRadius` (30) of
the flock centroid ("a dive through the flock's core scatters it") —
`replayContentVersion` 15, goldens regenerated, MUCore 112/112 green
(f6d3049). The CI red on 130fc90 (lint: class-body length and a
`Data` conversion in the new tests; `testVersusTwoFlockRouting`'s third
leader) was fixed in a252b4e/adf2748; CI green on adf2748. MUAI 58/58.
Probe round 4 re-baselines all three tiers on v15 and tests
the remaining lever, a per-tier rival start scale (`--rival-start`
probe override added to the harness).

**Tier-table inversion found (2026-11-20, in progress):** the sweep's
 first two tiers finished and inverted the intended difficulty
ordering: gentle 57.3% player wins (target 85), normal 72.2%
(target 60). Event traces explain why: feeding is per-tick inside a
field radius, so the gentle rival's slow forage cadence (480 ticks)
makes it sit in fields longer and feed MORE (3-day trace: gentle
1,359 feeds → +5,758 birds grown vs normal 1,049 feeds → +2,621),
and its large standoff (640) lets it farm uncontested. Faster
cadence is weaker, not stronger. Flock collapse is fixed — dusk
medians are in/near the 1,000–2,500 window (commons 1,125; delta
2,444; meadow 1,562; fenlands 946; ridge 810; gorge 529). Action:
added `--rival-forage/-flee/-radius/-standoff` CLI overrides to the
sim balance harness (probe-only), and a 4×4 forage×standoff probe
grid on commons (30 days/cell) is running to re-derive the tier
table; hard tier still running. Tier table retune + balance report
will follow as ADR-0033, then golden regeneration (contentVersion
12) and the full suite.

**Root cause of the inversion: side-ownership bug (ADR-0033, fixed
2026-11-20):** the tier inversion was not an AI-parameter problem.
`forceSplit` (the R-10 falcon-dive response) reassigned every other
bird of the struck flock to `sf == 0 ? 1 : 0` — a dive on the player's
flock handed half the player's birds to the rival's flock (and vice
versa), and it desynced `subFlockAssignments` from `birds.subFlock`.
The rival's "second roost" bankings (22 of 30 days on commons) were
en-route claims from stolen player birds; the autoplayer's ≤37% win
rate against every probed rival config was the same theft. Fix:
explicit side ownership — `GameState.subFlockOwners` (0 = player,
1 = rival), a new `.spawnRival(ratio:)` action replacing the starter
split, `splitFlock` inheriting the source owner, a per-side cap (a
side may split only while it has exactly one flock), `forceSplit`
targeting the same side and updating both arrays, and the roost
tally + R-13 tiebreak counting by owner. `replayContentVersion`
12→13; goldens regenerated. New `VersusOwnershipTests` (7 tests);
R-12 rewritten for versus mode; R-13/solo fixtures given
owner-matched rows. Full suites green: MUCore 110/110, MUAI 53/53.
The balg4 balance sweep (100 days × 6 regions × 3 tiers) is running
on the fixed engine; the pre-fix numbers (gentle 57.3%, normal
72.2%) are superseded. The autoplayer's nearest-roost dusk strategy
is the remaining known weakness and a legitimate tuning target.

### P4.1 — Multi-flock rival economy: per-flock plans + sustainability split (2026-11-21, ADR-0035)

The 100-day sweep's hard tier exposed a structural AI gap: the
rival pilot only ever planned flock 1, so a split-off flock 2 had
no forage directive at all and starved via R-8 (zero energy kills
birdCount/100 per event); on two-field regions the side starved as
a whole. Fix (ADR-0035), three parts:

- **Per-flock forage plans.** Every rival flock plans its own
  forage via `ForageScoring`, with the other flocks' centroids and
  the player's leader point in its avoid set, so the flocks
  de-correlate instead of stacking on one field.
- **Dawn sustainability split.** A single rival flock of at least
  `sustainSplit` birds splits once per day at dawn (`.splitFlock`
  50/50), and the halves route to two *different* fields — growth
  becomes limited by the fields, not by the flock's own cohesion.
  Runs in daytime, where the dusk-split per-side cap has no say;
  once per day (`sustainSplitDone`).
- **Difficulty-scaled start share** (`RegionStarter.startScale`):
  gentle 1.0×, normal 1.25×, hard 1.5× of the region's
  `rivalStartBirds` (capped at 0.9 of birdCount) — a visible
  "outnumbered" cue and the main lever on tiebreak-heavy days.

Rival memory moved from scalars to per-flock dictionaries
(`lastTargetByFlock`, `lastForageTickByFlock`, `lastStandoffByFlock`)
with Codable migration for saves from earlier builds. New
`RivalSustainTests` (4 tests: fat-flock split fires at dawn, fires
once per day, small flocks don't split, split halves target
different fields). MUAI 65/65 green. `GentleRival.swift` split into
`GentleRival.swift` + `GentleRival+Sustain.swift` (extension) to
hold the 400-line body lint limit; swiftlint 0 violations.
Committed 6be18df on `murmur/phase/P4-ai-opponents`.

**G4 evidence sweep running:** `sim --balance <tier> --days 500`
over all six regions per tier (sim-v16, scratch g4-{tier}.csv),
three tiers in parallel. Gate math on completion: per-tier win
rates 85/60/35 ± band, dusk medians 1,000–2,500, falcon losses
5–20% of peak.
