# 24 — The Loom Court Roadmap

> A deckbuilder of courtly intrigue where cards are threads, and the tapestry you weave decides who rises at court.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to The Loom Court.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 24 · `the-loom-court` |
| Code prefix | `LMC` (packages `LMCCore`, `LMCContent`, `LMCAI`, `LMCRender`, `LMCAudio`, `LMCPlatform`, `LMCMeta`) |
| Bundle ID (placeholder) | `com.zyniker.the-loom-court` |
| Subgenre | Pattern-building roguelite deckbuilder on a shared board |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 20–40 min per run (3 seasons, each ending in a Judgment) |
| Renderer | SpriteKit (2D) with woven-textile normal-mapped textures and an `SKShader` for thread sheen |
| Players | Solo only (vs AI courtiers) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** A deckbuilder of courtly intrigue where cards are threads, and the tapestry you weave decides who rises at court.

**Summary:** A run is one courtier's rise through three seasons at court. Each **audience** (encounter) is a fresh 6×6 tapestry shared with one or two rival courtiers. On each turn the player spends needles to play thread cards into cells: madder red, woad blue, weld yellow, or mixed dyes. Lines and shapes of matching color form **patterns** that trigger effects: red patterns earn Influence, blue patterns reveal Secrets (draw, peek, and disrupt), yellow patterns earn Favor (gold for the run), and gold thread is wild. Rivals weave on the same cloth and telegraph their next stitch, so the player can block, hijack, or complete a rival's pattern to claim it. Overstitching a rival's thread is powerful but builds Scandal. Reach the audience's Influence target before the candle burns out. Between audiences: draft threads, dye cards a new color, remove cards at the tailor, and meet court events. Each season ends with a Judgment by a ruling figure with special rules.

**Pillars:**

1. **The board is shared, so every stitch is double-edged.** Most strong plays both build your pattern and deny a rival's. If sims show players can ignore rivals and win at the same rate, the pillar fails.
2. **Combos you can read.** Pattern scoring shows its math (base × multiplier) as it happens, Balatro-style.
3. **Telegraphed rivals.** Rivals show their next stitch's color and target line; surprises come from your own combos, not hidden enemy actions.
4. **The deck becomes a dye palette.** Dyeing and removal reshape the deck's color profile; a run's tapestry looks like its deck.
5. **Cloth you want to frame.** Finished tapestries are beautiful and saved to a gallery.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Madder red `#A3262A`, woad blue `#2D4F8B`, weld yellow `#D9B23A`, mixed: purple `#5E3A73`, green `#4C7A3D`, orange `#C96A2B`; gold thread `#D4AF37`; undyed linen `#E9E1CF`; loom wood `#5A3B24`; scandal soot `#3B3335` |
| Shapes | Every cell is a woven patch with visible warp and weft; patterns are outlined with a stitched border when formed; cards are long thread spools with a color swatch and a stitch glyph |
| Typography | A blackletter-inspired display face only for titles (default New York Black Italic), SF Pro for numbers |
| Motion | Shuttle animation across a row when placing; formed patterns ripple; scandal stains spread like ink |
| Music | Lute and soft choir; a percussion layer joins as Influence nears the target |
| SFX | Shuttle clacks, thread pulls, a bell per pattern (pitch by size), murmuring court on scandal |
| Haptics | Tick per cell woven; rising pattern for combos (one pulse per pattern in the chain) |

**Inspirations:** Balatro's pattern scoring, Slay the Spire's deck growth and readable intents, and medieval tapestry.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit with normal-mapped weave textures (one `SKLightNode` for a soft key light); thread sheen via `SKShader`.
- **Rules:** integer scoring; pattern detection by scanning lines and templates after each placement.
- **No real-time elements.**

ADRs to create in P0:

