# Murmuration — Decision Log

Architecture decision records. Every deviation from the roadmap is recorded here.

## ADR-0001 — Toolchain

- **Status:** Accepted (P0)
- **Context:** Per `_CONVENTIONS.md` §2, the program builds with Xcode 27.2, Swift 6.0,
  and 26.0 deployment targets for both app targets. Project generation is XcodeGen;
  linting is SwiftLint (`--strict`) plus swift-format.
- **Decision:** Murmuration uses Xcode 27.2 / Swift 6.0 / iOS 26.0 + macOS 26.0
  deployment targets; SwiftPM packages declare their own lower floors (.iOS(.v17) /
  .macOS(.v14)) so `swift test` works on the host toolchain.
- **Consequences:** The app targets and CI build with the 26.0 floor; package tests run
  on the host SDK. No third-party dependencies are permitted beyond the allow-list.

## ADR-0002 — Stack

- **Status:** Accepted (P0)
- **Context:** Roadmap §2 fixes the simulation and rendering approach for Murmuration.
- **Decision:** CPU simulation with a fixed 30 Hz tick using fixed-point boids —
  `Int32` world-unit positions, Q16.16 `Int32` velocities, uniform spatial hash with
  deterministic (ID-ascending per cell) iteration. Rendering is Metal instanced quads
  hosted in SwiftUI (no SpriteKit), interpolating between ticks at 120 Hz. The GPU
  never feeds back into gameplay, preserving determinism (INV-3). Bird cap 3,000 per
  flock (ADR per roadmap; two flocks max 4,000 total).
- **Consequences:** All rules math is integer-only (`Int`, Q32.32 `Fixed`, Q16.16
  velocity lanes); `Float`/`Double` are confined to debug formatting and tools.
  Boid spawn sequences must also be integer-deterministic once golden replays are
  cross-device (P1 replaces the P0 spike's tool-side Double trig spawn with integer
  math or moves it into Core).

## ADR-0003 — World-edge avoidance force

- **Status:** Accepted (P0)
- **Context:** R-6 lists obstacle avoidance among the per-tick forces but the world
  border behavior is unspecified. Probes of the kernel without any edge force showed
  birds pinning to walls and streaming along the perimeter (positions pinned at
  [0,2047]×[0,1535] from tick ~25), forming a perimeter vortex; the flock centroid
  then drifts away from any leader point and the flock is uncontrollable — leader
  paths (R-3) would fail for the same reason.
- **Decision:** Each bird inside a 64-unit margin of a world edge receives an inward
  unit force scaled by `edgeWeight` (default 1.0, one per violated edge; corners get
  two). Fields `edgeMargin`/`edgeWeight` live on `BoidsParams` and move to
  `balance.json` with the other weights.
- **Consequences:** Deterministic and integer-only (no trig, no division). Tunable at
  the P8 balance pass. Obstacle polygons (cliffs, towers) will reuse the same
  pattern in P1/P3.

## ADR-0004 — Min-speed floor is a cruise floor, not a hard clamp

- **Status:** Accepted (P0)
- **Context:** The roadmap clamps speed to `[minSpeed, maxSpeed]` (R-6). Enforcing the
  minimum as a hard post-integration clamp re-inflates the velocity magnitude along
  its current direction every tick. When the net force decelerates a bird (e.g.,
  leader + edge forces opposing an into-wall velocity), the magnitude never reaches
  zero, so the direction can never reverse: birds deadlock permanently (single-bird
  probe: pinned at the wall with v=(+18,0) for 250+ ticks). A static leader point can
  also never "park" the flock: birds cannot fly slower than 18 units/tick, so they
  orbit it.
- **Decision:** The maximum speed stays a hard clamp on every tick. The minimum speed
  is enforced only when the net force is not decelerating the bird
  (`dot(force, velocity) ≥ 0`); while decelerating, the speed may dip below
  `minSpeed` so the direction can reverse, and the floor reasserts once the turn
  completes. Gameplay steering uses moving leader paths (R-3/R-4), never parked
  points, so the orbit equilibrium is the intended resting behavior.
- **Consequences:** `testSpeedsStayClamped` asserts the exact invariant: max always;
  min unless the tick's Δv decelerates the bird (`dot(v_t − v_{t−1}, v_t) < 0`).
  Emergent balance questions (orbit radius, flock cohesion at game densities, speed
  saturation) are tracked in `docs/OPEN_QUESTIONS.md` for the P8 balance pass.

## ADR-0005 — Exact-direction integer rescale semantics

- **Status:** Accepted (P0)
- **Context:** `isqrt64` floors the true magnitude, so `x·t/magnitude` with a floored
  divisor scales components UP (max-speed overshoot), while per-component floor
  division scales the magnitude DOWN (min-speed undershoot). Both violations were
  observed (4,860 and 89 test failures; plus an Int64 overflow trap in the spike at
  ticks ≥ 223 when velocity hit the Int32 clamp).
- **Decision:** Min-speed branch: divide each component away from zero
  (`(|v|·t + m − 1)/m`, sign preserved) over the floored magnitude — result magnitude
  ≥ target, mathematically guaranteed. Max-speed branch: floor-division over a
  CEILING magnitude (`m = isqrt(speed2)`, +1 if `m² < speed2`) — result magnitude
  ≤ target, mathematically guaranteed. All integer, deterministic (INV-3).
- **Consequences:** The clamp invariant holds exactly (±2 tolerance is now slack, not
  necessity). Spike 4000×300 completes with a stable final hash.
