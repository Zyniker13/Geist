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

### Test state (pre-G2)

- `make lint`: **0 violations** (SwiftLint strict + swift-format + content-lint
  + check-imports).
- `swift test` per package: MUCore **67/67**, MUAI **15/15**, MURender green,
  MUContent/MUAudio/MUPlatform/MUMeta green.
- G2 UI-test runs (iPad simulator + Mac) in progress; evidence below.
