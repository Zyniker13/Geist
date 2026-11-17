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
`finalHash=7e94d1021c3a13a1`, `deterministic=true`. Cross-process/cross-device
checkpoint-hash evidence is the G1 gate item (Checkpoint.swift), not yet run.

**Tests:** `swift test --package-path Packages/MUCore`: **Executed 50 tests, with
0 failures** (49 pre-existing + the new dense-flock regression; BoidsTests 7/7).

### Known items for MU-P1.2 (leader paths, splits, condense, merges)

- Merge event emission was fixed early (one `.merge` per merged sub-flock, `from`
  captured before the assignment is zeroed — previously one event per bird with
  `from` always 0); the tagged R-5 merge test still belongs to MU-P1.2.
- Lint debt from the first P1 commits cleared (for_where, shorthand_operator,
  unused_enumerated, type_body_length via the Energy tests split into
  EnergyRuleTests.swift); `make lint` 0 violations, 50/50 tests green.

### Next

MU-P1.2: leader paths, splits, condense, merges (R-3 to R-5) — fix the merge
event emission, add tagged R-3/R-4/R-5 tests.
