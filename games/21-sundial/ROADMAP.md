# 21 — Sundial Roadmap

> An abstract where a sun crosses the board each turn, and the shadows your stone pillars cast capture whatever they fall across.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Sundial.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 21 · `sundial` |
| Code prefix | `SDL` (packages `SDLCore`, `SDLContent`, `SDLAI`, `SDLRender`, `SDLAudio`, `SDLPlatform`, `SDLMeta`) |
| Bundle ID (placeholder) | `com.zyniker.sundial` |
| Subgenre | Two-player abstract strategy (perfect information, no luck) |
| Difficulty tier | Deep |
| Scope | Solo-indie |
| Session length | 10–20 min |
| Renderer | RealityKit (3D limestone board with a directional sun light) plus a SpriteKit 2D schematic view; both read the same Core shadow map |
| Players | Solo vs AI (5 tiers), local pass-and-play, async online via GameKit turn-based matches (perfect information, so no commit scheme needed) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** An abstract where a sun crosses the board each turn, and the shadows your stone pillars cast capture whatever they fall across.

**Summary:** Two players, Dawn and Dusk, build limestone pillars of height 1–3 on a 7×7 board. After every turn the sun steps along its arc, and every pillar casts a shadow away from the sun whose length depends on the pillar's height and the sun's elevation. An enemy pillar that stands in your shadow at the end of two consecutive sun steps is captured. Your own pillars can shelter each other, and tall pillars block shadows behind them. At night there are no shadows and every count resets. Seasons and latitudes change the arc, so the same position plays differently in winter and summer. There is no luck: everything is visible, and the future shadow pattern is computable, which the UI lets you scrub.

**Pillars:**

1. **Plan for the sun, not the board.** Strong moves anticipate shadows two to four steps ahead. The scrub preview must make this possible for any player.
2. **It should look like chess.** Pieces, heights, and shaded cells are unambiguous from any angle and in the 2D view.
3. **No luck, deep play.** The hard AI should not saturate: expert-tier vs master-tier win rate ≤ 35% at equal time.
4. **Tactile stone.** Placing and raising pillars feels heavy and satisfying.
5. **Small rules, many games.** Rules fit on one card; seasons and latitudes provide variety without new rules.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Limestone `#E3D9C6`, weathered limestone `#C9BBA3`, deep shadow `#3A3428`, golden light `#F2C46D`, Dawn pieces warm sandstone `#D9A066`, Dusk pieces blue slate `#5F6F82`, rule-shadow tint (Dawn) `#B5762E` at 35%, (Dusk) `#2F4A6B` at 35%, sky gradient from `#F7D9A8` (dawn) to `#9CC3E6` (noon) to `#E58B6B` (dusk) to `#1C2236` (night) |
| Shapes | Square-section pillars with chamfered tops; height steps visible as stacked drums; board as a carved slab with inset cells |
| Typography | SF Pro Display Light for titles; numerals in SF Mono for the notation panel |
| Motion | Sun glides smoothly between steps (0.8 s); shadows sweep with it; captures crumble the pillar into sand |
| Music | Slow drone with stone percussion; one note per sun step forming a day-long melody |
| SFX | Stone clicks on place, a deeper grind on raise, a soft crumble on capture, crickets at night |
| Haptics | Heavy transient on place; double heavy on raise; long fade on capture |

**Inspirations:** Polytopia's "it should look like chess" clarity, perfect-information puzzles of Into the Breach, Hoplite, and classic abstracts.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** RealityKit 3D board with one directional light whose direction follows the sun step (decorative physical shadows) **plus** crisp rule-shadow tints on cells from Core's shadow map, because physical shadows are continuous and rules are grid-based. The SpriteKit schematic view shows the same tints top-down. Toggle between views at any time.
- **Rules:** 7×7 grid, integer math, 8-direction shadows only (rules clarity).
- **AI:** alpha-beta with iterative deepening, transposition table (Zobrist keys include sun step and shade counters), and quiescence on pending captures.
- **Async:** `GKTurnBasedMatch` with the full move list in matchData (perfect information; tiny payload).

