# 02 — Orrery Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 02 · `orrery` |
| Code prefix | `OR` (packages `ORCore`, `ORContent`, `ORAI`, `ORRender`, `ORAudio`, `ORPlatform`, `ORMeta`) |
| Bundle ID (placeholder) | `com.zyniker.orrery` |
| Subgenre | Two-player abstract strategy |
| Difficulty tier | Approachable to learn, deep to master |
| Scope | Solo-indie |
| Session length | 5–15 minutes |
| Renderer | RealityKit (3D brass orrery) with a SpriteKit 2D "schematic" fallback view |
| Players | Solo vs AI; local pass-and-play; async online via GameKit turn-based matches |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** A two-player abstract on brass rings that turn like planetary orbits; line up three of your planets and the eclipse captures everything between.
- **Summary:** Four concentric rings rotate around a sun at different speeds. Players place planets into ring slots or nudge rings. When three or more of your planets fall on one line through the sun, enemy planets lying between them on that line are eclipsed and captured. You plan for where the rings will be, not where they are.
- **Pillars:**
  1. **Perfect information, no luck.** All randomness is in variant selection before the game starts.
  2. **Time is the board.** The core skill is predicting rotation; the UI must make the future visible on demand.
  3. **Learn in one minute.** Two actions, one capture rule, one instant-win rule.
  4. **An object you want to touch.** The orrery should feel like a heavy, precise brass instrument.
- **Aesthetic spec:**
  - Palette: brass `#B5893B`, brass highlight `#E6C77A`, walnut `#4A2F1D`, cobalt enamel `#1F3E8C` (Player 1), ivory enamel `#EDE6D3` (Player 2), sun `#F2A93B`, background velvet `#151318`.
  - Materials: physically based brass with fine machining anisotropy; enamel planets with glass clear-coat; walnut base.
  - Camera: three-quarter macro view with shallow depth of field; top-down schematic view toggle.
  - Motion: rings rotate with eased mechanical inertia (300 ms) and a tiny overshoot; captured planets drop into a velvet tray.
  - Audio: clockwork ticking that speeds up as the game nears its end, glass chimes for placement (pitch by ring), a low gong for eclipses, and a sparse celesta theme.
  - Haptics: detent clicks while scrubbing ring rotation; a heavy pulse on eclipse.
- **Inspirations:** Polytopia's legibility-first art, Into the Breach and Hoplite's perfect-information puzzles, Spelunky-style daily seeds, and Game Center challenges in the Apple Games app.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Renderer:** RealityKit `RealityView` scene with procedural ring meshes (generated in code, no external 3D files needed for v1) and a Metal-free material setup (`PhysicallyBasedMaterial`). The 2D `SchematicScene` (SpriteKit) is required in P2 as the accessible and low-power view.
- **Turn-based:** No tick simulation. Animations replay `[Event]`.
- **Search:** Alpha-beta with Zobrist hashing in `ORAI`; integer evaluation.
- ADRs: ADR-0003 (RealityKit plus schematic fallback), ADR-0004 (angular unit of 1/48 turn), ADR-0005 (Zobrist keys generated from a fixed seed and committed as a table).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/ORCore/Sources/ORCore/
  Model/ Angle48.swift, Ring.swift, Planet.swift, Board.swift, Variant.swift, GameState.swift, Action.swift, Event.swift
  Rules/ Reducer.swift, Rotation.swift, Alignment.swift, Capture.swift, NudgeKo.swift, Victory.swift, LegalMoves.swift
  Hashing/ Zobrist.swift, StateHash.swift
