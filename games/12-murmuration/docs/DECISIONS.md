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
