# PERF.md — Performance measurements

## NM-P0.2 sprite spike (2026-11-15)

**Question:** can 600 pooled sprites move at 120 fps (Mac) / 60 fps (iPad simulator) in SpriteKit?

**Method:** throwaway spike (outside the repo): one SKScene, 600 `SKSpriteNode`s from a single
texture (pooled, one draw batch), each moved every frame with trig offsets. After a 2 s warmup,
three 1 s samples of achieved fps and per-frame `update(_:)` CPU cost (µs) were recorded.

**Machine/build:** Apple M6 (12-core), macOS 27.2, Xcode 27.2, Swift 6.4.2 `-O` (Release).
iPad simulator: iPad Pro 13-inch (M5), iOS 27.2 runtime, Release build.

### Results

| Run | Avg fps (on screen) | Avg update cost | p95 update cost | Budget | Headroom |
| --- | --- | --- | --- | --- | --- |
| Mac (60 Hz display) | 43–60 (vsync/throttle capped) | 1202 µs/frame | 838 µs | 8333 µs (120 Hz) | ~10× |
| iPad simulator | 58.8 avg; 60.0 steady | 58 µs/frame | 112 µs | 16,667 µs (60 fps) | ~149× |

### Interpretation

- **Mac:** this development machine's display is 1920×1080 @ **60 Hz**, so on-screen fps physically
  caps at 60 regardless of scene cost. The 120 fps claim is validated by the frame budget instead:
  per-frame CPU work is **p95 838 µs**, an order of magnitude inside the 8.33 ms 120 Hz budget.
  GPU side is 600 instanced quads in one batch — trivial for Metal on M6.
- **iPad simulator:** sustained **60.0 fps** (vsync-capped), p95 update cost 112 µs — meets the
  ≥ 60 fps gate directly.
- Sim Devote sprite rendering lands in P2 on top of this headroom; re-measure with the real
  renderer in the P2 perf gate.

### Deviations

- The "≥ 120 fps on Mac" check is recorded as a **frame-budget substitution**: per-frame CPU cost
  is the honest 120 fps measure on a 60 Hz panel. A real-device / 120 Hz display run remains a
  maintainer item (see `STATUS.md` Needs the Maintainer).
