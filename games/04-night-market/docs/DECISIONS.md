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

## ADR-0006: Edits never strand customers (R-14 generalized)

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** Every edit that makes a customer's tile untraversable (walkway erase, bridge move) relocates the customer to the nearest traversable tile with the walk reset (R-14 rule generalized); seat-seekers whose target seat becomes unreachable retarget to the exit.
- **Rationale:** The 500-night invariant sweep caught customers standing on open water after a bridge moved out from under them (INV-2). R-14 already mandated relocation for erases; extending it to bridge moves is the smallest consistent rule that keeps INV-2 true under arbitrary editing.
- **Consequences:** `Reducer.relocateStranded(off:in:)` is shared by erase and bridge-move paths; regression tests `r15BridgeMoveRelocatesStranded`, `r14SeatSeekerNotStranded`, `r14SeatWalkStaysTraversable`.

## ADR-0007: Replay ordering and checkpoint timing are canonical

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** Same-tick actions replay in the order: upgrade choice first, then pause/erase/paint/place/move/speed/resume (`Replay.actionOrderKey`). Checkpoint hashes are taken after the tick advance but before the boundary upgrade choice. Golden recordings contain only actions that actually applied.
- **Rationale:** The sim applies the boundary upgrade before that tick's player action; replaying in a different order changed outcomes (e.g. paints before a budget upgrade failed where the sim succeeded). Hashing before the choice keeps checkpoints comparable between sim and replay.
- **Consequences:** `Replay.run` applies pending actions both pre- and post-advance; ten committed golden replays reproduce final and checkpoint hashes bit-for-bit (0 skipped actions).

## ADR-0008: Map paint order and digest soundness

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** The default Taipei map paints plaza first, then canals (canals cut through the plaza). `StateHash.digest` hashes `walkwayTiles` in sorted order, and no engine or policy code lets `Set` iteration order reach the RNG.
- **Rationale:** The plaza loop silently overwrote the row-12 canal (only row 7 existed), which the bridge-move test caught. Swift's per-process `Hasher` seed makes unsorted Set iteration differ between processes, which broke Debug/Release hash parity until the erase policy sorted its candidates.
- **Consequences:** Both canals (rows 7 and 12, cols 14–16) exist; Debug and Release sims produce identical hashes for the same seed; digest regression test `digestCoversWalkways`.

## ADR-0009: Launch-argument-driven UI tests and the harness data view

- **Date:** 2026-11-15
- **Status:** accepted
- **Summary:** G2 UI checks drive the app with `-uitest-*` launch arguments (fast, fresh, paused, stress, autochoose, autosave, save-restart, autolane, debug, shot) and assert through the debug overlay's accessibility rows; map painting goes through real touch synthesis into `MapInputCatcher`. The save/resume check reloads the save in-process (`-uitest-save-restart`), and `SaveData` carries the save-time hash so resume can verify the restore. On Mac, `-uitest-shot <path>` writes an in-app window snapshot for evidence.
- **Rationale:** Three harness facts forced this: the headless iPad simulator cannot rotate its display while XCUITest's touch space stays portrait, so every SwiftUI button tap mistranslates and never fires (probe counter proof); each `XCUIApplication` launch observes an empty data container, so a relaunch cannot read a previous launch's save; and the Mac UI-test runner cannot enable automation mode on this build machine (issue #6). The StateHash includes `isPaused`, so the save must be taken while paused for the resumed hash to equal the saved hash.
- **Consequences:** UI-test affordances are inert without their launch arguments; the debug overlay doubles as the assertion surface; cross-launch save restore is verified manually via `simctl launch` (tick and hash restore exactly); real mouse/keyboard input remains tested on Mac only when automation is granted.
