# Orrery — Decisions (ADRs)

## ADR-0001: Toolchain

- **Date:** 2026-11-23
- **Status:** accepted
- **Summary:** Xcode 27.2 (Build 27B52), Swift 6.4.2, iOS/iPadOS/macOS deployment targets 26.0.
- **Rationale:** `_CONVENTIONS.md` §2 fixes the stack; versions recorded for reproducibility.

## ADR-0002: Stack

- **Date:** 2026-11-23
- **Status:** accepted
- **Summary:** Swift 6 strict concurrency; SwiftUI app shell (one app target per platform from one shared source set); SwiftPM packages ORCore ← ORContent ← ORAI ← ORMeta ← ORRender/ORAudio/ORPlatform ← App; XcodeGen for the project; SwiftLint + swift-format.
- **Rationale:** Per `_CONVENTIONS.md` §2–§3; proven in Night Market and Murmuration.

## ADR-0003: RealityKit plus schematic fallback

- **Date:** 2026-11-23
- **Status:** accepted (roadmap §2 decision, restated here as the render ADR)
- **Summary:** The primary 3D view is RealityKit `RealityView` with procedurally generated ring meshes; the accessible/low-power view is the SpriteKit `SchematicScene`.
- **Rationale:** Roadmap §2 names this pairing; SceneKit is not used.

## ADR-0004: Angular unit of 1/48 turn

- **Date:** 2026-11-23
- **Status:** accepted (roadmap §2 decision)
- **Summary:** All rules math uses `Angle48` (Int in 0…47). Rendering converts to radians only at the edge.
- **Rationale:** Integer-only deterministic rules math (§4.2); 48 divides evenly by all four Standard slot counts (8, 12, 16, 24).

## ADR-0005: Zobrist keys from a fixed seed, committed as a table

- **Date:** 2026-11-23
- **Status:** accepted (roadmap §2 decision; table arrives in P1)
- **Summary:** Zobrist random keys are generated once from a fixed seed and committed as a table file, not regenerated at runtime.
- **Rationale:** Hash values must be identical across machines and rebuilds.