Packages/ORContent/Sources/ORContent/ VariantCatalog.swift, PuzzleCatalog.swift, Validation.swift
Packages/ORAI/Sources/ORAI/ Evaluator.swift, AlphaBeta.swift, TranspositionTable.swift, MoveOrdering.swift, PuzzleSolver.swift, PuzzleGenerator.swift
Packages/ORRender/Sources/ORRender/ OrreryView.swift (RealityView), RingMesh.swift, PlanetEntity.swift, SchematicScene.swift, FuturePreview.swift, LineHighlight.swift
Packages/ORAudio/Sources/ORAudio/ Clockwork.swift, Chimes.swift, Music.swift
Packages/ORPlatform/Sources/ORPlatform/ GameCenterService.swift, TurnBasedService.swift, CloudSave.swift, Haptics.swift
Packages/ORMeta/Sources/ORMeta/ DailyPuzzle.swift, Ladder.swift (AI ladder), Stats.swift
Resources/Content/ variants.json, puzzles_seed.json, balance.json, tutorial.json, achievements.json
```

## 4. Core Rules Specification

**Board**
- R-1 Angles are integers mod 48 (`Angle48`). Four rings, indexed 1 (inner) to 4 (outer).
- R-2 Standard variant slot counts: ring 1 = 8 slots (every 6 units), ring 2 = 12 (every 4), ring 3 = 16 (every 3), ring 4 = 24 (every 2). Slot `k` of ring `i` sits at angle `(offset_i + k × 48 / slots_i) mod 48`.
- R-3 Each ring has an `offset` (initially 0 in Standard) and a `speed` in angle units per round: Standard speeds ring 1 = +12, ring 2 = +8, ring 3 = −3, ring 4 = +2 (negative = counter-rotation).
- R-4 Each player starts with 10 planets in reserve. Player 1 (cobalt) moves first.

**Turn**
- R-5 On a turn the player takes exactly one action: `place(ring, slot)` into an empty slot from reserve, or `nudge(ring, ±1 slot)` which immediately rotates that ring by one slot step (changes `offset` by `±48/slots_i`).
- R-6 Nudge ko: a player may not nudge the ring the opponent nudged on the immediately preceding turn in the opposite direction (prevents undo loops). A player may not nudge two turns in a row (they must place in between) unless their reserve is empty.
- R-7 After both players have taken a turn (one round), all rings rotate by their speed (`offset += speed`).
- R-8 If a player has no legal action, they pass.

**Lines, Alignment, and Capture**
- R-9 A line is an unordered pair of opposite angles `{a, a+24}` for `a` in 0…23.
- R-10 A planet's signed position on line `{a, a+24}` is `+ring` if its angle is `a`, `−ring` if its angle is `a+24`.
- R-11 An alignment for player P exists on a line when ≥ 3 of P's planets lie on it.
- R-12 Capture: for an alignment with signed positions S, every enemy planet on that line with signed position strictly between `min(S)` and `max(S)` is captured (removed from the game and counted for P).
- R-13 Alignment checks happen (a) after every action, for the acting player only, and (b) after the round rotation (R-7), for the player who moves next first, then the other player, each using the board state after the previous player's captures.
- R-14 Grand Alignment: if a player has one planet on each of the 4 rings on the same angle `a` (same ray, not the opposite side), that player wins immediately (checked whenever alignments are checked, before captures).

**Victory**
- R-15 A player who captures 5 enemy planets wins.
- R-16 The game ends after 20 rounds; the player with more planets on the board wins; tie → more captures; tie → Player 2 wins (compensates first-move advantage; verify in sims).
- R-17 A player with no planets on the board and none in reserve loses.

**Invariants**
- INV-1 Each slot holds at most one planet; planets in reserve + on board + captured = 10 per player.
- INV-2 Ring offsets stay in 0…47 after normalization.
- INV-3 Captures only remove the opponent's planets.
- INV-4 Replay determinism (same seed and actions → same hash).
- INV-5 Alpha-beta at depth d returns the same best move as plain minimax at depth d on 500 random positions (d ≤ 3).

## 5. Data Schemas and Content Tables

```swift
struct RingState: Codable, Hashable { var slots: Int; var offset: Int; var speed: Int; var occupants: [Int: PlayerID] } // slot → owner
struct GameState: Codable, Hashable, Sendable {
  var rings: [RingState]   // 4
  var reserve: [PlayerID: Int]; var captured: [PlayerID: Int]
  var toMove: PlayerID; var round: Int; var turnInRound: Int
  var lastNudge: (player: PlayerID, ring: Int, dir: Int)?; var variantID: String
}
enum Action: Codable { case place(ring: Int, slot: Int), nudge(ring: Int, dir: Int), pass }
enum Event: Codable { case placed(PlayerID, Int, Int), nudged(Int, Int), rotated([Int]), aligned(PlayerID, line: Int, planets: [PlanetRef]), captured([PlanetRef]), grandAlignment(PlayerID), gameOver(PlayerID?, reason: String) }
```

`variants.json` (8 variants by G3, 16 by G5):
```json
{ "id": "standard", "name": "Standard", "rings": [ {"slots": 8, "speed": 12}, {"slots": 12, "speed": 8}, {"slots": 16, "speed": -3}, {"slots": 24, "speed": 2} ], "reserve": 10, "maxRounds": 20, "capturesToWin": 5 }
```
Required variant families: Standard, Retrograde (two counter-rotating rings), Still Outer (ring 4 speed 0), Quickening (speeds increase every 5 rounds), Five Rings (adds ring 5 with 48 slots), Binary Suns (two lines per angle offset by 12; captures on both), Small Orrery (3 rings, 7 planets, 12 rounds), Seeded (speeds drawn from allowed sets by seed).

`puzzles_seed.json` (60 hand-verified puzzles by G5): `{ "id", "variant", "position": GameState, "solutionPlies": 3, "solution": [Action], "rating": 1200 }`.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `reserve` | 10 | 7–12 |
| `maxRounds` | 20 | 12–30 |
| `capturesToWin` | 5 | 3–7 |
| `ringSpeeds` | 12, 8, −3, 2 | per variant |
| `tieBreakFavorsP2` | true | bool |

Targets (Hard vs Hard, 2,000 games per variant): first-player win rate 48–52% (adjust tie-break or reserve per variant); median length 12–18 rounds; Grand Alignment ≤ 10% of wins; captures-to-win victories 35–60%.

## 7. AI Approach

- **Search:** negamax alpha-beta, iterative deepening, Zobrist transposition table (2^20 entries), killer moves and history heuristic, move ordering: captures-creating moves first.
- **Evaluation (integers):** captures × 1000; planets on board × 120; potential alignments next rotation (2-of-3 on a future line) × 60; threatened own planets × −80; Grand Alignment threats × 400; reserve parity × 10.
- **Tiers:** Pupil (depth 1, 30% random among moves within 150 points); Apprentice (depth 3); Astronomer (depth 6 or 0.8 s); Astrologer Royal (depth 10 or 2.0 s, wider table). All deterministic for a given node budget.
- **Puzzle generator:** sample random mid-game positions from Hard-vs-Hard sims, search for a forced capture-or-win in N plies (N = 1, 3, 5) where the solution is unique at the first ply; verify with the solver at depth N+2; rate difficulty by node count.
- **Daily puzzle:** seed `hash("OR-daily-" + yyyyMMdd UTC)` picks from a generated pool deterministically (the generator runs at build time to produce `puzzles_daily.json` with 400 days; the runtime only indexes). Daily match: vs Astronomer on a seeded variant.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.
- OR-P0.1 `Angle48` type with arithmetic and tests. Acceptance: wraparound tests for ±1…±96.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- OR-P1.1 Rotation and slot-angle math (R-1 to R-3, R-7).
- OR-P1.2 Actions, ko, and pass (R-5, R-6, R-8).
- OR-P1.3 Alignment, capture, ordering, and Grand Alignment (R-9 to R-14) with ≥ 30 hand-built test positions including opposite-side lines and simultaneous post-rotation alignments.
- OR-P1.4 Victory (R-15 to R-17) and Zobrist hashing.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-17 tagged tests pass; INV-1…INV-4 over 5,000 seeds
  [ ] ORCore coverage ≥ 90%
  [ ] make sim N=5000 random games: 0 crashes; identical hashes on two runs; median game < 2 ms CPU
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- OR-P2.1 `SchematicScene` (2D top-down) fully playable: tap a slot to place; drag a ring to nudge (snaps to slot steps).
- OR-P2.2 Future preview: drag a time scrubber (or two-finger twist on the board) to show ring positions 1–3 rounds ahead as ghosted planets; lines that would align glow.
- OR-P2.3 RealityKit `OrreryView` prototype with procedural ring meshes and placeholder materials, same input mapping via raycasts; toggle between 3D and schematic.
- OR-P2.4 Opponent: Apprentice (depth 3) AI.
- OR-P2.5 Mac: click to place, drag to nudge, scroll wheel scrubs future preview.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a full game vs Apprentice in schematic and 3D views on iPad and Mac
  [ ] Future preview matches Core's simulated positions for 1–3 rounds (test compares rendered slot angles to Core)
  [ ] Resume mid-game to identical hash
Sign-off: REVIEW: GROK + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- OR-P3.1 Eight variants (§5) with variant select and a rules card per variant.
- OR-P3.2 Tutorial: 6 interactive lessons (place, rotate, line, capture, opposite-side capture, Grand Alignment) from `tutorial.json`.
- OR-P3.3 Pass-and-play with optional board rotation per player on iPad.
- OR-P3.4 Move history with undo in casual mode (disabled in ranked/daily).

```
GATE G3 — Content and Systems
Checks:
  [ ] 8 variants pass content-lint and 1,000-game sims each
  [ ] Tutorial UI test passes
Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- OR-P4.1 Full alpha-beta with TT, ordering, and iterative deepening; four tiers.
- OR-P4.2 Puzzle solver and generator (`Tools/sim puzzles --count 500`).
- OR-P4.3 Balance report per variant in `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] INV-5 passes; each tier beats the tier below ≥ 75% over 500 games
  [ ] Astronomer p95 ≤ 0.8 s and Astrologer Royal p95 ≤ 2.0 s (Mac measured, iPad simulator reported)
  [ ] First-player win rate within 48–52% on Standard (or ADR with tuning)
  [ ] Generator yields ≥ 400 unique-solution puzzles across N = 1, 3, 5
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- OR-P5.1 Daily puzzle and daily match with local history and streaks.
- OR-P5.2 AI ladder: 12 named opponents with escalating tiers and variants; beating one unlocks the next and a cosmetic (enamel color).
- OR-P5.3 Eight more variants (16 total); seeded variant mode.
- OR-P5.4 Stats and 24 achievements in `achievements.json`.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily content identical across devices for 30 simulated dates; 400 days precomputed
  [ ] 16 variants pass sims; ladder completes in a scripted UI test with a debug "auto-win" flag
  [ ] Coverage thresholds met; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- OR-P6.1 Final PBR brass, enamel, and walnut materials; depth of field; image-based lighting.
- OR-P6.2 Mechanical motion curves; capture tray animation.
- OR-P6.3 Clockwork, chime, and celesta audio; ring-pitch mapping.

```
GATE G6 — Aesthetics
Checks:
  [ ] 3D view hits 120 fps on iPad Pro M4 with DOF on; 60 fps on iPad (A16) with DOF auto-reduced
  [ ] Snapshot set approved
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- OR-P7.1 Game Center: leaderboards (Daily puzzle time, Daily match score, Ladder progress), 24 achievements, daily challenge.
- OR-P7.2 Turn-based async matches with variant choice.
- OR-P7.3 iCloud sync of profile, ladder, and in-progress games.
- OR-P7.4 Mac menus and shortcuts (⌘Z undo in casual, ⌘1/⌘2 view toggle, arrow keys scrub time); small default window 900×700.
- OR-P7.5 Pencil hover shows the slot under the tip and a future-angle readout; squeeze toggles the future preview.

