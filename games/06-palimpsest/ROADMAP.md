# 06 — Palimpsest Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 06 · `palimpsest` |
| Code prefix | `PS` (packages `PSCore`, `PSContent`, `PSAI`, `PSRender`, `PSAudio`, `PSPlatform`, `PSMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Puzzle tactics (turn-based, deterministic) |
| Difficulty tier | Hardcore |
| Scope | Small team |
| Session length | 15–30 minutes per island; 1–2 hour campaign run |
| Renderer | SpriteKit (2D isometric-free top-down grid) with SKShader ghost effects |
| Players | Solo |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Squad tactics where each turn your previous turn replays as ghost echoes, so you fight beside, and sometimes against, your own past.
- **Summary:** You command three Scribes on an 8×8 grid defending Archives from telegraphed enemy attacks. After you act, your actions from the previous turn re-execute as Echoes, which deal damage and push like the real thing, including to your own units. Enemies then attack. Survive five turns per map, protect the Archives, and carry your squad across procedural islands.
- **Pillars:**
  1. **Every move is a two-turn plan.** Today's action is tomorrow's echo.
  2. **Total information.** Enemy intents, echo previews, and outcomes are all visible before you commit.
  3. **Deterministic and fair.** No hit chances; failure is always explicable.
  4. **Short, dense fights.** Five turns per map, rarely more than ten minutes.
- **Aesthetic spec:**
  - Palette: cyanotype Prussian blue `#13315C`, deep blue `#0B1F3A`, line white `#F1F5F9`, echo white at 45% opacity with bloom, enemy rust `#C2562E`, Archive gold `#D9B44A`, hazard magenta `#C2378F` (sparingly).
  - Visuals: blueprint line art, units as technical drawings of robed scribes with instruments; echoes as overexposed photographic ghosts with light leaks; tiles with drafting-grid texture.
  - Audio: minimal synths through a tape delay whose echo time equals the turn's echo playback; footsteps on paper; a shutter click when echoes trigger.
  - Haptics: a double pulse for echo impacts (the "echo" of a hit).
- **Inspirations:** Into the Breach's telegraphing and collapsible touch UI, Tactical Breach Wizards' rewinds, and Hoplite.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Renderer:** SpriteKit `BattleScene`, top-down grid (clear tile boundaries per the research on legibility); `SKShader` for echo ghosting and bloom.
- **Core:** fully deterministic turn resolution; previews are computed by running the reducer on a copy of the state.
- ADRs: ADR-0003 (echoes as recorded action scripts, not snapshots), ADR-0004 (preview by reducer simulation), ADR-0005 (8×8 grid, 5 turns).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/PSCore/Sources/PSCore/
  Model/ Cell.swift, Tile.swift (ground, water, chasm, rubble, Archive), Unit.swift (Scribe), Enemy.swift, Echo.swift, Intent.swift, GameState.swift
  Rules/ Reducer.swift, Movement.swift, Abilities.swift, Push.swift, Damage.swift, EchoReplay.swift, EnemyPhase.swift, Spawning.swift, Objectives.swift, TurnOrder.swift
  Run/ RunState.swift, Island.swift, Squad.swift, Upgrades.swift
  Replay.swift
Packages/PSContent/Sources/PSContent/ SquadCatalog.swift, EnemyCatalog.swift, MapTemplates.swift, ObjectiveCatalog.swift, UpgradeCatalog.swift, Validation.swift
Packages/PSAI/Sources/PSAI/ EnemyIntentPlanner.swift, TurnSolver.swift (beam search over player turns), MapVerifier.swift, DailyGenerator.swift
Packages/PSRender/Sources/PSRender/ BattleScene.swift, UnitNode.swift, EchoNode.swift, IntentOverlay.swift, PreviewOverlay.swift, TimelineStrip.swift, IslandMapScene.swift
Packages/PSAudio/Sources/PSAudio/ TapeDelaySynth.swift, SFX.swift
Packages/PSMeta/Sources/PSMeta/ Campaign.swift, Unlocks.swift, Daily.swift, Achievements.swift
Resources/Content/ squads.json, scribes.json, enemies.json, templates/*.json, objectives.json, upgrades.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup**
- R-1 The board is 8×8. Tiles: ground, water (units drown unless flying; pushes into water kill ground enemies), chasm (falls kill), rubble (blocks movement, destroyed by 1 damage), and Archive (blocks movement; has 1 HP; destroyed Archives reduce the run's Ink).
- R-2 The player deploys 3 Scribes in the highlighted deployment zone (rows 1–3 by default).
- R-3 Enemies spawn at telegraphed spawn cells (shown one turn ahead); a unit standing on a spawn cell blocks the spawn and takes 1 damage.

**Turn Structure (5 Turns per Map)**
- R-4 Phase order each turn: (1) Enemy intents are shown (computed at the end of the previous turn), (2) Player phase, (3) Echo phase, (4) Enemy action phase (in intent order), (5) Environment phase (hazards), (6) Enemy movement and new intents, (7) Spawns resolve and next spawns are telegraphed.
- R-5 Player phase: each Scribe may move up to its Move value (orthogonal path around blockers) and then use one ability, in any order across Scribes; a Scribe may act without moving or move without acting. One "Rewind" per battle undoes the entire player phase.
- R-6 Every player action is recorded as an `EchoScript { scribeID, startCell, path (relative steps), ability, targetOffset (relative to the Scribe's position at use time) }`.

**Echoes**
- R-7 Echo phase: the scripts recorded in the previous turn (not the current turn) replay in their original order as Echo entities that appear at their recorded `startCell`.
- R-8 An Echo follows its relative path step by step; if a step is blocked (by any unit, enemy, or blocking tile), it stops at its last valid cell and still uses its ability with the same relative target offset.
- R-9 Echo abilities deal the same damage, push, and effects as the original, and they affect all units including the player's Scribes (friendly fire) and Archives.
- R-10 Echoes are not units: they cannot be damaged, do not block enemy movement, and vanish after the Echo phase. They do block other Echoes during the Echo phase.
- R-11 Turn 1 has no Echo phase. Squad modifiers change echo rules (R-20).

**Abilities and Damage**
- R-12 Abilities are defined in content with `targeting` (adjacent, line, artillery arc, self), `damage`, `push` (direction relative to the source), and `effects` (shield, smoke, ink-pool hazard).
- R-13 Push: a pushed unit moves 1 cell; if blocked, it and the blocker each take 1 damage (bump); pushing into water or chasm kills ground units.
- R-14 Damage reduces HP; shields absorb one instance; units at 0 HP die and leave no corpse (except "Husk" enemies, which leave rubble).

**Enemies**
- R-15 Enemy intents target cells, not units: when the enemy acts, whatever is in the targeted cells is hit. Pushing or killing an enemy before its action cancels or redirects its attack exactly as the intent rules specify (attacks follow the enemy's facing and relative offset).
- R-16 Enemy action order is shown by numbered badges; ties are impossible (strict order by spawn index).

**Objectives and Run**
- R-17 Each map has the base objective "Survive 5 turns" plus 0–2 bonus objectives (protect a specific tile, kill N enemies, finish with no friendly-fire damage, keep an Echo from hitting an Archive).
- R-18 Run: an island has 4 maps chosen from 6 offered in any order, then a boss map. A campaign is 3 islands plus a final map. Ink (run HP) starts at 7; destroyed Archives cost 1 Ink each; at 0 Ink the run ends.
- R-19 Rewards: bonus objectives give Reagents (currency) for upgrades (HP, Move, ability upgrades) and Folios (new abilities); Scribes that die in a map return next map at 1 HP but gain a "Scar" (−1 Move until healed at a shop).
- R-20 Squads change echo rules: Standard (echoes replay last turn), Delayed (echoes replay the turn before last; turns 1–2 have none), Mirrored (echo paths and targets are mirrored across the vertical axis), Amplified (echoes deal +1 damage; Scribes deal −1 minimum 1), Silent (no echoes; each Scribe gains a second ability use), and Chorus (two layers of echoes: last turn and the turn before, each at −1 damage).

**Invariants**
- INV-1 No two units occupy one cell; Echoes never persist past the Echo phase.
- INV-2 The preview of a full turn equals the actual resolution (preview uses the reducer).
- INV-3 Enemy intents are fixed between the end of turn N and their resolution in turn N+1, except as modified by pushes and kills per R-15.
- INV-4 Replay determinism for full runs.
- INV-5 Every generated map has at least one solution that loses no Archives on turn 1–2 (verified by `MapVerifier`).

## 5. Data Schemas and Content Tables

```swift
struct EchoScript: Codable, Hashable { let scribe: Int; let startCell: Cell; let steps: [Dir]; let ability: AbilityID?; let targetOffset: Cell? }
struct Intent: Codable, Hashable { let enemy: Int; let order: Int; let ability: AbilityID; let facing: Dir; let cells: [Cell] }
enum Action: Codable { case deploy(Int, Cell), move(Int, [Dir]), useAbility(Int, AbilityID, target: Cell), endPlayerPhase, rewind, chooseMap(Int), buyUpgrade(String) }
```

`scribes.json` row:
```json
{ "id": "vanguard", "hp": 3, "move": 3, "abilities": ["shove"], "flying": false, "art": "vanguard" }
```
`enemies.json` row: `{ "id": "rust_hound", "hp": 2, "move": 3, "ability": "bite", "behavior": "nearest_archive", "tier": 1 }`.

Map templates are 8×8 strings plus spawn tables:
```json
{ "id": "t_river_bend", "rows": ["..~~....", "..~~..A.", "........", "..R.....", "......R.", ".A......", "........", "DDDDDDDD"], "spawnBands": ["top"], "biome": "estuary" }
```

Content counts — G3: 3 Scribe archetypes (Vanguard push melee, Lancer line shot, Warden shield and pull), 1 squad (Standard), 12 enemy types, 20 map templates, 8 bonus objectives, 15 upgrades. G5: 6 squads (R-20) with 3 Scribes each (18 Scribe variants), 24 enemies including 3 bosses, 45 templates across 3 biomes, 14 objectives, 40 upgrades/Folios, daily map.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `turnsPerMap` | 5 | 4–6 |
| `startInk` | 7 | 5–9 |
| `scribeBaseHP` | 3 | 2–4 |
| `bumpDamage` | 1 | fixed |
| `spawnsPerTurn` (by island) | 1–2, 2, 2–3 | |
| `reagentsPerBonus` | 1 | |

Targets (TurnSolver beam 64 as player proxy, 1,000 runs): Standard squad campaign completion 55–75% for the solver (humans will be lower); average Archives lost per map 0.3–0.8; friendly-fire incidents occur in ≥ 30% of maps (to prove echoes matter); each squad within ±10 points of Standard's completion rate.

## 7. AI Approach

- **Enemy intent planner:** each enemy chooses a move cell and attack target maximizing a score (Archive hits × 10 + Scribe hits × 6 + kills × 8 − own-risk × 2), considering the visible echo scripts that will replay next turn (enemies "know" echoes, making them cleverer on higher difficulty; Easy ignores echoes). Deterministic tie-break by cell order.
- **TurnSolver (player proxy for balance and verification):** enumerates Scribe orderings (6), moves (≤ 25 each), and targets, pruned with beam search (width 64) and evaluated by the full reducer including the next Echo phase.
- **MapVerifier:** rejects generated maps where the solver at width 32 loses Archives on turn 1 or 2.
- **Daily:** seed `hash("PS-daily-" + yyyyMMdd UTC)` fixes squad, three maps, and enemies; score by Archives saved, bonus objectives, and turns without damage.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.

```
GATE G0 — Setup: standard checks · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- PS-P1.1 Board, tiles, units, and deployment (R-1 to R-3).
- PS-P1.2 Turn structure and player actions with Rewind (R-4 to R-6).
- PS-P1.3 Echo replay including blocking, friendly fire, and ordering (R-7 to R-11) with ≥ 40 scenario tests.
- PS-P1.4 Abilities, push, bump, hazards, and damage (R-12 to R-14).
- PS-P1.5 Enemy intents and resolution (R-15, R-16) and objectives (R-17).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-17 tagged tests (R-18–R-20 may be stubbed with tests for Standard squad only)
  [ ] INV-1…INV-4 over 5,000 random-play maps; PSCore coverage ≥ 90%
  [ ] make sim N=5000: 0 crashes; stable hashes
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- PS-P2.1 `BattleScene`: tap a Scribe, tap a destination (reachable cells highlighted), tap an ability, tap a target.
- PS-P2.2 Intent overlay (numbered enemy attacks with target cells) and echo preview (ghost paths for next Echo phase).
- PS-P2.3 Timeline strip: scrub through the resolution of the upcoming turn (Player → Echo → Enemy) before ending the player phase.
- PS-P2.4 Collapsible info panels (tile info, enemy info) per the Into the Breach touch lessons; confirm button away from the dominant-hand wrist (left/right setting).
- PS-P2.5 One island of 4 maps plus a mini-boss using 6 enemy types.
- PS-P2.6 Mac: click to select, keyboard 1–3 to choose Scribes, Q/W abilities, Enter to end phase.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full island with scripted actions on iPad and Mac
  [ ] INV-2 verified in UI: preview outcome hash equals executed outcome hash on 200 scripted turns
  [ ] Rewind restores the exact pre-phase hash
Sign-off: GLM-SELF
```

### P3 Content and Systems
- PS-P3.1 Reach G3 content counts; tile hazards; Husk rubble.
- PS-P3.2 Island map screen with map choice and rewards; shop with upgrades.
- PS-P3.3 Tutorial: 7 steps (move, attack, intents, push, first echo, friendly fire, rewind).
- PS-P3.4 Bonus objectives UI and tracking.

```
GATE G3 — Content and Systems: counts met; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF
```

### P4 AI Opponents
- PS-P4.1 Enemy intent planner with Easy (ignores echoes), Normal, and Hard (anticipates echoes and baits friendly fire).
- PS-P4.2 TurnSolver and MapVerifier; balance report via `Tools/sim campaign --solver beam64 N=1000`.

```
GATE G4 — AI
Checks:
  [ ] Planner p95 ≤ 100 ms per enemy turn; TurnSolver width 64 ≤ 2 s per turn on Mac
  [ ] MapVerifier rejects 100% of seeded unwinnable maps in a crafted test set
  [ ] Solver completion within targets or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- PS-P5.1 All 6 squads and echo-rule variants; unlocks by achievements (e.g. "Win with no friendly fire" unlocks Silent).
- PS-P5.2 Three biomes, bosses, and the campaign structure (R-18).
- PS-P5.3 Daily map; local leaderboards; perfect-run tracking.
- PS-P5.4 Achievements (30) and statistics.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Each squad's solver completion within ±10 points of Standard
  [ ] Daily identical across devices for 30 dates
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- PS-P6.1 Cyanotype art set, drafting-grid tiles, echo ghost shader with light leaks.
- PS-P6.2 Tape-delay synth score whose delay time is tied to echo playback; SFX.

```
GATE G6 — Aesthetics: snapshots approved; echo readability test (5 testers identify echoes vs units ≥ 95%) · Sign-off: GLM-SELF
```

### P7 Platform Features
- PS-P7.1 Game Center: daily leaderboard, campaign wins by squad, 30 achievements, daily challenge.
- PS-P7.2 iCloud saves at map boundaries and mid-battle.
- PS-P7.3 Pencil hover previews path and echo outcome for the hovered cell; squeeze opens the ability wheel.
- PS-P7.4 Controller support (MFi/Xbox/DualSense) for couch play on Mac and iPad.

```
GATE G7 — Platform: iCloud round-trip; controller completes a map · Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- PS-P8.1 VoiceOver: full board description, intents list, and echo forecast list.
- PS-P8.2 Shapes and patterns distinguish enemies, Scribes, and Echoes beyond color; Reduce Motion skips ghost animation.

```
GATE G8 — Polish: perf budgets; VoiceOver completes the tutorial · Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: GLM-SELF
GATE G10 — Release: assets approved · Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- Fragile areas: echo blocking rules (R-8, R-10) and enemy redirect rules (R-15).
- Priorities for P6–P10: squad and enemy design for clever echo interactions; preview/timeline UX and performance of solver tools.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Echoes overwhelm players | High | High | Strong previews, timeline scrub, Rewind, and gentle first island | GLM |
| Too close to Into the Breach | Medium | Medium | Echo mechanic is core; distinct art and run structure | GLM |
| Solver too slow for verification | Medium | Low | Run verification offline in Tools, cache verified templates | GLM |

## 11. Out of Scope

Multiplayer; level editor; voice acting; narrative campaign beyond short island intros.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 8–12 |
| P2 | GLM | 10–14 |
| P3 | GLM | 10–14 |
| P4 | GLM | 8–12 |
| P5 | GLM | 10–14 |
| P6 | GLM | 12–18 |
| P7 | GLM | 5–8 |
| P8 | GLM | 5–8 |
| P9 | GLM | 8–12 |
| P10 | GLM | 3–4 |
| **Total** | | **81–118** |

## 13. Open Questions

1. Theme of the Scribes and enemies (archival mages vs creeping ink)? Default: archival scribes vs "Blots", an ink corruption.
2. Include the Rewind in Hard mode? Default: one per battle on Normal, none on Hard.
