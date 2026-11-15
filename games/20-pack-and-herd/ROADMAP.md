# 20 — Pack & Herd Roadmap

> An asymmetric predator-and-prey duel across a mountain valley, with one player as the wolf pack and the other as the elk herd.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Pack & Herd.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 20 · `pack-and-herd` |
| Code prefix | `PKH` (packages `PKHCore`, `PKHContent`, `PKHAI`, `PKHRender`, `PKHAudio`, `PKHPlatform`, `PKHMeta`) |
| Bundle ID (placeholder) | `com.zyniker.pack-and-herd` |
| Subgenre | Asymmetric hidden-information tactics |
| Difficulty tier | Intermediate |
| Scope | Solo-indie |
| Session length | 20–30 min (one year: 4 seasons × 3 turns) |
| Renderer | SpriteKit (2D) with a woodcut-print shader (`SKShader` for carved line texture and paper grain) |
| Players | Solo vs AI (either side), local pass-and-play with hidden information; no online play in v1.0 |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** An asymmetric predator-and-prey duel across a mountain valley, with one player as the wolf pack and the other as the elk herd.

**Summary:** A hex valley of meadows, forests, ridges, river, and snowfields hosts a wolf pack (5 wolves and a den with pups) and an elk herd (12–14 elk in three bands with bulls, cows, and calves). Over one year of four seasons (three turns each), the sides alternate turns with different action economies. Wolves are fast, few, and need to feed the den; they see far from ridges and can follow scent trails. Elk are many and slow, need to graze, and are strongest in tight bands where bulls guard calves. Each side sees only what its animals can see or smell. Snow deepens through winter and hurts elk more than wolves. The wolf player scores by food brought to the den and pups raised; the elk player scores by calves raised to yearlings and adults surviving. Only one side wins.

**Pillars:**

