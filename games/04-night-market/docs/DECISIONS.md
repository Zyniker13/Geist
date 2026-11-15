# Night Market — Decisions (ADRs)

## ADR-0001: Xoshiro256** PRNG

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** Use Xoshiro256** seeded via SplitMix64 for all randomness in Core, Content, and AI.
- **Rationale:** Deterministic, replayable, and fast enough for real-time simulation.
- **Consequences:** SystemRandomNumberGenerator, Int.random(in:), Date(), and UUID() are banned in Core/Content/AI.

## ADR-0002: Fixed-Point Math

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** Use Q32.32 fixed-point (Int64 backing) for all rules math.
- **Rationale:** Deterministic across platforms and architectures; no floating-point drift.
- **Consequences:** All rules use Fixed; Float/Double banned in Core except debug formatting.

## ADR-0003: Immutable GameState

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** GameState is an immutable struct (Codable, Equatable, Hashable, Sendable).
- **Rationale:** Pure reducer pattern enables deterministic replay and thread safety.
- **Consequences:** Every state change creates a new GameState instance.

## ADR-0004: App targets consume SwiftPM package products

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** XcodeGen app targets (`NM`, `NM-macOS`) declare `dependencies: [- package: <Pkg>]` on all seven packages instead of compiling package sources into the app targets.
- **Rationale:** Cross-package `import` statements fail when sources are compiled into a single target; product dependencies give real module boundaries and match the `swift test` per-package gate layout.
- **Consequences:** `Config/Bundle.xcconfig` is attached per target via XcodeGen `configFiles` (project-level `options.configFiles` did not emit base-configuration references in XcodeGen 2.46.0). `PRODUCT_BUNDLE_IDENTIFIER` resolves through `$(GEIST_BUNDLE_ID)` from that xcconfig.

## ADR-0005: Formatting and lint tool interplay

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** `swift-format` (604.0.0) is the canonical formatter; its output defines style. SwiftLint runs `--strict` with rules disabled where they contradict the formatter (`trailing_comma`) or fight game-math code (`identifier_name`, `large_tuple`, `cyclomatic_complexity`, `function_body_length`).
- **Rationale:** The formatter re-adds trailing commas to multiline literals on every `format --in-place` run, so SwiftLint's opposite rule would fail permanently; hex constants in fixed-point code are unreadable when force-grouped.
- **Consequences:** Run `swift-format lint` (clean) and `swiftlint --strict` (clean) as separate gates; never "fix" formatter output by hand.