- ADR-0003 Pattern detection by template scan with deterministic claim resolution.
- ADR-0004 Scoring model (base × multiplier with integer math).
- ADR-0005 Rival intent model (telegraphed next stitch).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── LMCCore/Sources/LMCCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Cell.swift
│   ├── Tapestry/     Tapestry.swift (6×6), Thread.swift (color, owner, stitch, layer), Overstitch.swift
│   ├── Patterns/     PatternTemplate.swift, Detector.swift, Claim.swift, Combo.swift, Scoring.swift
│   ├── Cards/        Card.swift, CardEffect.swift, Deck.swift, Hand.swift, Needles.swift, Dye.swift
│   ├── Court/        Courtier.swift (rival), Intent.swift, Favor.swift, Scandal.swift, Secrets.swift
│   ├── Audience/     AudienceState.swift, Candle.swift (turn limit), AudienceResult.swift
│   ├── Run/          RunState.swift, CourtMap.swift, Season.swift, Judgment.swift, Patronage.swift (relics)
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── LMCContent/       CardDef.swift, CourtierDef.swift, JudgeDef.swift, PatronageDef.swift, EventDef.swift, Loader.swift
├── LMCAI/            RivalPolicy.swift, IntentPlanner.swift, PlayerBot.swift, MapGenerator.swift, DailyVerifier.swift
├── LMCRender/        LoomScene.swift, CellNode.swift, PatternBorder.swift, CardHand.swift, ScoreTicker.swift, Shaders/
├── LMCAudio/         CourtMusic.swift, ShuttleSFX.swift
├── LMCPlatform/      PencilStitch.swift, GameCenterService.swift, CloudSaveService.swift
└── LMCMeta/          Progression.swift, DailyWeave.swift, Gallery.swift, Stats.swift, Ascension.swift
Resources/Content/    cards.json, courtiers.json, judges.json, patronage.json, events.json, patterns.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Run Structure

- **R-1 Run.** Three seasons (Spring, Summer, Winter Court). Each season is a court map of 8–10 nodes in rows (audience, salon, tailor, dyer, intrigue event, and patron) ending with a **Judgment** audience.
- **R-2 Standing.** The player has Standing 5 (lives). Losing an audience costs 1 Standing (2 for a Judgment). At 0 Standing the run ends in exile.
- **R-3 Starting deck.** 12 cards: 4 red, 4 blue, 3 yellow thread cards (basic stitches) and 1 `needle_of_grace` (draw 2).

### 4.2 Audience Setup

- **R-4 Tapestry.** A 6×6 grid; each cell holds a stack of up to 2 thread layers (base and overstitch). The visible thread is the top layer.
- **R-5 Participants.** The player and 1–2 rival courtiers. Turn order: player, then rivals in seat order.
- **R-6 Candle.** An audience lasts `candle` rounds (default 8). The player wins the audience by reaching the Influence target (shown at start, e.g., 120) by the end of any round; otherwise, at candle's end, the player loses the audience unless their Influence exceeds every rival's **and** at least 75% of the target (a "narrow favor": win with no rewards).
- **R-7 Draw.** At each player turn start: draw to 5 cards, gain 3 needles. Unused needles do not carry over (except with patronage effects).

### 4.3 Thread Cards

- **R-8 Card anatomy.** Each card has a needle cost (0–3), a color (`red`, `blue`, `yellow`, `purple` = red or blue, `green` = blue or yellow, `orange` = red or yellow, `gold` = any), a **stitch** (shape it lays), and optional effects.
- **R-9 Stitches.** `single` (1 cell), `warp` (2 vertically adjacent empty cells), `weft` (2 horizontally adjacent), `knot` (1 cell; this thread cannot be overstitched), `couching` (1 cell; adjacent same-color threads count double for pattern size), and `chain` (up to 3 cells in a straight line; costs +1 needle).
- **R-10 Placement.** A stitch must be laid on empty cells, or on cells whose top layer is a single thread layer (overstitch, R-14). A stitch cannot partially overlap the board edge.
- **R-11 Mixed colors.** A mixed or gold thread counts as each of its colors for pattern detection; for claim resolution (R-13) it counts for its owner.

### 4.4 Patterns

- **R-12 Templates.** After every placement, the detector scans for newly formed patterns (patterns that include at least one cell just placed), each defined in `patterns.json`:
  - `line3`, `line4`, `line5`, `line6` (orthogonal lines of the same color),
  - `diag4` (diagonal line of 4),
  - `block` (2×2 same color),
  - `cross` (plus shape of 5),
  - `border_run` (6 same-colored cells along one edge), and
  - `rosette` (3×3 ring of 8 same color around any center).
  A cell may contribute to several patterns at once (that is the combo engine).