```
GATE G7 — Platform
Checks:
  [ ] Async match between two sandbox accounts completes
  [ ] iCloud round-trip iPad ↔ Mac
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- OR-P8.1 VoiceOver: slots announced as "Ring 2, angle 3 o'clock, empty"; rotor for lines with 2 of your planets.
- OR-P8.2 Players distinguished by shape (cobalt round, ivory faceted) as well as color.
- OR-P8.3 Reduce Motion: instant rotations with a cross-fade.

```
GATE G8 — Polish
Checks:
  [ ] Performance budgets (§7 of conventions); cold start < 2.0 s
  [ ] VoiceOver game completion UI test passes
Sign-off: REVIEW: GROK + REVIEW: MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard P9 and P10 tasks. OR-P9.1 puzzle difficulty re-rating from beta solve times.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2 issues
Sign-off: REVIEW: MAHLER
GATE G10 — Release
Checks:
  [ ] Store assets approved; final CI green
Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: R-13 ordering of post-rotation alignments; Zobrist table must be regenerated if state layout changes.
- First pickups: CLAUDE — RealityKit performance and materials; GROK — variant balance and puzzle curation.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| First-player advantage | Medium | High | Tie-break, reserve tweaks, and sims per variant | GROK |
| Rotation hard to visualize | High | High | Future scrubber, glow lines, and tutorial | GLM |
| 3D view hurts battery | Medium | Medium | Schematic view default on Low Power Mode | CLAUDE |
| Solved by strong engines | Low | Low | Variants and seeded speeds | GROK |

## 11. Out of Scope

Real-time mode; more than 2 players; online chat; physical-product tie-ins; Vision Pro build (consider post-launch).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 4–6 |
| P2 | GLM | 6–9 |
| P3 | GLM | 4–6 |
| P4 | GLM | 6–9 |
| P5 | GLM | 5–7 |
| P6 | GROK + CLAUDE | 8–12 |
| P7 | CLAUDE | 5–8 |
| P8 | CLAUDE | 4–6 |
| P9 | GROK + CLAUDE | 5–8 |
| P10 | CLAUDE + GROK | 2–3 |
| **Total** | | **51–76** |

## 13. Open Questions for Mahler

1. Should the 3D view or the schematic view be the default? Default: 3D on iPad Pro and Mac, schematic elsewhere.
2. Should Vision Pro be considered? Default: out of scope for v1.
