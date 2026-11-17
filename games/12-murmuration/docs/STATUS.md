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
- Xcode test leg (`make test` scheme MU on the iPad simulator): **pending** — a
  foreign profile's xcodebuild holds the shared build service; the run is chained
  behind it and this file will be updated with the result before the gate tag.

### Corrections to the scaffold record

- The scaffold doc named packages `MM*`; the actual packages are `MU*`
  (MUCore, MUContent, MUAI, MURender, MUAudio, MUPlatform, MUMeta).
- Bundle placeholder is `$(GEIST_BUNDLE_ID)` via `Config/Bundle.xcconfig`.

### Sign-off

Pending: Xcode test leg + merge to `main` + tag `murmur/gate-G0-pass`.