- **R-13 Claim.** A pattern belongs to whoever owns the **majority** of its cells (top layers). Ties go to the player who placed the most recent thread in it (the placer). Claimed patterns resolve their color effect for the claimant.
- **R-14 Overstitch.** Laying a thread on top of another participant's thread costs +1 needle per overstitched cell and adds **1 Scandal** per cell to the overstitcher. Overstitching your own thread is free of scandal (+1 needle still). Cells with 2 layers cannot be stitched again.
- **R-15 Effects by color.** Red: `+Influence = score` (R-16). Blue: Secrets — draw 1 card per 2 cells (rounded down) and, for patterns of size ≥ 5, cancel one rival's next intent. Yellow: Favor — gain `size × 2` Favor (run currency) and +1 needle next turn for size ≥ 5. Mixed-color patterns (all cells counted via a mixed or gold color) apply that color's effect.
- **R-16 Scoring.** Each claimed pattern has `base` (from the template: line3 10, line4 20, line5 35, line6 60, diag4 25, block 15, cross 30, border_run 50, rosette 70) and `mult` starting at 1. Within a single placement's resolution: each additional pattern formed adds +1 to the mult of all patterns in that resolution (combo); cards and patronage add flat base or mult. The total mult per resolution is capped at `balance.combo.multCap` (default 8). Influence gained = Σ base × total mult. Integer math only.
- **R-17 Re-forming.** A pattern instance (same template, same cells) can be claimed only once per audience; extending a line (line3 → line4) forms a new instance and scores the larger template only (the smaller is upgraded, not re-scored).

### 4.5 Rivals

- **R-18 Intents.** At the start of the player's turn each rival displays its **intent**: the color it will weave, its stitch, and its target line or cell set (as a highlighted region of 1–6 cells), plus any special ability (e.g., "will overstitch your highest-value thread").
- **R-19 Rival turns.** On its turn a rival executes its intent if legal; if its target cells were taken, it executes its fallback (the best legal placement by its policy in the same region; if none, anywhere). Rival patterns score Influence for the rival and may apply rival-specific effects (e.g., add Scandal to the player).
- **R-20 Rival Influence.** Rivals accumulate Influence by the same scoring rules. A rival reaching the target first ends the audience as a player loss.
- **R-21 Courtier personalities.** Each courtier definition sets preferred colors, stitch pool, intent logic (§7), and one ability, e.g., `the_whisperer` (blue patterns also discard a card from your hand), `the_gilded_duke` (gold threads), `the_seamstress` (rarely overstitches but uses knots), `the_rake` (overstitches freely; its Scandal threshold is high).

### 4.6 Scandal

- **R-22 Scandal.** Scandal is tracked per audience for each participant. At 5 Scandal the participant suffers **Gossip** (−1 card draw next turn); at 10, **Disgrace** (the participant immediately loses the audience; for rivals, they withdraw and their threads remain).
- **R-23 Scandal reduction.** Some cards and patronage reduce Scandal; yellow patterns of size ≥ 6 reduce the claimant's Scandal by 2.

### 4.7 Between Audiences

- **R-24 Rewards.** Winning an audience grants a card draft (choose 1 of 3 thread cards), Favor, and, at elite audiences, a patronage (relic).
- **R-25 Dyer.** Spend Favor to change a card's color (red/blue/yellow → mixed costs 25 Favor; to gold costs 60).
- **R-26 Tailor.** Remove a card (cost 20 Favor, +10 each time this run).
- **R-27 Salons.** Upgrade a card (e.g., `single` → `couching`, or −1 needle) for 30 Favor or rest (+1 Standing, max 5).
- **R-28 Intrigue events.** Choice cards with deterministic outcomes using the run RNG.

### 4.8 Judgment and Victory

- **R-29 Judgment.** The season's final audience is judged by a ruling figure (`judges.json`) who imposes a rule (e.g., "only patterns of size ≥ 4 score," "Scandal thresholds halved," "gold threads are forbidden") and faces 2 rivals with a higher target.
- **R-30 Run victory.** Winning the third Judgment wins the run. Run score = total Influence earned + Favor remaining + 100 × Standing.

### 4.9 Edge Cases

