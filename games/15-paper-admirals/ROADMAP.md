# 15 — Paper Admirals Roadmap

> Simultaneous-order naval battles on a folded-paper sea, where wind, current, and the creases of the map decide who holds the weather gauge.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Paper Admirals.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 15 · `paper-admirals` |
| Code prefix | `PAD` (packages `PADCore`, `PADContent`, `PADAI`, `PADRender`, `PADAudio`, `PADPlatform`, `PADMeta`) |
| Bundle ID (placeholder) | `com.zyniker.paper-admirals` |
| Subgenre | Simultaneous-turn fleet tactics with a short campaign |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 10–20 min per battle; campaign 2–3 hours over 8 battles |
| Renderer | SpriteKit (2D, top-down hex sea) + `SKShader` for paper creases and ink-wash water; no Metal compute |
| Players | Solo vs AI (skirmish and campaign), local pass-and-play, async online via GameKit turn-based matches (commit-reveal) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Simultaneous-order naval battles on a folded-paper sea, where wind, current, and the creases of the map decide who holds the weather gauge.

**Summary:** Two admirals each command three to seven origami ships on a hex sea printed on washi paper. Each turn both sides secretly plot a course and a shot type for every ship, then orders resolve together across six impulses: ships sail, turn, fire broadsides, grapple, and board. Wind direction sets how fast each ship can sail on each heading, and the upwind side (the weather gauge) chooses when to engage. The paper's fold lines matter: valley folds are currents that carry ships, and mountain folds are paper ridges that block cannon fire. Between battles, a short campaign manages crews, repairs, and fleet purchases on a chart of islands.

**Pillars:**

1. **Read the other admiral.** The main skill is predicting simultaneous orders. If an expert can beat a perfect-information version of the AI by the same margin as the simultaneous version, the pillar fails.
2. **Wind is the terrain.** Every battle's shape comes from wind and folds. A reviewer should be able to explain who has the weather gauge from one screenshot.
3. **Plot in seconds, watch with pleasure.** Plotting a 5-ship turn takes under 45 seconds for an experienced player; the resolution playback is the spectacle.
4. **Damage tells a story.** Every ship shows where it is hurt (hull, rigging, crew, or rudder), and the hurt changes how it sails.
5. **Fair async.** Neither side can learn the other's orders before committing, even by inspecting match data.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Washi paper `#EFE6D2`, paper shadow `#D8CCB0`, indigo sea ink `#2E3F6E` (wash at 15–45% alpha), deep indigo `#1C2647`, persimmon `#E06A3A` (player one), sumi black `#1E1E1E` (player two outlines), gold accent `#C9A24A`, smoke `#8D8A84` |
| Shapes | Ships as folded paper models with visible facets (3 tones per sprite); hexes drawn as faint ink grid that fades at zoom-out; folds as crease lines with a soft shading gradient |
| Typography | Brush-style display face for titles (open question Q2; default: a licensed-free serif such as New York Large), SF Pro for UI |
| Motion | Ships bob and tilt with heel angle by point of sail; cannon smoke as ink blooms that spread and fade; sunk ships unfold flat and sink |
| Music | Taiko and shakuhachi; tension layer rises during resolution impulses; calm koto in plotting |
| SFX | Paper rustle on plot, brush stroke on course drawing, cannon as deep taiko hit plus paper tear on damage, splash, boarding shouts (non-verbal) |
| Haptics | Soft tick per waypoint snap; heavy hit when your ship takes hull damage; rising pattern on boarding |

**Inspirations:** ROME: Total War's path drawing, Warbits+ legibility, and simultaneous-turn tactics games; Polytopia's pass-and-play.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit top-down. Water is an `SKShader` blending two ink-wash textures by world position; creases are a normal-map-like shading strip per fold line.
- **Grid:** Hex grid, pointy-top, axial coordinates `(q, r)`. Default 17×13. Six headings (0 = north-east … numbered clockwise; see R-2).
- **Simultaneous resolution:** six impulses per turn; integer math only. Hit rolls use the turn RNG, which is derived deterministically from the match seed and the turn number (so both async clients compute the same outcome).
- **Async online:** GameKit `GKTurnBasedMatch` with a commit-reveal protocol (R-50–R-54). Hashing uses CryptoKit SHA-256 inside `PADPlatform`; Core sees only plain orders and verifies a hash through an injected `HashVerifier` protocol.
- **Audio:** AVAudioEngine with stems (plotting, resolution, victory) and pooled SFX.

ADRs to create in P0:

- ADR-0003 Hex axial coordinates and heading numbering.
- ADR-0004 Six-impulse simultaneous resolution order.
- ADR-0005 Commit-reveal async protocol over GKTurnBasedMatch.
- ADR-0006 Turn RNG derivation `SplitMix64(matchSeed ^ turn * 0x9E3779B97F4A7C15)`.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── PADCore/Sources/PADCore/
│   ├── Foundation/     SeededRNG.swift, Fixed.swift, Hex.swift, Heading.swift
│   ├── Map/            SeaMap.swift, Fold.swift (valley/mountain), Island.swift, Shoal.swift
│   ├── Weather/        Wind.swift, PointOfSail.swift
│   ├── Ships/          Ship.swift, ShipClass.swift, Damage.swift (hull/rigging/crew/rudder), Morale.swift
│   ├── Orders/         Course.swift, ShotType.swift, ShipOrders.swift, FleetOrders.swift, OrderValidator.swift
│   ├── Resolution/     Impulse.swift, Movement.swift, Collision.swift, Gunnery.swift, Boarding.swift, Fire.swift
│   ├── Battle/         BattleState.swift, VictoryCheck.swift
│   ├── Campaign/       CampaignState.swift, Chart.swift, Port.swift, CrewVeterancy.swift, CampaignEvent.swift
│   ├── Protocol/       CommitRevealState.swift, HashVerifier.swift (protocol only)
│   └── Engine/         GameState.swift, Action.swift, Event.swift, Reducer.swift
├── PADContent/         ShipClassDef.swift, SeaMapTemplate.swift, CampaignEventDef.swift, CaptainTraitDef.swift, Loader.swift
├── PADAI/              CandidateGenerator.swift, OpponentModel.swift, Evaluator.swift, BestResponse.swift, Personality.swift
├── PADRender/          SeaScene.swift, ShipNode.swift, CourseDrawer.swift, PreviewGhosts.swift, InkSmoke.swift, Shaders/
├── PADAudio/           StemMixer.swift, Gunfire.swift
├── PADPlatform/        TurnBasedMatchService.swift, SHA256Verifier.swift, GameCenterService.swift, CloudSaveService.swift, PencilAdapter.swift
└── PADMeta/            Progression.swift, DailyBattle.swift, Stats.swift, Admiralty.swift (unlocks)
Resources/Content/      ship_classes.json, captain_traits.json, maps/*.json, campaign_events.json, campaign_chart.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Map, Wind, and Setup

- **R-1 Sea.** The battle map is a hex grid (default 17×13). Hex kinds: `sea`, `shoal` (impassable for ships of draft ≥ 2), `island` (impassable; blocks fire), and `edge` (leaving the map = ship disengaged, counts as retreat).
- **R-2 Headings.** There are six headings numbered 0–5 clockwise, with 0 pointing to the upper-right neighbor.
- **R-3 Wind.** Wind blows *from* one of six headings with strength 1–3. It is set at battle start from the map template and may shift by one heading at the start of turns listed in the template's `windShifts` (or randomly with 1-in-6 chance per turn on "fickle" maps, using the turn RNG).
- **R-4 Folds.** A fold is a straight line of hex edges or a hex row. **Valley folds** are currents: a ship ending an impulse on a valley-fold hex drifts one hex along the fold's direction at the end of impulse 6. **Mountain folds** are ridges: line of fire that crosses a mountain-fold hex edge is blocked.
- **R-5 Deployment.** Each side deploys its fleet in its deployment zone (two hex rows on opposite edges). Deployment is simultaneous and secret (commit-reveal online).
- **R-6 Weather gauge.** At each turn start, the side whose fleet centroid is more upwind (projected on the wind axis) holds the weather gauge. Ties: previous holder keeps it. The gauge holder wins initiative ties in R-22 and R-31.

### 4.2 Ships

- **R-7 Ship classes.** Each ship has a class with hull points, rigging points, crew, guns per broadside, base speed table by point of sail, turn cost, draft, and points cost (`ship_classes.json`).
- **R-8 Damage tracks.** A ship has four tracks: Hull, Rigging, Crew, and Rudder (Rudder is 2 boxes). Hull 0 = sinking (removed at end of turn). Rigging loss reduces speed per R-12. Crew loss reduces reload and boarding. Rudder 0 doubles turn cost.
- **R-9 Morale.** Morale starts at the class value plus the captain trait modifier. Morale drops by 1 per Hull or Crew box lost in a single impulse beyond the first, by 2 when a friendly ship within 3 hexes sinks or strikes, and recovers by 1 at turn end if the ship took no damage. At 0 the ship **strikes its colors**: it stops acting and can be captured by boarding (R-34).
- **R-10 Facing.** A ship always faces one heading. Its broadsides cover the two side arcs (headings h+1, h+2 for starboard; h−1, h−2 for larboard), each a 60° wedge out to range.

### 4.3 Movement and Points of Sail

- **R-11 Point of sail.** Let `d` be the number of 60° steps between the ship's heading and the heading the wind blows *from* (0–3). `d = 0` is **in irons** (heading straight into the wind; speed 0), `d = 1` is close-hauled, `d = 2` is beam reach, and `d = 3` is running (wind directly astern).
- **R-12 Speed.** Movement points per turn = class speed table `[inIrons, closeHauled, beamReach, running]` (default frigate `[0, 2, 4, 3]`) + wind strength modifier (`+0` at 1, `+1` at 2 for beam and running, `+1` at 3 for all except in irons) − floor(rigging lost / 2). Minimum 0.
- **R-13 Courses.** An order is a course: a sequence of up to 6 steps, each `forward` or `turnLeft`/`turnRight` (60°). A forward step costs 1 movement point; a turn costs the class turn cost (default 1, ×2 if Rudder is 0). Courses are validated on the speed of the point of sail at the moment of each step (turning changes the point of sail for subsequent steps).
- **R-14 Impulse allocation.** A course is spread over 6 impulses: a ship with `m` movement points executes forward steps at the impulses given by the table `impulsesFor(m)` (e.g., m = 3 → impulses 2, 4, 6; m = 4 → 1, 3, 4, 6). Turns happen at the impulse of the following forward step, or at impulse 1 if the course begins with a turn.
- **R-15 Collision.** If two ships would enter the same hex in the same impulse, both stop in their current hexes and each takes 1 Hull damage; if one ship would enter a hex occupied by a stationary ship, the mover stops and both take 1 Hull damage and become **fouled** (adjacent, may board without grappling this turn).
- **R-16 Shoals and islands.** A ship of draft ≥ 2 entering a shoal hex runs aground: it stops, takes 2 Hull damage, and cannot move next turn. Entering an island is illegal (validator rejects the course).
- **R-17 Currents.** Valley-fold drift (R-4) happens after impulse 6 and before end-of-turn checks; drift into an occupied or impassable hex does not happen.

### 4.4 Gunnery

- **R-18 Shot types.** Each ship's orders choose one shot type for the turn: `round` (targets Hull), `chain` (targets Rigging, range ≤ 3), or `grape` (targets Crew, range ≤ 2). Changing shot type from the previous turn delays the first broadside to impulse 3.
- **R-19 Reload.** A broadside fires at most once per turn per side, unless crew ≥ 75% and the captain has the `fast_reload` trait, in which case it may fire twice (second at least 3 impulses after the first).
- **R-20 Fire decision.** Orders include a fire policy per broadside: `atFirstChance`, `holdUntilRange(n)`, or `holdFire`. Fire happens at the end of an impulse when a valid enemy target is in arc, in range (max 4), and in line of fire.
- **R-21 Target selection.** Among valid targets, a broadside fires at the closest; ties go to the target with the lowest Hull; then the lowest ship ID.
- **R-22 Hits.** For each gun-group (guns per broadside ÷ 4, rounded up), roll `d6` from the turn RNG: hit on ≤ `5 − range + 1` (range 1: hits on 1–5, range 4: hits on 1–2); +1 to the threshold for a **raking** shot (target's bow or stern faces the firer, i.e., firer is in the target's heading or heading+3 wedge); −1 if the firer is in irons. Each hit removes one box from the targeted track; at 0 remaining, excess hits go to Hull.
- **R-23 Critical hits.** A natural 1 on a hit also rolls a crit table: Rudder −1, fire starts, mast down (Rigging −2), or magazine (Hull −2, only on round shot).
- **R-24 Simultaneity.** All fire in the same impulse resolves simultaneously: damage is applied after every broadside of that impulse has rolled.
- **R-25 Fire on board.** A burning ship loses 1 Hull at the end of each turn; it may extinguish instead of firing a broadside (orders flag); extinguishing succeeds on d6 ≤ 4.

### 4.5 Boarding

- **R-26 Grappling.** Orders may flag a ship to `grapple` a named enemy. At the end of any impulse where the two are adjacent, grappling succeeds on d6 ≤ 3 (+1 if the target is fouled or struck; +1 for the weather gauge holder). Grappled ships stop moving for the rest of the turn.
- **R-27 Boarding melee.** At turn end, each grappled pair fights: each side rolls `crew/4` dice (rounded up); each roll ≤ 3 removes 1 Crew from the opponent. The side with more Crew left after 3 rounds wins; ties leave both grappled.
- **R-28 Capture.** A losing ship with Crew ≤ 2, or any struck ship that is boarded, is **captured**: it joins the winner's fleet for the rest of the battle with 1 Crew and morale 1, and counts as a prize in campaign scoring.
- **R-29 Cutting free.** A grappled ship may cut free in its next orders instead of moving its first forward step.

### 4.6 Turn Structure and Order Resolution

- **R-30 Turn phases.** (1) Turn start: wind shift, weather gauge, morale checks. (2) Plotting: both sides submit `FleetOrders` secretly. (3) Resolution: impulses 1–6. (4) Drift. (5) Boarding melee. (6) Fire damage and extinguish. (7) Sinking and strikes. (8) Victory check.
- **R-31 Impulse order.** Within each impulse: (a) turns, (b) forward moves resolved simultaneously with collisions per R-15, (c) grapple attempts, (d) fire declarations by policy, (e) simultaneous damage application, (f) morale updates. Iteration order for any per-ship loop is: weather gauge holder's ships first, then by ship ID; this order affects only event ordering, never outcomes, because effects are applied simultaneously.
- **R-32 Orders legality.** `OrderValidator` rejects courses that exceed movement points, enter islands, or reference missing ships. An illegal order set is a `RuleError` and is never applied; the UI must prevent it.

### 4.7 Victory

- **R-33 Battle victory.** A side wins when all enemy ships are sunk, struck, captured, or disengaged. Turn limit (default 12): at the limit, victory points decide: sunk = class points, captured = 1.5× class points, struck but not captured = 0.5×, disengaged = 0.25×.
- **R-34 Struck ships.** A struck ship has 0 movement and does not fire. It drifts with currents. It can be captured by any enemy that ends a turn adjacent with Crew ≥ 2 (no melee needed).
- **R-35 Retreat.** A ship leaving the map edge is disengaged. A player may order **general retreat**: all ships that disengage within the next 3 turns count 0 VP for the opponent; the battle ends as a loss for the retreating side.

### 4.8 Campaign

- **R-36 Campaign chart.** A node map of 12–16 islands and ports; the fleet moves one edge per campaign turn. Nodes are `battle`, `port`, `event`, `storm`, or `admiralty` (finale).
- **R-37 Fleet roster.** Up to 7 ships, each with a captain (one trait from `captain_traits.json`), veterancy (green, seasoned, veteran: +0/+1/+2 morale and +0/0/+1 grapple), and persistent damage (Hull and Rigging repaired at ports for gold; Crew recruited).
- **R-38 Gold.** Earned by victories (VP × 10), prizes (sell or commission), and events. Spent on repairs, recruits, and new ships at ports.
- **R-39 Campaign end.** Win by defeating the admiralty fleet at the final node; lose if the fleet has no ships or the admiral's reputation (starts at 5, −1 per lost battle, −2 per retreat) reaches 0.
- **R-40 Campaign events.** Event nodes draw a card (`campaign_events.json`) with 2–3 choices; outcomes are deterministic given the campaign RNG.

### 4.9 Async Online Commit-Reveal

- **R-50 Roles.** In an online match, the player who created the match is A, the other B. Every turn, one side submits a **commitment** (SHA-256 of `orders || 32-byte salt`) and the other submits **plain orders**. The roles alternate each turn: A commits on odd turns, B on even turns.
- **R-51 Pipeline (fixed committer).** A is always the committing side and B is always the plain side. Each turn *t* consists of two GameKit passes:
  1. **A's pass:** `reveal(Aₜ₋₁, salt)` for the previous turn (omitted on turn 1) plus `commit(Aₜ) = SHA256(ordersₜ || saltₜ)`.
  2. **B's pass:** `plain(Bₜ)`.
  
  After B's pass, B cannot yet resolve turn *t* (A's orders are hidden). After A's next pass reveals Aₜ, both clients resolve turn *t*, and A plots Aₜ₊₁ having seen the result. Fairness: B never sees A's orders before posting, and A cannot change Aₜ after seeing Bₜ because A's commitment precedes B's plain orders. Deployment (R-5) uses the same scheme as "turn 0." Because B sees the resolution of turn *t* one pass later than A, the UI shows B the last resolved turn plus a "waiting for the enemy's reveal" banner.
- **R-52 Verification.** When a reveal arrives, both clients verify `SHA256(orders || salt) == commitment`. A mismatch forfeits the match for the revealer.
- **R-53 Timeouts.** GameKit turn timeout is 72 hours (default). A timed-out player forfeits.
- **R-54 Determinism.** Turn resolution depends only on `(matchSeed, turn, ordersA, ordersB, contentVersion)`. Both clients compute it independently and compare the post-turn state hash, which is included in each pass; a mismatch flags a desync, freezes the match, and offers a support export (state + orders JSON).

> GLM note: implement exactly the fixed-committer protocol in R-51. Local pass-and-play uses a "hand the iPad over" screen instead of commit-reveal; solo play needs neither.

### 4.10 Edge Cases

- **R-55** A ship that sinks in impulse *k* still fires in impulse *k* (simultaneity) but not afterward.
- **R-56** Two ships grappling each other in the same impulse: one grapple roll (lower ship ID rolls), success binds both.
- **R-57** A course that ends in irons is legal; the ship keeps its heading but has 0 speed next turn unless it turns first (turning out of irons costs 2).
- **R-58** A captured ship's orders for the current turn are discarded.
- **R-59** Wind shift during a turn never happens (only at turn start).

### 4.11 Invariants

- **INV-1** No two ships occupy one hex at the end of any impulse.
- **INV-2** Damage track values are within `0…max` for every ship.
- **INV-3** A struck, sunk, or captured ship never fires.
- **INV-4** Resolution is symmetric: swapping players' identities (and mirroring the map) yields mirrored outcomes for symmetric setups with the same RNG stream mapping (test with mirrored maps).
- **INV-5** Replay hashes match across platforms.
- **INV-6** A commitment is verified before any revealed order affects state.
- **INV-7** VP totals are non-negative and equal the sum of per-ship contributions.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct BattleState: Codable, Equatable, Hashable, Sendable {
    public var turn: Int; public var impulse: Int
    public var map: SeaMap; public var wind: Wind
    public var ships: [ShipID: Ship]; public var gauge: Side
    public var vp: [Side: Int]; public var turnLimit: Int
    public var matchSeed: UInt64
}
public struct Ship: Codable, Equatable, Hashable, Sendable {
    public var id: ShipID; public var side: Side; public var classID: String
    public var hex: Hex; public var heading: Heading
    public var hull: Int; public var rigging: Int; public var crew: Int; public var rudder: Int
    public var morale: Int; public var status: ShipStatus // active, struck, sunk, captured, disengaged, aground
    public var burning: Bool; public var grappledWith: ShipID?; public var lastShot: ShotType
    public var captain: CaptainTraitID?; public var veterancy: Veterancy
}
public struct ShipOrders: Codable, Equatable, Hashable, Sendable {
    public var ship: ShipID; public var course: [Step]            // forward, turnLeft, turnRight
    public var shot: ShotType; public var fire: [Broadside: FirePolicy]
    public var grapple: ShipID?; public var extinguish: Bool; public var cutFree: Bool
}
public enum Action: Codable, Equatable, Sendable {
    case deploy(Side, [ShipID: Placement])
    case submitOrders(Side, FleetOrders)        // both required before resolveTurn
    case resolveTurn
    case generalRetreat(Side)
    case campaign(CampaignAction)               // moveTo(node), repair, recruit, buy, chooseEvent
}
public enum Event: Codable, Equatable, Sendable {
    case moved(ShipID, Hex, Heading, impulse: Int), collided(ShipID, ShipID)
    case fired(ShipID, Broadside, target: ShipID, hits: [Track], crits: [Crit])
    case grappled(ShipID, ShipID), boarded(winner: ShipID, loser: ShipID), captured(ShipID, by: Side)
    case struck(ShipID), sank(ShipID), aground(ShipID), drifted(ShipID, Hex)
    case windShift(Heading, Int), gaugeChanged(Side), battleEnded(BattleResult)
}
```

### 5.2 Content Tables

**`ship_classes.json`** — G3: 6 classes; G5: 8.

```json
{ "id": "frigate", "hull": 10, "rigging": 6, "crew": 12, "rudder": 2, "gunsPerBroadside": 12,
  "speed": [0, 2, 4, 3], "turnCost": 1, "draft": 2, "morale": 6, "points": 8, "sprite": "ship_frigate" }
```

Classes: `cutter`, `sloop`, `brig`, `frigate`, `razee`, `ship_of_the_line`, plus `fire_ship` (special: sacrifices itself to set an adjacent ship burning) and `bomb_ketch` (indirect fire over mountain folds, range 3–5, no broadside) for G5.

**`captain_traits.json`** — G3: 10; G5: 16.

```json
{ "id": "fast_reload", "effect": { "doubleBroadside": true }, "rarity": "rare", "nameKey": "trait_fast_reload" }
```

**`maps/*.json`** — G3: 8 handcrafted skirmish maps; G5: 12 handcrafted + a procedural archipelago generator.

```json
{ "id": "twin_folds", "size": [17, 13], "hexes": "base64", "folds": [
  { "kind": "valley", "hexes": [[3,0],[3,1],[3,2]], "direction": 2 },
  { "kind": "mountain", "edges": [[[8,4],1],[[8,5],1]] } ],
  "wind": { "from": 0, "strength": 2, "shifts": [{ "turn": 6, "to": 1 }], "fickle": false },
  "deploy": { "A": [[0,0],[16,1]], "B": [[0,11],[16,12]] } }
```

**`campaign_events.json`** — G3: 12; G5: 30.

```json
{ "id": "becalmed_merchant", "textKey": "ev_becalmed_merchant", "choices": [
  { "key": "board", "effects": [{ "gold": 40 }, { "reputation": -1 }] },
  { "key": "escort", "effects": [{ "gold": 15 }, { "morale": 1 }] } ] }
```

**`campaign_chart.json`** — G5: 1 hand-authored chart with procedural node assignment (seeded), 3 difficulty settings.

### 5.3 Online Match Data

```json
{ "v": 1, "contentVersion": "1.0.0", "matchSeed": "0x…", "turn": 7,
  "passes": [{ "by": "A", "reveal": { "orders": {…}, "salt": "b64" }, "commit": "hex", "stateHash": "hex" },
             { "by": "B", "plain": { "orders": {…} }, "stateHash": "hex" }] }
```

Keep `matchData` under GameKit's size limit (64 KB). Prune passes older than the last 3 turns and store a state snapshot every 4 turns.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `battle.turnLimit` | 12 | 8–16 | balance.json |
| `gunnery.maxRange` | 4 | 3–5 | balance.json |
| `gunnery.hitBase` | 6 (hits ≤ 6 − range) | 5–7 | balance.json |
| `gunnery.rakeBonus` | 1 | 0–2 | balance.json |
| `grapple.base` | 3 | 2–4 | balance.json |
| `morale.sinkNearby` | 2 | 1–3 | balance.json |
| `wind.strengthBonus` | see R-12 | — | balance.json |
| `campaign.goldPerVP` | 10 | 6–15 | balance.json |
| `campaign.repairCostPerBox` | 4 | 2–8 | balance.json |
| `campaign.reputationStart` | 5 | 3–7 | balance.json |
| Ship points per class | per table | ±2 | ship_classes.json |

**Target metrics (sims, ≥ 500 games per pairing):**

| Metric | Target |
| --- | --- |
| Mirror match, equal AI, side A win rate | 48–52% |
| Weather gauge holder at turn 1 win rate (equal AI) | 53–60% (an advantage, not decisive) |
| Average battle length | 7–10 turns |
| Battles decided by turn limit | 15–30% |
| Each ship class appears in winning fleets of the `hard` AI at ≥ 8% (point-buy skirmish) | yes |
| Hard AI vs medium AI | 70–80% |
| Medium vs easy | 70–80% |

## 7. AI Approach

Simultaneous moves mean the AI must reason about a distribution of opponent orders.

| Tier | Algorithm | Budget (iPad A16, p95) |
| --- | --- | --- |
| `easy` | For each ship independently: generate 12 candidate courses (`CandidateGenerator`), pick the one with the best static score assuming the enemy stays still. Fire policy `atFirstChance`. | 100 ms |
| `medium` | Generate 24 joint fleet candidates (ship-level candidates combined by beam search, width 24). Sample 8 opponent candidate sets from `OpponentModel` (the easy policy plus noise). Pick the candidate with the best average evaluation after full turn simulation. | 800 ms |
| `hard` | Iterated best response, depth 2: build 32 own and 32 opponent candidates; compute payoff matrix by simulating the turn (32×32 = 1,024 resolutions, cached by state hash); solve for a mixed strategy with 200 iterations of regret matching; sample the final orders from the mixture using the AI's own RNG stream. | 1,500 ms |
| `admiral` (campaign finale only) | `hard` plus a 2-turn rollout on the top 4 candidates | 2,500 ms with an "Admiral is thinking" indicator |

**Evaluation features:** hull, rigging, crew ratios (weighted 1.0, 0.6, 0.5); expected damage dealt minus taken (computed from hit probabilities, not RNG); raking opportunities; weather gauge ownership (+0.3); distance to the nearest enemy relative to preferred range for the ship's shot type; risk of grounding; ships in irons (−0.4); VP delta.

**Personalities** (campaign rivals): `aggressive` (preferred range 1–2, grapple bias), `cautious` (preferred range 3–4, retreats damaged ships), and `tactician` (values the gauge ×2).

**Determinism:** AI decisions use a dedicated RNG `SplitMix64(matchSeed ^ side ^ turn)`. Same state in = same orders out. Turn resolution simulations inside the AI use a cloned state and a *copy* of the turn RNG so the AI never advances the real stream.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **PAD-P0.1 Hex library.** Axial coordinates, neighbors, distance, line-of-fire walker across hex edges (needed for mountain folds), and ring/arc queries. Acceptance: 40+ known-answer tests.
- **PAD-P0.2 Debug map viewer.** SpriteKit scene that draws a map JSON with folds. Acceptance: snapshot test.

```
GATE G0 — Setup
Checks:
  [ ] CI green; app launches on iPad simulator and macOS
  [ ] Hex library tests pass; banned-API lint fixture fails as expected
  [ ] RULES.md contains R-1…R-59 and INV-1…INV-7
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **PAD-P1.1 Wind and points of sail (R-3, R-11, R-12).** Parameterized tests for all 6×6 heading/wind pairs and strength 1–3.
- **PAD-P1.2 Courses and impulse allocation (R-13, R-14).** Acceptance: `impulsesFor(m)` table tested for m = 0…6; validator rejects every illegal case listed in R-32.
- **PAD-P1.3 Movement and collisions (R-15–R-17).** Acceptance: head-on, same-hex, chase, and drift cases.
- **PAD-P1.4 Gunnery (R-18–R-25).** Acceptance: arcs, raking detection, mountain-fold blocking, simultaneous damage (both ships sink in the same impulse), and crits; statistical test of hit rates over 100,000 rolls within ±1%.
- **PAD-P1.5 Boarding and capture (R-26–R-29, R-34).**
- **PAD-P1.6 Morale and strikes (R-9).**
- **PAD-P1.7 Victory and VP (R-33, R-35).**
- **PAD-P1.8 Commit-reveal state machine (R-50–R-54)** in Core with a fake `HashVerifier`. Acceptance: forged reveal forfeits; desync detection triggers on a tampered hash.
- **PAD-P1.9 Sim CLI.** `Tools/sim --map twin_folds --a random --b random --games 1000`.

```
GATE G1 — Rules Engine
Checks:
  [ ] Every rule ID has ≥ 1 tagged test; INV-1…INV-7 property tests over 1,000 seeds
  [ ] PADCore coverage ≥ 90%
  [ ] `make sim N=1000` random-vs-random: 0 crashes, 0 illegal states, identical hashes across two runs and iPad vs Mac
  [ ] One full turn resolution ≤ 1.0 ms on CI Mac with 14 ships (measure test; the hard AI depends on it)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: one skirmish map (`twin_folds`), 3 ship classes (sloop, brig, frigate), 3v3, vs the `easy` AI, plus local pass-and-play.

- **PAD-P2.1 Course drawing.** Drag from a ship along the hex grid; the path snaps to legal steps and shows remaining movement points as small paper notches; the line turns gray beyond legal range. Tap a ship's side to toggle each broadside's fire policy; a shot-type wheel on press and hold. Mouse: click-drag the same way; right-click opens the shot wheel.
- **PAD-P2.2 Preview scrub.** A scrub bar under the sea previews your own ships across impulses 1–6 (enemy shown at their current positions, faded). Acceptance: preview positions equal Core's movement for your ships with the enemy stationary.
- **PAD-P2.3 Resolution playback.** Impulses play back over ~6 seconds with ink smoke, damage numbers, and track pips. Tap to fast-forward; replay last turn button.
- **PAD-P2.4 Ship cards.** Bottom drawer with each ship's four tracks, morale, and orders summary.
- **PAD-P2.5 Pass-and-play.** A "Hand over to the other admiral" screen hides the board between plots.
- **PAD-P2.6 Wind rose and weather gauge indicator.**

Slice checks: Mahler can plot a 3-ship turn in under 45 seconds after two battles; the board reads clearly at iPad 11".

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays a full skirmish vs easy AI to the results screen on iPad and Mac (scripted courses)
  [ ] XCUITest plays a pass-and-play battle for 2 turns with the hand-over screen
  [ ] Preview equals resolved movement in 200 random cases (unit test across PADRender preview adapter and Core)
  [ ] ≥ 60 fps in debug overlay during resolution playback with 6 ships
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — is predicting the opponent the core skill? Is wind meaningful?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **PAD-P3.1** All 8 ship classes including `fire_ship` and `bomb_ketch` rules (add rule IDs R-60+ to RULES.md with ADRs).
- **PAD-P3.2** 12 skirmish maps; 16 captain traits.
- **PAD-P3.3** Campaign: chart, ports (repair, recruit, buy), event cards (30), veterancy, gold, reputation, and the admiralty finale.
- **PAD-P3.4** Skirmish setup screen with point-buy (default 40 points) and map picker.
- **PAD-P3.5** Tutorial: three short guided battles (sailing and wind, gunnery and shot types, boarding).
- **PAD-P3.6** Procedural archipelago generator (`PADAI/MapGenerator`) with symmetric deployment and validation that both sides have equal access to the gauge (wind-axis symmetry).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 8 classes, 16 traits, 12 maps, 30 events, 1 campaign chart
  [ ] content-lint 0 errors; all rule tests green
  [ ] Campaign completes end-to-end in XCUITest using the debug "auto-resolve battles" switch
  [ ] Tutorial battles complete in XCUITest
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **PAD-P4.1** `CandidateGenerator` with pruning of dominated courses.
- **PAD-P4.2** Easy, medium, hard, and admiral tiers (§7).
- **PAD-P4.3** Resolution cache by state hash; measure 1,024 resolutions within budget.
- **PAD-P4.4** Personalities for campaign rivals.
- **PAD-P4.5** `make balance`: every tier pairing ×500 games on 6 maps → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] Soak: 500 games per tier per map, 0 crashes, 0 illegal orders
  [ ] p95 think time within §7 budgets (measured on CI Mac, scaled by the A16 factor recorded in PERF.md; real device in P8)
  [ ] Tier separation and mirror-balance targets in §6
  [ ] Same state → same AI orders (determinism test, 100 states)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **PAD-P5.1 Daily Battle.** A daily map (procedural) and fixed fleets vs the hard AI; score = VP margin + turns remaining bonus.
- **PAD-P5.2 Admiralty unlocks.** Ship classes and maps unlock via campaign progress; all earnable.
- **PAD-P5.3 Stats.** Win rate by class, shots by type, prizes taken, campaigns won by difficulty.
- **PAD-P5.4 Async online scaffolding.** `TurnBasedMatchService` protocol with an in-memory fake that runs the full commit-reveal flow for two local clients. Real GameKit binding waits for P7.
- **PAD-P5.5 Replays.** Save any battle replay and play it back from the results screen.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Two-client fake async test plays 12 turns with commit-reveal; tampering test forfeits
  [ ] Daily battles generate deterministically for 60 days; hard AI does not lose to easy AI from the player seat more than 10%
  [ ] All standard tests and coverage thresholds pass
  [ ] docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **PAD-P6.1** Final origami ship sprites (8 classes × 6 headings × 2 sides × damage states: intact, damaged, burning, struck).
- **PAD-P6.2** Washi water shader, crease shading, ink smoke particles.
- **PAD-P6.3** Music (plotting, resolution, victory, defeat) and SFX.
- **PAD-P6.4** Campaign chart art as a folded map that unfolds node by node.

```
GATE G6 — Aesthetics
Checks:
  [ ] Pillar 2 screenshot test: Grok names the gauge holder in 10/10 random frames
  [ ] 120 fps on iPad Pro (M4) during resolution
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **PAD-P7.1 Pencil.** Draw courses with Pencil; hover over a ship previews its arcs and range; squeeze opens the shot wheel.
- **PAD-P7.2 GameKit turn-based.** Bind `TurnBasedMatchService` to `GKTurnBasedMatch` with `SHA256Verifier`; matchmaking, rematch, and turn notifications.
- **PAD-P7.3 Game Center.** Leaderboards (daily battle), 30 achievements.
- **PAD-P7.4 iCloud** campaign sync.
- **PAD-P7.5 Mac.** Keyboard: Tab cycles ships, arrow keys step a course, 1/2/3 shot type, Return submits.

```
GATE G7 — Platform
Checks:
  [ ] Two sandbox Game Center accounts complete an async match on iPad + Mac
  [ ] matchData stays < 64 KB through 16 turns
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **PAD-P8.1** Color-blind: sides distinguished by sail pattern (striped vs plain) as well as color.
- **PAD-P8.2** VoiceOver: ship cards, course summary ("Frigate Kestrel: forward two, turn right, forward one; round shot; fire at first chance").
- **PAD-P8.3** Reduce Motion: no ship bob, shorter playback.
- **PAD-P8.4** Real-device AI budgets and frame rates in `docs/PERF.md`.

```
GATE G8 — Polish
Checks:
  [ ] Budgets met on real devices; hard AI p95 ≤ 1.5 s on iPad (A16)
  [ ] Accessibility audit clean
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

- **PAD-P9.1** Internal TestFlight (Mahler creates records and groups).
- **PAD-P9.2** Async matches among testers; collect desync reports.
- **PAD-P9.3** Balance from opt-in exported stats.

```
GATE G9 — Beta
Checks:
  [ ] 0 desyncs across ≥ 50 tester async matches
  [ ] Crash-free ≥ 99.5%
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks plus a 30-second preview showing a plotted turn and its resolution.

```
GATE G10 — Release
Checks:
  [ ] RC passes full CI and clean-install smoke
  [ ] Metadata, screenshots, privacy and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** the impulse allocation table (R-14) and simultaneous damage (R-24) are where subtle bugs hide; the commit-reveal pipeline (R-51) must be audited by Claude before P7 binds it to GameKit.
- **Balance hot spots:** weather gauge strength and grapple odds; boarding can dominate if crew numbers are too high.
- **First tasks:** Grok — review `docs/BALANCE.md` gauge and class pick rates; Claude — audit the protocol and bind GameKit.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Simultaneous turns feel random | Medium | High | Preview scrub, clear arcs, expected-damage hints in tutorial | GROK |
| Hard AI too slow on A16 | Medium | Medium | Resolution cache, reduce candidate counts adaptively by measured time | GLM → CLAUDE |
| Async cheating by reading matchData | Low | Medium | Commit-reveal (R-50–R-54) | CLAUDE |
| matchData size limit | Medium | Medium | Pruning and snapshots | GLM |
| Course drawing fiddly on iPhone | Medium | Medium | Step buttons fallback on compact width | CLAUDE |
| Campaign scope creep | Medium | Medium | Fixed at 1 chart and 30 events for v1.0 | GROK |

## 11. Out of Scope

- Real-time naval combat, 3D ships, and historical scenarios with real ship names.
- Live (real-time) online play; only async turn-based.
- More than two sides in a battle.
- A map editor in release builds.
- In-app purchases and cosmetics.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 10–14 |
| P2 Vertical Slice | GLM | 8–12 |
| P3 Content and Systems | GLM | 12–16 |
| P4 AI | GLM | 8–12 |
| P5 Meta | GLM | 5–8 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 12–18 |
| P7 Platform | CLAUDE | 7–10 |
| P8 Polish | CLAUDE | 5–8 |
| P9 Beta | GROK + CLAUDE | 8–12 |
| P10 Release | CLAUDE + GROK | 2–4 |
| **Total** | | **79–117** |

## 13. Open Questions for Mahler

1. Fixed-committer async protocol (two GameKit passes per turn) is the default; acceptable? **Default:** yes.
2. Title display face? **Default:** New York Large.
3. Should the campaign have one fixed narrative or be fully procedural? **Default:** fixed chart shape, procedural node contents.
4. Include fire ships and bomb ketches in v1.0? **Default:** yes, unlocked mid-campaign.
5. Price? **Default:** Mahler decides in P10.