ADRs to create in P0:

- ADR-0003 Dual views (RealityKit and SpriteKit) reading one shadow map.
- ADR-0004 8-direction shadow model with arc tables.
- ADR-0005 Alpha-beta AI with Zobrist hashing.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── SDLCore/Sources/SDLCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Square.swift, Dir8.swift, Zobrist.swift
│   ├── Board/        Board.swift (7×7), Pillar.swift, Supply.swift
│   ├── Sun/          Arc.swift, SunStep.swift, Season.swift, Latitude.swift
│   ├── Shadow/       ShadowCaster.swift, ShadowMap.swift, Shelter.swift
│   ├── Rules/        MoveGen.swift, Apply.swift, Capture.swift, Victory.swift, Notation.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── SDLContent/       ArcDef.swift, VariantDef.swift, PuzzleDef.swift, Loader.swift
├── SDLAI/            Search.swift (alpha-beta), Eval.swift, TT.swift, Tiers.swift, PuzzleGenerator.swift, PuzzleSolver.swift
├── SDLRender/        StoneBoardView.swift (RealityKit), SchematicScene.swift (SpriteKit), ShadowTint.swift, SunRig.swift, ScrubBar.swift
├── SDLAudio/         DayMelody.swift, StoneSFX.swift
├── SDLPlatform/      TurnBasedService.swift, GameCenterService.swift, CloudSaveService.swift, PencilAdapter.swift
└── SDLMeta/          DailyPuzzle.swift, Rating.swift, Stats.swift, Progression.swift
Resources/Content/    arcs.json, variants.json, puzzles/*.json (generated), balance.json, tutorial.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Setup

- **R-1 Board.** 7×7 squares, coordinates a1–g7 (file a–g west to east, rank 1–7 south to north).
- **R-2 Players.** Dawn moves first, Dusk second.
- **R-3 Supply.** Each player has 14 stones. A pillar of height *h* contains *h* stones. Stones in captured pillars are removed from the game and scored by the captor.
- **R-4 Opening.** The board starts empty. The sun starts at the variant's first step (dawn). Neither player may place on the center square d4 on the first turn of the game.

### 4.2 Turn

- **R-5 Turn sequence.** On a turn the active player performs exactly one action (R-6), then the **sun step** (R-10) happens, then **shade resolution** (R-15), then the turn passes.
- **R-6 Actions.** `place` (put a height-1 pillar from supply on an empty square), `raise` (add 1 stone from supply to one of your pillars of height ≤ 2), `topple` (remove one of your own pillars of height 1 and return its stone to supply; may not be used two turns in a row), or `pass` (only if no other action is legal or once per day per player; see R-11).
- **R-7 Ko-like rule.** A player may not make a move that recreates the full position (board, sun step, counters) of the start of their previous turn.

### 4.3 Sun and Arcs

- **R-8 Arc.** A variant defines an arc as an ordered list of steps; each step has a direction from which the sun shines (one of 8 compass directions) and an elevation class (`low`, `mid`, `high`) — plus one or more `night` steps.
- **R-9 Default arc (Temperate Equinox).** `E low, SE mid, S high, SW mid, W low, night` (6 steps). The arc repeats (a "day" is one full cycle).
- **R-10 Sun step.** After every action, the sun advances to the next arc step (wrapping to the first step after the last).
- **R-11 Days.** A day is one full cycle of the arc. Each player may pass at most once per day voluntarily.

### 4.4 Shadows

- **R-12 Shadow length.** A pillar's shadow length in squares depends on its height and the sun's elevation, per this table (at `high` sun, only pillars of height 2 or 3 cast a shadow, of 1 square; at `zenith` and `night`, no pillar casts a shadow):

  | Height | Low | Mid | High |
  | --- | --- | --- | --- |
  | 1 | 2 | 1 | 0 |
  | 2 | 4 | 2 | 1 |
  | 3 | 6 | 3 | 1 |

- **R-13 Shadow direction.** The shadow extends from the pillar's square in the direction opposite the sun (sun from E → shadow toward W). Diagonal shadows step diagonally. Squares are counted starting from the square adjacent to the pillar.
- **R-14 Occlusion.** A shadow passes over empty squares and over pillars **lower** than the caster; it stops **at** the first pillar of height ≥ the caster's height (that pillar's square is shaded; squares beyond are not).
- **R-15 Shade resolution.** After the sun step, compute for every pillar *P* whether it is **shaded by the opponent**: *P*'s square lies in the shadow of at least one opponent pillar, and *P* is **not sheltered**. *P* is sheltered if its square also lies in the shadow of one of its owner's own pillars (your own shade protects you).
- **R-16 Shade counters.** Each pillar has a counter 0–2. If shaded by the opponent this step, +1; otherwise reset to 0. At night (no shadows) all counters reset to 0.
- **R-17 Capture.** Any pillar whose counter reaches 2 is captured immediately during shade resolution: removed, and its stones are added to the opponent's captured total. All captures in one resolution happen simultaneously (computed on the pre-capture board).
- **R-18 Raising resets nothing.** Raising a shaded pillar does not reset its counter (it changes only future shadows).

### 4.5 Victory

- **R-19 Capture win.** A player who has captured ≥ 8 stones wins at the end of the shade resolution in which that happens. If both reach ≥ 8 simultaneously, the player with more captured stones wins; equal = the player who did **not** make the last action wins.
- **R-20 Exhaustion.** If both players have empty supply and no legal action other than pass for one full day, the game ends: most captured stones wins; tie → most stones on the board; tie → draw.
- **R-21 Move limit.** The game ends after 8 days (48 sun steps in the default arc) with the R-20 tiebreak order.

### 4.6 Variants

- **R-22 Seasons.** Variants change the arc (from `arcs.json`): Summer (long day: `NE low, E low, SE mid, S high, SW mid, W low, NW low, night`), Winter (short day: `SE low, S mid, SW low, night, night`), Polar Summer (the sun circles all 8 directions at `low`, with no night), and Equator (`E low, zenith, zenith, W low, night`). A `zenith` step is the sun directly overhead and casts no shadows.
- **R-23 Board variants.** 7×7 default; 9×9 "Great Court" with 20 stones each and capture target 11.

### 4.7 Edge Cases

- **R-24** A pillar captured during a shade resolution *did* cast its shadow for that sun step (captures are computed simultaneously on the pre-capture board, R-17); its removal affects only later steps.
- **R-25** Shadows leaving the board are truncated.
- **R-26** A raise that would make a pillar taller than 3 is illegal.
- **R-27** If a player has no legal action (empty supply, no toppleable pillar, and pass already used today), they must pass anyway (forced pass).

### 4.8 Invariants

- **INV-1** For each player: supply + stones on board + stones captured by the opponent = 14 (or the variant total).
- **INV-2** Counters are within 0…2; no pillar with counter 2 survives a resolution.
- **INV-3** Shadow maps computed from scratch equal incrementally updated maps (AI uses incremental).
- **INV-4** Board symmetry: rotating the board by 90° and rotating the arc's directions yields rotated shadow maps (property test).
- **INV-5** Zobrist hash equals a from-scratch hash after every move and undo.
- **INV-6** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var board: [Square: Pillar]             // Pillar { owner: Side, height: 1...3, counter: 0...2 }
    public var supply: [Side: Int]; public var captured: [Side: Int]
    public var arc: ArcID; public var step: Int; public var day: Int
    public var toMove: Side; public var passedToday: [Side: Bool]; public var lastToppleTurn: [Side: Int]
    public var history: [UInt64]                    // Zobrist keys for R-7
}
public enum Action: Codable, Equatable, Hashable, Sendable {
    case place(Square), raise(Square), topple(Square), pass
}
public enum Event: Codable, Equatable, Sendable {
    case placed(Side, Square), raised(Side, Square, to: Int), toppled(Side, Square)
    case sunStepped(step: Int, dir: Dir8?, elevation: Elevation?)
    case shaded([Square: Int]), captured([Square], by: Side, stones: Int), gameEnded(Result)
}
```

Notation: `P c3` place, `R c3` raise, `T c3` topple, `—` pass; captures appended `x[e4,e5]`.

### 5.2 Content Tables

**`arcs.json`** — G3: 6 arcs (equinox, summer, winter, polar summer, equator, high desert).

```json
{ "id": "winter", "steps": [{ "dir": "SE", "elev": "low" }, { "dir": "S", "elev": "mid" },
  { "dir": "SW", "elev": "low" }, { "night": true }, { "night": true }], "nameKey": "arc_winter" }
```

**`variants.json`** — G3: 8 variants (arc × board size combos).

**`puzzles/*.json`** — G5: 365 generated daily puzzles, plus 60 handpicked tutorial puzzles.

```json
{ "id": "p_2027_03_14", "variant": "equinox_7", "position": "FEN-like string", "toMove": "dawn",
  "goal": { "captureStones": 3, "withinTurns": 3 }, "solution": ["R c3", "P e5", "R e5"], "difficulty": 6 }
```

Position string (`position` field): ranks 7 to 1 separated by `/`; each square is a digit run for empty squares or a piece token: `D1`–`D3` for Dawn pillars and `K1`–`K3` for Dusk pillars by height, followed by one `'` per shade-counter point (e.g., `K2'`). After the board, space-separated fields: arc step index, day, Dawn supply, Dusk supply, Dawn captured, Dusk captured. Example: `7/7/2D1K2'3/7/3D3K12/7/7 2 1 10 11 0 0`.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `stones.perPlayer` | 14 | 12–16 | balance.json |
| `capture.target` | 8 | 6–10 | balance.json |
| `game.maxDays` | 8 | 6–10 | balance.json |
| Shadow factor table | R-12 | per arc | arcs.json |
| `counter.toCapture` | 2 | 2 (fixed in v1.0) | balance.json |

**Target metrics (AI self-play, ≥ 2,000 games per variant at the expert tier):**

| Metric | Target |
| --- | --- |
| First-player (Dawn) win rate | 48–54% per variant (adjust the d4 rule or komi-like tiebreak if outside) |
| Draw rate | ≤ 6% |
| Average game length | 22–34 turns |
| Games ending by capture target | ≥ 60% |
| Master vs expert (same time) | ≥ 65% (depth matters, pillar 3) |
| Average branching factor | 25–60 |

## 7. AI Approach

| Tier | Algorithm | Budget (iPad A16, p95) |
| --- | --- | --- |
| `pupil` | Depth-1 search + eval with 30% chance to pick a random move among the top 5 | 50 ms |
| `apprentice` | Iterative deepening alpha-beta to depth 3 | 200 ms |
| `adept` | Depth 5 with TT and move ordering (captures-threatening first, killer moves) | 700 ms |
| `expert` | Time-bounded iterative deepening (typically depth 7–8) with quiescence on counter-1 pillars | 1,500 ms |
| `master` | Same as expert with 4 s budget and late-move reductions; shown with a "deep thought" indicator | 4,000 ms |

**Evaluation features:** captured-stone difference (×10); pillars at counter 1 for each side (threat, ×4); projected shade over the next 2 sun steps (computed exactly; ×3); sheltered fraction of own pillars; supply remaining (tempo); tall pillars' coverage of the center; a night-proximity term (counters reset soon).

**Daily puzzle generation (`PuzzleGenerator`):** random self-play positions from expert games sampled at turns 10–30 → solver proves a forced line achieving the goal within N turns against best defense (full-width search to 2N plies with TT); require a **unique** first move; rate difficulty by solve node count. CI generates and verifies the next 60 days; puzzles ship in content bundles.

**Determinism:** search is deterministic (no randomness except `pupil`, which uses its own seeded RNG); move ordering ties break by square index.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **SDL-P0.1 Dir8 and square utilities;** notation parser and printer. Acceptance: round-trip tests.
- **SDL-P0.2 Arc loader** with validation (every arc has ≥ 1 shadow-casting step and every direction is one of the 8 compass points). Acceptance: content-lint rejects a malformed fixture arc.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-27 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **SDL-P1.1 Shadow caster (R-12–R-14, R-25).** Acceptance: ≥ 40 golden shadow-map fixtures across arcs; INV-4 rotation property.
- **SDL-P1.2 Shade resolution and capture (R-15–R-18, R-24).** Acceptance: sheltering, simultaneous capture, night reset.
- **SDL-P1.3 Moves, passes, ko, and topple restrictions (R-5–R-7, R-11, R-26, R-27).**
- **SDL-P1.4 Victory (R-19–R-21).**
- **SDL-P1.5 Zobrist and incremental shadow maps (INV-3, INV-5).**

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 over 5,000 seeds
  [ ] SDLCore coverage ≥ 90%
  [ ] `make sim N=5000` random games: 0 crashes; identical hashes; perft-style node counts for depth 1–3 from 5 fixed positions committed and stable
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: equinox 7×7, apprentice AI, both views.

- **SDL-P2.1 Schematic view** (SpriteKit): pillars with height numerals, counters as pips, rule-shadow tints per side.
- **SDL-P2.2 Stone board view** (RealityKit): placeholder limestone materials, sun rig with decorative shadows, rule tints projected on cells.
- **SDL-P2.3 Interactions.** Tap an empty square to place; tap your pillar to raise; press and hold your height-1 pillar to topple; drag a pillar from your supply tray as an alternative; select-then-confirm option in settings. Mouse: click, ⌥-click topple.
- **SDL-P2.4 Sun scrub.** Drag the sun along its arc (or a scrub bar) to preview shadows and counters for the next 1–6 steps assuming no further moves; projected captures glow.
- **SDL-P2.5 Move list** with notation and undo in casual games.

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest completes a full game vs apprentice in both views on iPad and Mac
  [ ] Scrub preview equals Core's simulated shadow maps for 1–6 steps (test)
  [ ] Physical shadow direction matches rule-shadow direction for every arc step (render test)
  [ ] Resume to identical hash; docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — is planning for the sun the core skill? Are captures foreseeable?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **SDL-P3.1** Six arcs and eight variants with a rules card each.
- **SDL-P3.2** Tutorial: 7 interactive lessons (place, shadows by elevation, occlusion, sheltering, two-step capture, night reset, seasons).
- **SDL-P3.3** Pass-and-play with board rotation per player.
- **SDL-P3.4** Game review mode: step through a finished game with the AI's evaluation graph (adept depth).

```
GATE G3 — Content and Systems
Checks:
  [ ] 8 variants each pass 1,000-game sims; tutorial UI test passes
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **SDL-P4.1** Five tiers (§7); TT; move ordering; quiescence.
- **SDL-P4.2** First-move balance tuning per variant (adjust the d4 restriction or a "Dusk wins equal-capture ties" rule; log ADRs).
- **SDL-P4.3** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Soak 500 games per tier per variant: 0 illegal moves; p95 within budgets (CI scaled)
  [ ] Tier ladder: each tier beats the one below ≥ 65%
  [ ] First-player win rate within 48–54% per variant
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **SDL-P5.1 Daily puzzle** (UTC date) with streaks; generator and solver in CI for 60 days ahead.
- **SDL-P5.2 Puzzle library** of 60 handpicked puzzles by difficulty.
- **SDL-P5.3 Local rating** (Glicko-2) vs AI tiers; and scaffolding for async ranked play (`TurnBasedService` protocol with fake).
- **SDL-P5.4 Stats** and achievements list (bound in P7).

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] 60 dailies generated, each with a verified unique solution
  [ ] Fake async service plays a full game between two local clients
  [ ] All standard tests and coverage thresholds pass; docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **SDL-P6.1** Final limestone PBR materials, weathering, and lichen variants; sky dome gradients per step; night stars.
- **SDL-P6.2** Capture crumble effect (particles of sand).
- **SDL-P6.3** Day melody system; stone SFX; haptics.

```
GATE G6 — Aesthetics
Checks:
  [ ] Pillar 2 test: 10 random positions, both views, a tester names heights and shaded squares without error
  [ ] 120 fps on iPad Pro (M4) in the 3D view
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **SDL-P7.1 Pencil.** Hover over a square previews the shadow a pillar there (or raised) would cast for the next 3 steps; squeeze toggles 2D/3D.
- **SDL-P7.2 GameKit turn-based** async matches with rematch; ranked leaderboard (rating) and daily puzzle streak leaderboard.
- **SDL-P7.3 iCloud** saves and puzzle progress.
- **SDL-P7.4 Mac.** Keyboard notation entry (type `R c3`), arrows to scrub the sun.

```
GATE G7 — Platform
Checks:
  [ ] Two sandbox accounts complete an async game across iPad and Mac
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **SDL-P8.1** Side tints distinguishable by pattern (Dawn diagonal hatch, Dusk dots) as well as color.
- **SDL-P8.2** VoiceOver: full play by square names, with shade and counter readouts; notation entry.
- **SDL-P8.3** Reduce Motion: sun jumps between steps.

```
GATE G8 — Polish
Checks:
  [ ] A full game playable with VoiceOver only (UI test)
  [ ] Budgets met on real devices; master tier ≤ 4 s on A16
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight (Mahler creates records); crash-free ≥ 99.5%
  [ ] Daily puzzle solve rate 40–75% among testers
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview is a time-lapse of a full day over a midgame position with a capture at sunset.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** occlusion (R-14) with equal heights; simultaneous captures; physical-vs-rule shadow alignment in 3D.
- **First tasks:** Grok — variant balance and puzzle quality (curate the 60 handpicked); Claude — the 3D board polish and VoiceOver flow.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Physical shadows confuse rule shadows | Medium | High | Crisp rule tints; schematic view; render test | CLAUDE |
| First-player advantage | Medium | Medium | Self-play tuning and tie rules | GLM |
| Game too abstract for broad audience | Medium | Medium | Daily puzzles and gentle tutorial | GROK |
| Puzzle generator yields dull puzzles | Medium | Medium | Difficulty rating and human curation | GROK |

## 11. Out of Scope

- Real-time play; more than two players.
- Custom arcs created by players (post-launch candidate).
- Online chat.
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 5–7 |
| P2 Vertical Slice | GLM | 7–10 |
| P3 Content and Systems | GLM | 4–6 |
| P4 AI | GLM | 5–8 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 8–12 |
| P7 Platform | CLAUDE | 4–6 |
| P8 Polish | CLAUDE | 4–6 |
| P9 Beta | GROK + CLAUDE | 4–8 |
| P10 Release | CLAUDE + GROK | 2–3 |
| **Total** | | **49–75** |

## 13. Open Questions for Mahler

1. Capture threshold of two consecutive steps (fixed) or a variant with three? **Default:** two only.
2. Ship the 9×9 Great Court in v1.0? **Default:** yes, as an unlockable variant.
3. Should ranked async use a client-computed rating on a Game Center leaderboard (simple, cheatable) or only win counts? **Default:** win counts plus local rating display.
4. Player names "Dawn" and "Dusk"? **Default:** yes.
5. Price? **Default:** Mahler decides in P10.