- **R-31** A single placement can form patterns for multiple participants (e.g., completing a rival's line with your mixed thread when they hold the majority): each claimant resolves their own patterns; the combo mult applies per claimant.
- **R-32** If both the player and a rival would reach the target in the same round, the participant who reached it first in turn order wins.
- **R-33** Patterns that include a Disgraced participant's threads are claimed by the remaining owners by majority; if the Disgraced participant held the majority, the pattern is unclaimed.
- **R-34** Drawing from an empty deck shuffles the discard pile into the deck (seeded); if both are empty, no draw.

### 4.10 Invariants

- **INV-1** Every cell has ≤ 2 layers; knot threads never have a layer above them.
- **INV-2** A pattern instance is claimed at most once per audience.
- **INV-3** Influence never decreases except via explicit card effects (logged).
- **INV-4** Detector output is independent of scan order (shuffle templates, same result).
- **INV-5** Deck + hand + discard + exhausted = owned cards (conservation).
- **INV-6** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct AudienceState: Codable, Equatable, Hashable, Sendable {
    public var tapestry: Tapestry                 // [CellStack] 36, each [ThreadLayer] ≤ 2
    public var round: Int; public var candle: Int; public var target: Int
    public var influence: [Seat: Int]; public var scandal: [Seat: Int]
    public var intents: [Seat: Intent]; public var claimed: Set<PatternInstanceKey>
    public var hand: [CardInstance]; public var deck: [CardInstance]; public var discard: [CardInstance]
    public var needles: Int; public var judge: JudgeID?
}
public enum Action: Codable, Equatable, Sendable {
    case play(CardInstanceID, cells: [Cell], colorChoice: ThreadColor?), endTurn
    case chooseReward(Int), dye(CardInstanceID, to: ThreadColor), remove(CardInstanceID), upgrade(CardInstanceID)
    case moveTo(MapNodeID), chooseEvent(Int), rest
}
public enum Event: Codable, Equatable, Sendable {
    case woven(Seat, [Cell], ThreadColor, overstitched: Int), patternFormed(PatternInstanceKey, claimant: Seat?, base: Int, mult: Int)
    case influence(Seat, Int), secret(SecretEffect), favor(Int), scandal(Seat, Int), gossip(Seat), disgrace(Seat)
    case intentShown(Seat, Intent), intentCancelled(Seat), audienceEnded(AudienceResult), runEnded(RunResult)
}
```

### 5.2 Content Tables

**`cards.json`** — G3: 60 cards; G5: 100.

```json
{ "id": "woad_chain", "color": "blue", "stitch": "chain", "cost": 2, "rarity": "uncommon",
  "effects": [{ "onPattern": "blue", "addMult": 1 }], "upgrade": { "cost": 1 }, "artKey": "card_woad_chain" }
```

**`patterns.json`** — 9 templates with base values and cell offsets.

```json
{ "id": "rosette", "base": 70, "cells": [[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]], "anchorFree": true }
```

**`courtiers.json`** — G3: 10; G5: 16. **`judges.json`** — G3: 3; G5: 6 (two per season, one drawn per run). **`patronage.json`** — G3: 20; G5: 40. **`events.json`** — G3: 20; G5: 40.

```json
{ "id": "the_rake", "colors": { "red": 4, "orange": 2 }, "stitches": ["single", "weft", "chain"],
  "intentLogic": "hijack_highest", "ability": { "scandalThreshold": 14 }, "targetMul": 1.0 }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `audience.candle` | 8 | 6–10 | balance.json |
| `hand.size` / `needles` | 5 / 3 | 4–6 / 2–4 | balance.json |
| `scandal.gossip` / `disgrace` | 5 / 10 | 4–7 / 8–14 | balance.json |
| `overstitch.needleCost` | 1 | 1–2 | balance.json |
| Pattern base values | R-16 | ±40% | patterns.json |
| `combo.multPerExtraPattern` | 1 | 1–2 | balance.json |
| `combo.multCap` | 8 | 6–12 | balance.json |
| `favor.dyeMixed` / `dyeGold` / `remove` | 25 / 60 / 20 | ±50% | balance.json |
| Audience targets per row | 80 → 400 | tuned | balance.json |
| `standing.start` | 5 | 3–6 | balance.json |

**Target metrics (sims, ≥ 5,000 runs per bot):**

| Metric | Target |
| --- | --- |
| `PlayerBot.greedy` (ignores rivals) run win rate | 3–8% |
| `PlayerBot.aware` (blocks and hijacks) run win rate | 25–40% (pillar 1 gap) |
| `PlayerBot.expert` run win rate | 55–70% |
| Median audience length | 5–7 rounds |
| Placements forming ≥ 2 patterns (expert) | 20–35% (combos common but earned) |
| Card pick-rate floor (expert drafts) | each card ≥ 1% |
| Disgrace losses share (aware bot) | 5–15% |

## 7. AI Approach

| Component | Algorithm | Budget |
| --- | --- | --- |
| `RivalPolicy` | Each courtier scores candidate placements (all legal stitch placements of its next card) by own projected pattern value (lines one or two cells from completion weighted by template base), denial value (player's near-complete patterns blocked), and personality weights; picks the best as its **intent**, deterministically (ties by cell index) | ≤ 20 ms |
| Intent planning | The intent is computed at the start of the player's turn from the current board (so it is truthful); if the player blocks it, the fallback is recomputed at the rival's turn in the same region | ≤ 20 ms |
| Difficulty (Ascension) | 10 levels raising targets, rival Scandal thresholds, and adding elite rival abilities | — |
| `PlayerBot.greedy/aware/expert` | Greedy: maximize immediate own Influence. Aware: + denial and hijack terms. Expert: beam search (width 12) over the full turn's card sequence with a 1-round lookahead of telegraphed rival intents; drafting by a deck color-profile heuristic | sim only, ≤ 200 ms/turn |
| `MapGenerator` | Row-based court map with constraints (≥ 1 tailor and 1 dyer per season; elites not in row 1) | ≤ 20 ms |
| `DailyVerifier` | Daily weave seed: expert bot wins ≥ 2 of 6 runs | CI, ≤ 30 s |

**Determinism:** rival intent logic is deterministic given state; draws use the run RNG; bots use `SplitMix64(seed ^ botID)`.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **LMC-P0.1 Tapestry and cell stack types** with layer rules. Acceptance: INV-1 unit tests.
- **LMC-P0.2 Pattern template loader** with validation (cells within 6×6 under some anchor).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-34 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **LMC-P1.1 Stitches and placement (R-8–R-11, R-14).**
- **LMC-P1.2 Detector, claims, and combos (R-12, R-13, R-16, R-17, R-31).** Acceptance: ≥ 50 golden board fixtures with expected pattern lists and scores; INV-4 shuffle test.
- **LMC-P1.3 Color effects, Secrets, Favor (R-15).**
- **LMC-P1.4 Rivals and intents (R-18–R-21)** with a simple policy.
- **LMC-P1.5 Scandal (R-22, R-23, R-33).**
- **LMC-P1.6 Audience flow and candle (R-4–R-7, R-32, R-34).**
- **LMC-P1.7 Run structure (R-1–R-3, R-24–R-30).**
- **LMC-P1.8 Sim CLI** `Tools/sim --bot aware --runs 5000`.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 over 1,000 seeds
  [ ] LMCCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: season 1 only, 30 cards, 4 courtiers, 1 judge, 10 patronages.

- **LMC-P2.1 Loom scene.** Tapestry with layered threads, owner indicators (small selvedge marks), rival intent highlights with color and stitch icons.
- **LMC-P2.2 Playing cards.** Drag a card onto the tapestry; the stitch shape follows the finger and snaps; a preview shows patterns that would form with their score math (base × mult) before releasing; tap to rotate warp/weft. Mouse: drag, R rotate.
- **LMC-P2.3 Score ticker.** Patterns resolve one by one with the base and mult counting up.
- **LMC-P2.4 Court map, rewards, dyer, tailor, and salon screens.**
- **LMC-P2.5 Candle HUD** (rounds remaining), Influence bars per participant, Scandal meters.

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest completes season 1 (scripted) to the Judgment result on iPad and Mac
  [ ] Placement preview equals the engine's resolution for 200 random placements
  [ ] Save and resume mid-audience to identical hash
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — are shared-board decisions double-edged? Are combos satisfying?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **LMC-P3.1** 100 cards, 16 courtiers, 6 judges, 40 patronages, 40 events.
- **LMC-P3.2** Seasons 2 and 3 with escalating targets.
- **LMC-P3.3** Tutorial: three guided audiences (lines and claims, overstitch and scandal, combos and hijacks).
- **LMC-P3.4** Compendium: cards, courtiers, and judges discovered.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts met; content-lint 0 errors; tutorial UI test passes
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **LMC-P4.1** Courtier policies with personalities; truthful intents and fallbacks.
- **LMC-P4.2** PlayerBot tiers; `make balance` → `docs/BALANCE.md`.
- **LMC-P4.3** Balance iteration within §6 ranges (log each change with before/after sims).

```
GATE G4 — AI
Checks:
  [ ] 5,000 runs per bot: 0 crashes, 0 illegal actions; intents executed as shown in 100% of cases where legal
  [ ] Targets in §6 met (especially the greedy vs aware gap)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **LMC-P5.1** Ascension (10 levels).
- **LMC-P5.2** Daily Weave (UTC seed; fixed starting deck variant and map).
- **LMC-P5.3** Gallery: each audience's final tapestry saved as an image-ready snapshot (rendered in P6 style).
- **LMC-P5.4** Unlocks: starting decks (four "houses" with different color profiles) unlock by wins; all earnable.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Daily weaves deterministic and verified for 60 dates
  [ ] All standard tests and coverage thresholds pass; docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **LMC-P6.1** Final weave textures per color and stitch, sheen shader, scandal stains, pattern border embroidery.
- **LMC-P6.2** Card art (spools and swatches) and courtier portraits in tapestry style.
- **LMC-P6.3** Music and SFX; haptics.

```
GATE G6 — Aesthetics
Checks:
  [ ] Colors distinguishable at iPhone size in 10 random boards (Grok)
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **LMC-P7.1 Pencil.** Draw a stitch path with Pencil (chain stitches follow the stroke); hover over a cell previews formed patterns; squeeze opens the deck viewer. Finishing embroidery: an optional signature stitched on gallery tapestries.
- **LMC-P7.2 Game Center.** Daily leaderboard, achievements, challenges.
- **LMC-P7.3 iCloud** sync of runs and gallery.
- **LMC-P7.4 Mac.** Number keys select cards, click to place, Space ends turn.

```
GATE G7 — Platform
Checks:
  [ ] Pencil paths produce the same Actions as drag placement
  [ ] Game Center sandbox and iCloud round trips
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **LMC-P8.1** Color-blind support: each color has a distinct weave pattern (red twill, blue basket, yellow satin), and mixed colors combine their patterns; symbols option.
- **LMC-P8.2** VoiceOver for the tapestry (row and column readouts) and score math.
- **LMC-P8.3** Reduce Motion: no ripples; ticker instant.

```
GATE G8 — Polish
Checks:
  [ ] Full audience playable with VoiceOver (UI test)
  [ ] Budgets met on real devices
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight (Mahler creates records); crash-free ≥ 99.5%
  [ ] Tester first-season clear rate 30–60%
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview shows a combo hijack and the final tapestry of a run.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** claim resolution with mixed and gold threads (R-11, R-13, R-31) and pattern upgrade rules (R-17).
- **Balance hot spots:** gold threads, couching doubles, and combo mult growth.
- **First tasks:** Grok — card pool and courtier tuning; Claude — weave rendering legibility on iPhone.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too close to Balatro or match-3 in feel | Medium | Medium | Shared-board rivalry and hijacks are the identity | GROK |
| Color legibility | Medium | High | Weave patterns per color, symbols option | CLAUDE |
| Combo explosions break balance | Medium | Medium | Integer caps on mult per resolution (max 8, tunable) | GLM |
| Rivals feel scripted | Low | Medium | Personalities and fallback logic | GROK |

## 11. Out of Scope

- Multiplayer.
- Narrative campaign with branching story (events are standalone).
- Free-form tapestry painting mode (post-launch idea).
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 8–11 |
| P2 Vertical Slice | GLM | 8–11 |
| P3 Content and Systems | GLM | 10–14 |
| P4 AI | GLM | 5–8 |
| P5 Meta | GLM | 3–5 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 10–14 |
| P7 Platform | CLAUDE | 3–5 |
| P8 Polish | CLAUDE | 4–6 |
| P9 Beta | GROK + CLAUDE | 5–8 |
| P10 Release | CLAUDE + GROK | 2–3 |
| **Total** | | **60–88** |

## 13. Open Questions for Mahler

1. Three seasons per run? **Default:** yes.
2. Should the combo mult be capped? **Default:** yes, max ×8 per resolution.
3. Court setting: fictional realm or a historical court? **Default:** fictional realm with medieval textile craft.
4. Gallery image export via the share sheet? **Default:** yes.
5. Price? **Default:** Mahler decides in P10.