1. **Different games on one board.** Wolves and elk must feel unlike each other within the first turn: different verbs, different tempo, and different information.
2. **Fog is the battlefield.** Most decisions depend on what you believe the other side is doing; scent and sightlines create inference, not guessing.
3. **The ecology is the clock.** Seasons change the rules (calving, rut, and snow) and force each side to act.
4. **Honest predation.** Hunts are rare, tense, and readable; odds are shown before committing. No gore: woodcut abstraction.
5. **Balanced asymmetry.** Equal-skill AI plays win 45–55% for each side.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Bone white `#F2EDE3`, ink black `#141414`, gray ink `#5C5A57` (for remembered/out-of-sight), single red `#B3261E` (only for hunts, danger, and the den), snow tint `#E6EEF2` |
| Shapes | Woodcut linework with carved hatching for terrain; animals as bold silhouettes with one identifying mark (bulls' antlers, calves smaller, alpha wolf with a notch) |
| Typography | A heavy slab or woodtype face for titles (default New York Heavy), SF Pro for UI |
| Motion | Stamp-like transitions (prints pressing onto paper); snow accumulates as carved stipple |
| Music | Minimal: wind, a low bowed drone, a distant howl motif for wolves, low horn motif for elk |
| SFX | Hooves, crunching snow, howls (directional), alarm barks of elk, wind |
| Haptics | Soft pulse when a scent trail is found; heavy for a hunt result |

**Inspirations:** Root's asymmetry, Polytopia's pass-and-play, and hidden-movement board games.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit with a woodcut post shader; hidden information is rendered from a per-side `Observation` produced by Core (Render never sees the full state during a human player's turn).
- **Hex grid:** axial, default 15×11.
- **Pass-and-play privacy:** hand-over screens between turns; the renderer swaps observations; screenshots and app switcher snapshots during turns are blurred by a privacy overlay.
- **AI:** Information Set Monte Carlo Tree Search (ISMCTS) with determinization from a belief model.

ADRs to create in P0:

- ADR-0003 Per-side `Observation` boundary between Core and Render.
- ADR-0004 ISMCTS for AI.
- ADR-0005 Privacy overlay for pass-and-play.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── PKHCore/Sources/PKHCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Hex.swift, LineOfSight.swift
│   ├── Valley/       Valley.swift, Terrain.swift (meadow, forest, ridge, river, scree, snowfield, den), Snow.swift, Forage.swift
│   ├── Animals/      Wolf.swift, Elk.swift, Band.swift, Condition.swift, Pups.swift
│   ├── Senses/       Sight.swift, Scent.swift (trails with age), Observation.swift, Memory.swift
│   ├── Actions/      WolfActions.swift, ElkActions.swift, ActionPoints.swift
│   ├── Hunt/         Hunt.swift, Odds.swift, Defense.swift
│   ├── Seasons/      Calendar.swift, SeasonRules.swift (calving, summer, rut, winter)
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift, Score.swift
├── PKHContent/       ValleyTemplate.swift, SeasonDef.swift, PersonalityDef.swift, Loader.swift
├── PKHAI/            BeliefModel.swift, Determinizer.swift, ISMCTS.swift, WolfPolicy.swift, ElkPolicy.swift, Personality.swift, ValleyGenerator.swift
├── PKHRender/        ValleyScene.swift, AnimalNode.swift, ScentOverlay.swift, SightOverlay.swift, HandOverView.swift, Shaders/woodcut.fsh
├── PKHAudio/         Ambience.swift, Howl.swift
├── PKHPlatform/      PrivacyOverlay.swift, GameCenterService.swift, CloudSaveService.swift, PencilAdapter.swift
└── PKHMeta/          Progression.swift, DailyValley.swift, Stats.swift, FieldJournal.swift
Resources/Content/    valleys/*.json, seasons.json, personalities.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Setup

- **R-1 Valley.** Hex grid (default 15×11) with terrain: `meadow` (forage 3), `forest` (forage 1, blocks sight, cover), `ridge` (sight +2, elk move cost 2), `river` (crossing costs all remaining movement; scent ends), `scree` (move cost 2 both sides), `snowfield` (seasonal; see R-30), and one `den` hex (wolves only).
- **R-2 Pack.** 5 wolves (one alpha) start at the den; den holds 4 pups (born at game start, spring).
- **R-3 Herd.** 13 elk in 3 bands: 3 bulls, 7 cows, 3 yearlings at setup; calves are born in spring turn 2 (R-27). Bands start in meadow hexes at least 6 hexes from the den.
- **R-4 Turn order.** Each turn the elk move first, then the wolves (wolves are the reactive hunters). A season has 3 turns; the game has 4 seasons (spring, summer, autumn, winter) = 12 turns.

### 4.2 Senses and Information

- **R-5 Sight.** Each animal sees hexes within its sight radius (wolf 3, elk 2; +2 from a ridge) with line of sight not blocked by forest (forest hexes are visible but not seen through). A hex seen by any friendly animal is **visible** this turn.
- **R-6 Observation.** Each side receives an `Observation`: own animals fully; enemy animals only in visible hexes; terrain fully; snow depth fully; scent per R-7; and last-seen markers for enemy animals with the turn they were seen.
- **R-7 Scent.** Every animal leaves a scent mark in each hex it ends a move in and every hex it passes through, with age 0. Ages increase by 1 each turn; marks vanish at age 4 (wolf scent) or 3 (elk scent), and immediately in river hexes. Wolves smell elk scent within 1 hex of any wolf (radius 2 for the alpha), reading the band ID and the age. Elk smell wolf scent only in hexes they occupy, reading only age.
- **R-8 Alarm.** If any elk sees a wolf, every elk within 3 hexes becomes **alarmed** (R-21) and the herd's Observation includes the wolf's position for the next wolf turn as a last-seen marker.

### 4.3 Elk Actions

- **R-9 Bands.** Elk act by band. A band is a set of elk in contiguous hexes (each elk within 1 hex of another band member). Bands may split or merge as an action.
- **R-10 Herd action points.** The elk player has 6 action points (AP) per turn (spring 7: calving restlessness, winter 5).
- **R-11 Elk actions.** `moveBand` (1 AP: every elk in the band moves up to 2 hexes, staying contiguous; costs per terrain; deep snow per R-30), `graze` (1 AP: every elk in the band in meadow gains +1 condition, or +2 if the meadow forage ≥ 3; reduces forage by 1), `watch` (1 AP: band sight +1 and alarmed next wolf turn), `split` (1 AP: divide a band into two contiguous groups), `merge` (0 AP if adjacent), `ford` (2 AP: band crosses a river hex adjacent to it).
- **R-12 Band limit.** Each band may take at most 2 actions per turn, and at most 1 `moveBand`.
- **R-13 Condition.** Elk condition 0–6 (start 4). Each turn without grazing costs −1 in winter only; in autumn rut, bulls lose −1 per turn regardless (rut exhaustion). At 0 an elk dies (winter attrition).

### 4.4 Wolf Actions

- **R-14 Wolf action points.** Each wolf has 3 movement points (MP) per turn plus one **action** (`scout`, `track`, `rest`, `howl`, or `hunt`). The alpha has 4 MP.
- **R-15 Movement.** Terrain costs: meadow, forest, ridge 1; scree 2; river crossing ends movement; snow per R-30 (wolves pay less).
- **R-16 Scout.** On a ridge, sight +1 more this turn (stacks with R-5).
- **R-17 Track.** Choose an elk scent mark within 1 hex; learn the band's current hex if that band's newest mark is ≤ 1 turn old; otherwise learn the direction (one of 6) of the newest mark of that band.
- **R-18 Howl.** All wolves within 6 hexes may move 1 extra hex this turn (coordinate); every elk within 5 hexes becomes alarmed (trade-off).
- **R-19 Rest.** +1 wolf condition (wolves have condition 0–5, start 4; −1 per turn in winter, −1 per turn without eating for 2 consecutive turns).

### 4.5 Hunts

- **R-20 Hunt declaration.** A wolf adjacent to an elk may declare `hunt` on that elk. All other wolves adjacent to the same elk may **join** (they spend their action). The hunt resolves immediately in the wolf turn.
- **R-21 Hunt odds.** Success chance = `base[target] + 10% × (wolves − 1) + terrain + snow + condition − defense`, clamped 5–85%, shown before confirming:
  - `base`: calf 45%, yearling 35%, cow 25%, bull 10%.
  - `terrain`: forest +5% (ambush), meadow 0, ridge −5%, scree −10%.
  - `snow`: deep snow +15%, crusted snow +5%.
  - `condition`: +5% per point the target's condition is below 3.
  - `defense`: −10% per bull adjacent to the target (max −30%), −10% if the target's band is alarmed, −5% per adjacent cow when the target is a calf (max −15%).
- **R-22 Hunt results.** Success: the elk is killed; the hunting wolves gain +2 condition each and the hex becomes a **carcass** with 6 food (carried to the den by R-24). Failure: each hunting wolf loses 1 condition; a bull adjacent to the target **charges**: roll 25% per bull to injure one hunting wolf (wolf condition −2; injured wolves have 2 MP next turn).
- **R-23 One hunt per elk per turn.** An elk survives at most one hunt attempt per wolf turn; after an attempt (success or failure), all elk within 2 hexes become alarmed.

### 4.6 The Den and Food

- **R-24 Carrying food.** A wolf on a carcass hex may pick up 2 food (its action); carrying wolves have −1 MP. Dropping food at the den adds it to den food. A carcass loses 1 food per turn (scavengers) and vanishes at 0.
- **R-25 Pups.** At each season end, pups consume 1 food each from den food. A pup without food loses a health point (pups have 2); at 0 the pup dies. At game end, surviving pups count as raised.
- **R-26 Wolf starvation.** A wolf at condition 0 leaves the pack (removed).

### 4.7 Seasons

- **R-27 Spring.** Turn 2: each cow in a band with a bull present gives birth to one calf (max 7 calves), placed adjacent. Calves move with their band but cost the band +1 movement cost on ridges and scree.
- **R-28 Summer.** Meadow forage regrows +1 per turn (max 4). Elk sight +1 (open country).
- **R-29 Autumn (rut).** Bulls lose condition (R-13); a band with 2+ bulls must split one bull off as its own band at the start of each elk turn unless it spends 1 AP (`calm`). Elk calves become yearlings at the end of autumn (count as raised).
- **R-30 Winter and snow.** At winter's start, snowfield hexes become deep snow, and every meadow and forest hex above elevation 2 gains snow depth 1; each winter turn snow depth +1 up to 3 on those hexes. Elk movement cost +1 per depth (deep = 3); wolves +1 only at depth 3, or 0 if the snow is **crusted** (a cold-night event, 1-in-3 chance per winter turn from the season RNG; crust lasts one turn). Forage in snow hexes is 0 unless an elk band spends 1 AP to `paw` (forage 1).

### 4.8 Scoring and Victory

- **R-31 Wolf score.** `2 × pups raised + den food remaining / 3 (floor) + 1 per wolf alive`.
- **R-32 Elk score.** `2 × calves raised to yearlings + 1 per adult elk alive`.
- **R-33 Normalization.** Raw scores are compared through the valley template's par values (`parWolf`, `parElk`) tuned by sims so equal-skill play ties: final margin = `wolfScore / parWolf − elkScore / parElk`. Positive: wolves win; negative: elk win; |margin| < 0.03: draw.
- **R-34 Early end.** If all pups die, the elk win immediately. If the herd falls below 4 adults, the wolves win immediately.

### 4.9 Edge Cases

- **R-35** An elk band that becomes non-contiguous due to a death is split automatically into contiguous bands (lowest elk ID keeps the band ID).
- **R-36** A hunt on an elk in a river hex has −20% and failure means the wolf is swept 1 hex downstream.
- **R-37** Wolves cannot enter a hex with an elk; elk cannot enter a hex with a wolf.
- **R-38** If a band has no legal move (surrounded), `moveBand` is unavailable for it; it may still graze, watch, or split.

### 4.10 Invariants

- **INV-1** One animal per hex (R-37 plus elk/elk and wolf/wolf exclusivity).
- **INV-2** Observations never include an enemy animal in a non-visible hex (tested by diffing Observation against the visibility mask, 1,000 random states).
- **INV-3** AI decisions for a side depend only on that side's Observation history (enforced by API: AI functions take `ObservationHistory`, not `GameState`).
- **INV-4** Condition values within bounds; food ≥ 0.
- **INV-5** Every band is contiguous at turn end.
- **INV-6** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var turn: Int; public var season: Season; public var active: Side; public var rng: SeededRNG
    public var valley: Valley; public var snow: [UInt8]; public var forage: [UInt8]
    public var wolves: [WolfID: Wolf]; public var elk: [ElkID: Elk]; public var bands: [BandID: Set<ElkID>]
    public var scent: [Hex: [ScentMark]]; public var carcasses: [Hex: Int]
    public var den: Den; public var elkAP: Int; public var alarmed: Set<ElkID>
}
public struct Observation: Codable, Equatable, Hashable, Sendable {
    public var side: Side; public var turn: Int
    public var own: OwnUnits; public var visibleEnemies: [EnemySighting]; public var lastSeen: [EnemySighting]
    public var scent: [Hex: [ScentReading]]; public var terrain: TerrainSnapshot
}
public enum Action: Codable, Equatable, Sendable {
    case elk(ElkAction)    // moveBand(BandID, path), graze(BandID), watch(BandID), split(BandID, Set<ElkID>), merge(BandID, BandID), ford(BandID, Hex), paw(BandID), calm(BandID)
    case wolf(WolfAction)  // move(WolfID, path), scout(WolfID), track(WolfID, Hex), howl(WolfID), rest(WolfID), hunt(WolfID, ElkID, joiners: [WolfID]), pickUp(WolfID), drop(WolfID)
    case endTurn
}
public enum Event: Codable, Equatable, Sendable {
    case moved(Unit, [Hex]), sighted(by: Side, Unit, Hex), alarmed([ElkID]), tracked(WolfID, Reading)
    case huntResolved(target: ElkID, wolves: [WolfID], odds: Int, success: Bool, injuries: [WolfID])
    case born([ElkID]), died(Unit, cause: Cause), snowChanged, seasonChanged(Season), gameEnded(Result)
}
```

### 5.2 Content Tables

**`valleys/*.json`** — G3: 4 handcrafted; G5: 8 handcrafted + generator. Each includes par values.

```json
{ "id": "high_meadow", "size": [15, 11], "terrain": "base64", "elevation": "base64",
  "den": [2, 8], "elkStart": [[10,3],[11,4],[12,2]], "parWolf": 11.5, "parElk": 14.0 }
```

**`seasons.json`** — 4 rows (AP, sight modifiers, special rules flags).

**`personalities.json`** — G4: 3 per side.

```json
{ "id": "wolf_patient", "side": "wolf", "weights": { "huntThreshold": 40, "scoutBias": 1.5, "denReturnBias": 1.2 } }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `elk.ap` (spring/summer/autumn/winter) | 7/6/6/5 | ±1 | seasons.json |
| `wolf.mp` / alpha | 3 / 4 | 2–4 / 3–5 | balance.json |
| `hunt.base` per age class | 45/35/25/10 | ±10 | balance.json |
| `hunt.perExtraWolf` | 10% | 5–15% | balance.json |
| `hunt.bullDefense` | 10% | 5–15% | balance.json |
| `scent.ageMax` wolf/elk | 4 / 3 | 2–5 | balance.json |
| `sight.wolf` / `elk` | 3 / 2 | 2–4 / 1–3 | balance.json |
| `carcass.food` | 6 | 4–8 | balance.json |
| `pups.count` | 4 | 3–5 | balance.json |
| Par values per valley | per file | tuned by sims | valleys/*.json |

**Target metrics (sims, ≥ 2,000 games per valley per pairing):**

| Metric | Target |
| --- | --- |
| Equal-tier AI, wolf side win rate | 45–55% per valley |
| Draws | ≤ 8% |
| Hunts attempted per game | 6–12 |
| Hunt success rate | 30–45% |
| Calves killed share of kills | 35–55% |
| Games ending early (R-34) | ≤ 15% |
| Hard vs medium (either side) | 65–80% |

## 7. AI Approach

Hidden information on both sides: AI uses ISMCTS over determinized states sampled from a belief model.

| Tier | Algorithm | Budget (iPad A16, p95) |
| --- | --- | --- |
| `cub` / `calf` (easy) | Rule-based policies: wolves follow freshest scent and hunt at ≥ 35% odds; elk graze the best meadow and flee alarms | 50 ms |
| `hunter` / `matriarch` (medium) | ISMCTS, 1,500 iterations, 8 determinizations, rollouts with the easy policies, horizon to end of next season | 800 ms |
| `alpha` / `old_bull` (hard) | ISMCTS, 5,000 iterations, 24 determinizations, progressive widening on action sets, a learned-by-hand evaluation at horizon (no ML), plus belief refinement by scent age | 1,500 ms |

**Belief model:** for each unseen enemy unit or band, maintain a probability grid over hexes updated by movement possibilities (diffusion constrained by terrain and costs), last sightings, scent readings, and alarm events; determinizations sample positions from these grids consistently (bands remain contiguous).

**Action abstraction:** wolf moves are reduced to destination hexes from a candidate set (scent hexes, ridges, ambush forests, den, carcasses); elk band moves to the 6 best destinations by forage and safety.

**Evaluation features:** projected score margin (R-33), pups' food runway, calves' exposure (distance to nearest likely wolf × bull cover), herd condition before winter, and wolf condition.

**Determinism:** AI RNG from `SplitMix64(seed ^ side ^ turn)`; AI APIs accept only `ObservationHistory` (INV-3).

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **PKH-P0.1 Hex and line-of-sight utilities** with forest blocking and ridge bonuses. Acceptance: known-answer tests.
- **PKH-P0.2 Observation API skeleton** that Render consumes (no full-state access from Render; enforced by module visibility).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-38 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **PKH-P1.1 Senses: sight, scent, alarm, and Observation (R-5–R-8).** Acceptance: INV-2 property test.
- **PKH-P1.2 Elk actions and bands (R-9–R-13, R-35, R-38).**
- **PKH-P1.3 Wolf actions (R-14–R-19).**
- **PKH-P1.4 Hunts (R-20–R-23, R-36).** Acceptance: odds formula table tests (≥ 30 cases); success frequencies within ±1% over 100,000 trials.
- **PKH-P1.5 Den, food, pups, and starvation (R-24–R-26).**
- **PKH-P1.6 Seasons and snow (R-27–R-30).**
- **PKH-P1.7 Scoring and early end (R-31–R-34).**
- **PKH-P1.8 Sim CLI** with random-legal and easy policies.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 over 1,000 seeds
  [ ] PKHCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: `high_meadow`, full year, easy AI on both sides (play either), pass-and-play.

- **PKH-P2.1 Valley scene** with woodcut placeholder; out-of-sight areas printed in gray ink; last-seen ghost markers with turn age.
- **PKH-P2.2 Elk controls.** Tap a band to select (whole band highlights), drag to a destination (path preview with cost), action buttons for graze, watch, split (lasso elk with a finger), and merge. AP shown as antler tokens.
- **PKH-P2.3 Wolf controls.** Tap a wolf, drag to move (MP pips), action radial (scout, track, howl, rest, hunt). Hunt shows odds breakdown before confirming.
- **PKH-P2.4 Scent overlay.** Wolves see colored-by-age elk trails (gray tones; red only for very fresh); elk see faint wolf marks under their own hexes.
- **PKH-P2.5 Pass-and-play hand-over** with privacy overlay.
- **PKH-P2.6 Season transitions** and a year summary.

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays a full year as elk and as wolves vs easy AI on iPad and Mac
  [ ] Render cannot access GameState (compile-time module boundary test)
  [ ] Pass-and-play hand-over hides the board and blurs snapshots
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — do the two sides feel distinct? Is inference rewarding?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **PKH-P3.1** 8 valleys with par values; `ValleyGenerator` (river by downhill walk, forest clusters, ridges, den placement constraints).
- **PKH-P3.2** Two tutorials (one per side), 5 short lessons each.
- **PKH-P3.3** Field journal: per-game timeline of sightings and hunts, revealed fully after the game ("what really happened" replay with full information).

```
GATE G3 — Content and Systems
Checks:
  [ ] 8 valleys; content-lint 0 errors; tutorials pass UI tests
  [ ] Post-game full-information replay matches the recorded game hash
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **PKH-P4.1** Belief model and determinizer; test that sampled positions are always consistent with the Observation history (no sample places an enemy in a hex observed empty this turn).
- **PKH-P4.2** ISMCTS tiers and personalities.
- **PKH-P4.3** Par tuning: `make par` runs medium-vs-medium sims per valley and writes par values so the wolf win rate is 50% ± 3%.
- **PKH-P4.4** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] 2,000 games per tier pairing per valley: 0 crashes, 0 illegal actions
  [ ] INV-3 enforced (AI API takes ObservationHistory only; compile-time check)
  [ ] Targets in §6 met; p95 think time within budgets (CI scaled)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **PKH-P5.1** Daily Valley: date-derived procedural valley; player plays both sides vs hard AI (two scores combined).
- **PKH-P5.2** Seasonal modifiers (e.g., `mild_winter`, `drought_summer`, `big_litter`) selectable or random.
- **PKH-P5.3** Unlocks: valleys and modifiers by wins on each side; all earnable.
- **PKH-P5.4** Stats per side.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Daily valleys deterministic for 60 dates; par computed for each in CI
  [ ] All standard tests and coverage thresholds pass
  [ ] docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **PKH-P6.1** Final woodcut art for terrain, animals, snow states, and season palettes (still black, bone, and one red).
- **PKH-P6.2** Print-press transitions; hunt vignettes (abstract, non-graphic).
- **PKH-P6.3** Sound: directional howls, hooves, wind; side-specific music motifs.

```
GATE G6 — Aesthetics
Checks:
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **PKH-P7.1 Pencil.** Annotate the map with private notes per side (stored in that side's observation history, hidden on hand-over); hover previews paths and hunt odds.
- **PKH-P7.2 Game Center.** Daily leaderboard, achievements per side, challenges.
- **PKH-P7.3 iCloud** saves.
- **PKH-P7.4 Mac.** Keyboard: Tab cycles units, arrow keys move selection, H hunt, Return end turn.

```
GATE G7 — Platform
Checks:
  [ ] Notes never visible to the other side (UI test)
  [ ] Game Center sandbox and iCloud round trips
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **PKH-P8.1** Visibility encoded by texture as well as tone (gray ink plus stipple for unseen).
- **PKH-P8.2** VoiceOver: unit summaries, band contents, odds readouts.
- **PKH-P8.3** Real-device AI budgets.

```
GATE G8 — Polish
Checks:
  [ ] Budgets met on real devices; accessibility audit clean
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight (Mahler creates records); crash-free ≥ 99.5%
  [ ] Tester win rates by side within 40–60% vs medium AI
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; age rating draft notes non-graphic predation; preview shows a tracking sequence and a hunt from both perspectives.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** the Observation boundary (any leak breaks the game); belief-model consistency; par values per valley after any rule change (rerun `make par`).
- **First tasks:** Grok — side balance and hunt odds feel; Claude — privacy overlay audit and AI performance on A16.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| One side dominates | Medium | High | Par normalization and sims per valley | GLM → GROK |
| Hidden info feels like guessing | Medium | High | Scent ages, tracking, last-seen markers, post-game reveal | GROK |
| Predation upsetting for some players | Low | Medium | Abstract woodcut vignettes; no blood; age rating honest | GROK |
| ISMCTS too slow | Medium | Medium | Action abstraction, adaptive iterations | GLM |

## 11. Out of Scope

- Online multiplayer (hidden information makes GameKit matchData cheating easy; revisit with commit schemes after launch).
- Additional species (bears, cougars) in v1.0.
- Real-time play.
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 8–11 |
| P2 Vertical Slice | GLM | 7–10 |
| P3 Content and Systems | GLM | 5–8 |
| P4 AI | GLM | 8–12 |
| P5 Meta | GLM | 3–5 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 8–12 |
| P7 Platform | CLAUDE | 3–5 |
| P8 Polish | CLAUDE | 4–6 |
| P9 Beta | GROK + CLAUDE | 5–8 |
| P10 Release | CLAUDE + GROK | 2–3 |
| **Total** | | **55–83** |

## 13. Open Questions for Mahler

1. One year per game (12 turns)? **Default:** yes, with a two-year "long" setting.
2. Online async play post-launch? **Default:** not in v1.0.
3. Daily Valley as both sides combined? **Default:** yes.
4. Should players name wolves and elk? **Default:** auto-named with optional renaming in the field journal.
5. Price? **Default:** Mahler decides in P10.
