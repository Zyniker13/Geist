# 14 — Beacon Coast Roadmap

> Guide ships into harbor through fog by placing lighthouses, buoys, and foghorns along a coastline that grows more treacherous every night.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 in full before starting. This roadmap only adds what is specific to Beacon Coast. Where this file says "per conventions," the shared rule applies unchanged.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 14 · `beacon-coast` |
| Code prefix | `BCN` (packages `BCNCore`, `BCNContent`, `BCNAI`, `BCNRender`, `BCNAudio`, `BCNPlatform`, `BCNMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Puzzle logistics (real-time with pause) |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 8–15 min per run |
| Renderer | SpriteKit (2D) + one Metal 4 compute/fragment pass for volumetric fog and beam light (`BCNRender/Fog`) |
| Players | Solo only (score attack, daily, and weekly challenges); no multiplayer in v1.0 |
| Simulation | Fixed tick, 30 ticks per second, integer and `Fixed` math only |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Guide ships into harbor through fog by placing lighthouses, buoys, and foghorns along a coastline that grows more treacherous every night.

**Summary:** Each run is a sequence of nights on one coastline. Ships appear at the sea edge on a schedule and steer for a harbor. In clear water they navigate on their own; in fog they can only trust what is lit, marked, or sounded. The player places a small, growing set of navigation aids: lighthouses whose beams sweep, buoys that mark hazards permanently, and foghorns that give lost ships a heading. Tides raise and lower the water, hiding and exposing reefs, and each hull draws a different depth. One shipwreck ends the run. The score is the number of ships safely docked. Between nights the player picks one of two upgrades. The game borrows Mini Metro's escalating schedule and calm minimalism, and adds a light-geometry puzzle.

**Pillars (each is a gate-review test):**

1. **One glance, one truth.** A screenshot at any moment shows which water is safe, which is unknown, and which is dangerous. If a reviewer cannot point to the next likely wreck within five seconds, the pillar fails.
2. **Light is the verb.** Every meaningful decision is about where light falls and when. No menus are needed during a night except pause.
3. **Failure is fair and foreseeable.** Every wreck is preceded by at least 4 seconds (120 ticks) of visible warning (a ship's heading line crossing an unlit hazard turns red).
4. **Escalation, not complication.** Night 1 teaches itself with no text; nights get harder through more ships, thicker fog, and tides, not through new UI.
5. **Short and replayable.** A median run lasts 8–15 minutes, and a daily fog seed is the same for every player.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Night sea `#0E1B2C`, deep water `#13243A`, shallows `#1E3550`, fog `#8A96A3` (alpha 0–0.85), land `#2A2F36`, rock and reef `#4A5260`, beam sodium yellow `#FFC247`, beam core `#FFE7A8`, danger `#E0533D` (only for warnings), harbor glow `#F2D9A0`. Color-blind alternates in P8. |
| Shapes | Flat vector coastline with a 1.5 pt light outline on land; ships as simple top-down silhouettes, readable at 18 pt; aids are geometric icons (tower, cone buoy, horn) |
| Typography | SF Pro Rounded for UI numerals; one display face for titles (open question Q3; default: SF Pro Display Light with wide tracking) |
| Motion | Beams rotate at constant angular speed; fog advects slowly; ships ease at 30 Hz simulation interpolated to 120 Hz display |
| Music | Sparse, generative ambient: three-layer stems (pad, low strings, celesta) that add a layer per night tier |
| SFX | Foghorn (diaphone, pitch per horn), gulls, surf (density scales with tide), bell buoys, ship horn on docking, wreck sound as a muffled wooden crack (never gory) |
| Haptics | Light tick when a placed aid snaps to the grid; soft double pulse on docking; one heavy transient on wreck |

**Inspirations:** Mini Metro's escalating schedules and minimalism, daily-run principles from Dead Cells and Caveblazers, Polytopia's legibility rule, and Bad North's strict visual vocabulary.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit for the board, ships, aids, and UI. Fog and beam light are rendered by a Metal 4 fragment pass that reads a per-tile fog texture (R8, one texel per tile, bilinear upscale) and a per-tile light texture produced by Core each tick. Render never computes visibility; it draws what Core reports.
- **Visibility math:** Core computes beam coverage on the tile grid with integer angles (4096 units per turn) and a 4096-entry `Fixed` sine and cosine lookup table generated at build time and committed as `BCNCore/Foundation/TrigTable.swift`. Line of sight uses Bresenham across tiles; land and rock tiles block.
- **Pathfinding:** A* on the tile grid with 8-neighborhood and integer costs (10 orthogonal, 14 diagonal), deterministic tie-breaking by `(f, h, y, x)`.
- **Tick rate:** 30 ticks per second at 1× speed; 2× and 3× speed run 2 or 3 ticks per frame batch. Pause stops ticking entirely.
- **Audio:** AVAudioEngine with three looping stems mixed by night tier plus spatialized one-shot SFX (pan by screen x).

ADRs to create in P0:

- ADR-0003 Integer angle units and the committed trig table.
- ADR-0004 Tile-grid visibility instead of continuous raycasting (determinism and performance).
- ADR-0005 Metal fog pass reads Core output only.
- ADR-0006 Tide and draft integer depth model.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── BCNCore/Sources/BCNCore/
│   ├── Foundation/        SeededRNG.swift, Fixed.swift, TrigTable.swift, Angle.swift
│   ├── Map/               TileKind.swift, CoastMap.swift, DepthField.swift, Harbor.swift, SpawnPoint.swift
│   ├── Weather/           FogField.swift, FogBank.swift, Wind.swift, Tide.swift
│   ├── Aids/              Aid.swift, Lighthouse.swift, Buoy.swift, Foghorn.swift, BeamPattern.swift
│   ├── Ships/             Ship.swift, HullClass.swift, Navigator.swift (A*), KnowledgeMap.swift
│   ├── Visibility/        BeamCoverage.swift, LineOfSight.swift, LightField.swift
│   ├── Schedule/          NightSchedule.swift, SpawnScheduler.swift
│   ├── Run/               RunState.swift, NightPhase.swift, UpgradeOffer.swift, Score.swift
│   └── Engine/            GameState.swift, Action.swift, Event.swift, Reducer.swift, Tick.swift, RuleError.swift
├── BCNContent/            CoastlineDef.swift, HullDef.swift, AidDef.swift, UpgradeDef.swift, Loader.swift, Validation.swift
├── BCNAI/                 AutoPilot.swift (bot player for sims), DailyFogGenerator.swift, SeedVerifier.swift, CoastGenerator.swift
├── BCNRender/             BoardScene.swift, ShipNode.swift, AidNode.swift, BeamNode.swift, HeadingLineNode.swift, Fog/FogPass.metal, Fog/FogRenderer.swift
├── BCNAudio/              StemMixer.swift, Foghorn.swift, SurfBed.swift
├── BCNPlatform/           GameCenterService.swift, CloudSaveService.swift, PencilAdapter.swift, HapticsService.swift
└── BCNMeta/               Progression.swift, DailySeed.swift, WeeklyChallenge.swift, Stats.swift, LocalLeaderboard.swift
Resources/Content/
├── coastlines/            maine.json, cornwall.json, hokkaido.json, brittany.json (+ procedural templates)
├── hulls.json  aids.json  upgrades.json  nights.json  balance.json  weekly_mutators.json
```

Main types: `GameState`, `CoastMap`, `Ship`, `Aid`, `FogField`, `Tide`, `LightField`, `KnowledgeMap`, `NightSchedule`, `RunState`.

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5. All distances are in tiles; all times are in ticks (30 per second at 1×).

### 4.1 Map and Setup

- **R-1 Grid.** The map is a rectangular tile grid, 40×28 tiles by default (`balance.map.width`, `balance.map.height`). Tile kinds: `deep`, `shallow`, `reef`, `rock`, `land`, `harbor`, `spawn`.
- **R-2 Depth.** Every water tile has an integer `baseDepth` from 0 to 9. `deep` tiles have depth ≥ 6; `shallow` 2–5; `reef` 0–3. `rock` and `land` are impassable at any tide.
- **R-3 Harbors.** A map has 1–3 harbor tiles on the coast. Each harbor has a berth count (default 3). A ship docks when it enters a harbor tile with a free berth; a berth frees `balance.harbor.berthTicks` (default 300) ticks after docking.
- **R-4 Spawns.** Spawn tiles lie on the outer edge of the map in `deep` water. Each spawn has a weight per night tier taken from the coastline definition.
- **R-5 Starting aids.** The run starts with 1 lighthouse already placed at the coastline's designated headland, plus an inventory of 2 buoys and 0 foghorns.
- **R-6 Seed.** A run is fully determined by `(coastlineId, runSeed, contentVersion, actions)`. Procedural coastlines derive from `runSeed` through `CoastGenerator` (BCNAI), which is deterministic.

### 4.2 Time, Nights, and Phases

- **R-7 Night structure.** A run is a sequence of nights. Each night lasts `balance.night.lengthTicks` (default 5,400 ticks, three minutes at 1×). Between nights there is an untimed Harbor Phase.
- **R-8 Night tier.** Night *n* has tier `min(n, 8)`. Tier sets spawn rate, hull mix, fog strength, and tide amplitude from `nights.json`.
- **R-9 Harbor Phase.** In the Harbor Phase the player chooses exactly one of two offered upgrades (R-40) and may move any number of placed aids at no cost. No ships move.
- **R-10 Pause and speed.** The player may pause at any time during a night; placing, moving, rotating, and removing aids is allowed while paused. Speeds are 1×, 2×, and 3×; speed never changes rules, only ticks per frame.

### 4.3 Weather

- **R-11 Fog field.** Each tile has fog density `0…255`. Density is the sum of contributions from active fog banks, clamped to 255.
- **R-12 Fog banks.** A fog bank is a disk with center (Fixed), radius (tiles), and peak density. Contribution falls off linearly from peak at the center to 0 at the radius. Banks drift by the wind vector every tick and are removed when fully off the map.
- **R-13 Fog spawning.** New banks spawn at the upwind edge according to the night tier's `fogBanksPerMinute`, drawn from the run RNG.
- **R-14 Thick fog.** A tile is **fogged** when density ≥ `balance.fog.thickThreshold` (default 96). Clear tiles are visible to ships without light.
- **R-15 Wind.** Wind has a direction (integer angle) and speed (Fixed tiles per tick). It changes once per night at night start and may veer by ±512 units mid-night when the tier allows (`windVeer` in `nights.json`).
- **R-16 Tide.** Tide level `t` is an integer from `-tideAmp` to `+tideAmp`, following a triangle wave with period `balance.tide.periodTicks` (default 2,700). Effective depth of a tile is `baseDepth + t`, clamped to 0…12.
- **R-17 Exposed reefs.** A reef tile with effective depth ≤ 0 is **exposed**: it is drawn as rock and every ship treats it as impassable, lit or not.

### 4.4 Aids to Navigation

- **R-18 Placement.** Aids are placed on tiles. Lighthouses and foghorns must be on `land` or `rock` tiles adjacent (8-neighborhood) to water. Buoys must be on water tiles. At most one aid per tile.
- **R-19 Lighthouse beam.** A lighthouse has range `r`, arc width `w` (angle units), rotation period `p` (ticks), current heading `h`, and pattern. Each tick `h` advances by `4096 / p` (integer, remainder carried in a Fixed accumulator).
- **R-20 Beam patterns.** `sweep`: rotates continuously. `sector`: fixed heading set by the player, arc ×1.5, never rotates. `flash`: rotates at ×2 speed but lights only on 1 of every 3 frames of its cycle (on for `p/6` ticks, off for `p/12`), with range ×1.25.
- **R-21 Beam coverage.** A water tile is **lit** on a tick when its center is within distance `r` of the lighthouse, its bearing lies within `[h - w/2, h + w/2]`, and line of sight (Bresenham from aid tile to target) does not pass through a `land` or `rock` tile other than the aid's own tile.
- **R-22 Lit memory.** A ship that sees a lit tile remembers its hazard status for `balance.ship.memoryTicks` (default 240) ticks (see R-28).
- **R-23 Buoy.** A buoy permanently marks its own tile and the 8 neighbors as **charted** for all ships: their hazard status is always known, regardless of fog. Bell buoys (upgrade) chart radius 2.
- **R-24 Foghorn.** A foghorn has an audible radius (default 8). Every ship within radius gains a **heading fix**: its lost meter (R-30) decreases by 2 per tick instead of increasing. Foghorns do not reveal hazards.
- **R-25 Aid limits.** Inventory counts limit aids. Removing a placed aid returns it to inventory after `balance.aid.recallTicks` (default 90) during a night, instantly during the Harbor Phase or while paused at night start (tick 0 only).
- **R-26 Rotation.** While a night is running or paused, a `sector` lighthouse's heading may be set freely. A `sweep` lighthouse may be **nudged**: its current heading jumps to any value, once per `balance.aid.nudgeCooldown` (default 150) ticks.

### 4.5 Ships

- **R-27 Hulls.** Each ship has a hull class with `draft` (1–5), speed (Fixed tiles per tick), turn penalty, and score value from `hulls.json`.
- **R-28 Knowledge map.** Each ship keeps a knowledge map: for every tile, `unknown`, `safe`, or `hazard`, with an expiry tick. A tile is known when it is clear (R-14), charted (R-23), or lit (R-21, remembered per R-22). A tile is a **hazard for this ship** if it is rock, land, an exposed reef, or a water tile with effective depth < the ship's draft.
- **R-29 Navigation.** Every 15 ticks, and immediately when its knowledge map changes along its current path, a ship replans with A* to the nearest harbor with a free berth (or the nearest harbor if all are full). Unknown tiles cost ×3 and are assumed passable; known hazards are impassable.
- **R-30 Lost meter.** A ship in a fogged tile with no lit or charted tile within radius 2 adds 1 to its lost meter per tick. In a clear, lit, or charted tile, or under a heading fix (R-24), the meter decreases by 2 per tick. At 0 the meter stops.
- **R-31 Lost behavior.** While the lost meter ≥ `balance.ship.lostThreshold` (default 150), the ship stops following its plan and drifts with the wind at 25% speed. If it exceeds `balance.ship.anchorThreshold` (default 300), it drops anchor and stays put until the meter falls below the lost threshold.
- **R-32 Movement and collision.** A ship moves along its path at hull speed (×0.5 in fogged tiles). When its position enters a tile that is a hazard for its draft (true state, not knowledge), it **wrecks**.
- **R-33 Ship separation.** Two ships may not occupy the same tile; a ship whose next tile is occupied waits. If two ships wait on each other for 60 ticks, the later-spawned ship replans with the blocking tile marked hazard for 90 ticks.
- **R-34 Docking.** A ship entering a harbor tile with a free berth docks, scores its hull value, and is removed. A ship entering a full harbor waits on that tile.
- **R-35 Anchored too long.** A ship anchored or waiting for more than `balance.ship.patienceTicks` (default 1,800) is **lost at sea**: it is removed and the run's Reputation drops by 1.

### 4.6 Scoring, Win, and Loss

- **R-36 Score.** Score is the sum of docked hull values. The leaderboard metric for a run is total score.
- **R-37 Reputation.** Reputation starts at 3. Lost-at-sea ships cost 1. The run ends when Reputation reaches 0.
- **R-38 Wreck.** Any wreck ends the run immediately (after a 90-tick wreck animation during which no other rule runs). Exception: the `salvage_tug` upgrade negates the first wreck of the run (the ship is removed, no score).
- **R-39 No win state.** Runs continue until loss. Challenge modes (daily, weekly) use the same rule; a weekly mutator may add a night limit (e.g., "survive 6 nights"), in which case completing the last night is a win.

### 4.7 Upgrades and Progression Within a Run

- **R-40 Upgrade offers.** At each Harbor Phase, two upgrades are drawn from `upgrades.json` weighted by tier and excluding maxed upgrades, using the run RNG. Choosing one applies it immediately. The draw happens at night end, so it is reproducible from the replay.
- **R-41 Upgrade kinds.** Inventory (`+1 lighthouse`, `+2 buoys`, `+1 foghorn`), modifiers (`+2 range` on one lighthouse, `faster rotation`, `wider arc`, `bell buoys`), and specials (`salvage_tug`, `second harbor berth`, `pilot boat`: once per night, tap a lost ship to reset its lost meter).
- **R-42 Ordering within a tick.** Each tick resolves in this order: (1) apply queued player actions in submission order; (2) advance tide; (3) advance fog banks and recompute the fog field; (4) advance lighthouse headings; (5) compute the light field; (6) update ship knowledge maps; (7) replan ships that need it, in ship ID order; (8) update lost meters; (9) move ships in ship ID order and detect wrecks and docking; (10) spawn ships from the schedule; (11) check end-of-night and end-of-run conditions; (12) emit events.

### 4.8 Edge Cases

- **R-43** A ship spawning onto an occupied spawn tile waits off-map (not rendered, not counted) up to 300 ticks; if still blocked, it uses the next spawn by weight.
- **R-44** If no path exists to any harbor even through unknown tiles, the ship anchors (counts toward R-35).
- **R-45** Placing an aid under a ship is illegal (`RuleError.tileOccupied`).
- **R-46** A wreck and a docking on the same tick: wreck wins (the run ends), but the docked ship's score still counts.
- **R-47** If the night timer ends while ships are at sea, they persist into the next night at their positions; the Harbor Phase freezes them.

### 4.9 Invariants (Property Tests)

- **INV-1** No two ships share a tile at the end of any tick.
- **INV-2** Every ship's position is on a water or harbor tile whose effective depth ≥ its draft, unless a wreck event was emitted that tick.
- **INV-3** The number of placed aids plus inventory plus recalling aids equals total aids owned for each type.
- **INV-4** Fog density is in 0…255 on every tile.
- **INV-5** Replaying `(seed, contentVersion, actions)` yields the same state hash at every tick.
- **INV-6** A ship never plans through a tile its knowledge map marks hazard.
- **INV-7** Score never decreases.
- **INV-8** Every wreck is preceded by at least 120 ticks during which the ship's planned path included the wreck tile marked `unknown` (pillar 3; asserted in sims, logged if violated).

## 5. Data Schemas and Content Tables

### 5.1 Core State (Swift)

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var tick: Int
    public var rng: SeededRNG
    public var map: CoastMap                  // tiles, baseDepth, harbors, spawns
    public var tide: Tide                     // level, phase
    public var wind: Wind                     // angle: Angle, speed: Fixed
    public var fogBanks: [FogBank]
    public var fog: [UInt8]                   // width*height, derived; cached but hashed
    public var aids: [AidID: Aid]
    public var inventory: [AidKind: Int]
    public var recalling: [RecallEntry]
    public var ships: [ShipID: Ship]          // ordered by ShipID when iterated
    public var nextShipID: Int
    public var run: RunState                  // night, phase, score, reputation, upgrades, offers
}
public struct Ship: Codable, Equatable, Hashable, Sendable {
    public var id: ShipID; public var hull: HullID
    public var pos: FixedPoint; public var tile: TileCoord
    public var path: [TileCoord]; public var knowledge: KnowledgeMap
    public var lost: Int; public var waitTicks: Int; public var state: ShipMode // sailing, lost, anchored, waiting
}
public enum Action: Codable, Equatable, Sendable {
    case placeAid(AidKind, TileCoord, pattern: BeamPattern?)
    case moveAid(AidID, TileCoord)
    case removeAid(AidID)
    case setHeading(AidID, Angle)       // sector set or sweep nudge
    case setPattern(AidID, BeamPattern) // Harbor Phase only
    case chooseUpgrade(index: Int)
    case usePilotBoat(ShipID)
    case beginNight
}
public enum Event: Codable, Equatable, Sendable {
    case shipSpawned(ShipID), shipDocked(ShipID, score: Int), shipWrecked(ShipID, TileCoord)
    case shipLost(ShipID), shipAnchored(ShipID), headingWarning(ShipID, TileCoord)
    case aidPlaced(AidID), aidRemoved(AidID), tideTurned(level: Int)
    case fogBankSpawned(Int), nightEnded(Int), upgradeOffered([UpgradeID]), runEnded(RunResult)
}
```

### 5.2 Content Tables

**`hulls.json`** — count G3: 5; G5: 6.

```json
{ "id": "schooner", "draft": 2, "speedTilesPerTick": "0.0333", "fogSpeedMultiplier": "0.5",
  "score": 2, "sprite": "hull_schooner", "minTier": 1 }
```

Hulls: `dinghy` (1), `schooner` (2), `packet_steamer` (3), `collier` (4), `liner` (5, tier ≥ 5), `pilot_cutter` (special, upgrade only).

**`aids.json`** — count G3: 3 kinds with 3 patterns.

```json
{ "id": "lighthouse", "placement": "land_adjacent_water", "range": 7, "arcUnits": 512,
  "periodTicks": 240, "patterns": ["sweep", "sector", "flash"], "startCount": 1 }
```

**`upgrades.json`** — count G3: 12; G5: 18.

```json
{ "id": "bell_buoys", "kind": "modifier", "target": "buoy", "effect": { "chartRadius": 2 },
  "weightByTier": [0, 2, 3, 3, 3, 2, 2, 2], "maxStacks": 1, "icon": "up_bell" }
```

**`nights.json`** — one row per tier (8 rows).

```json
{ "tier": 3, "spawnIntervalTicks": [360, 540], "hullWeights": { "dinghy": 3, "schooner": 4, "packet_steamer": 2 },
  "fogBanksPerMinute": 2, "fogPeak": 200, "fogRadius": [4, 7], "tideAmp": 2, "windVeer": true }
```

**`coastlines/*.json`** — count G3: 2 handcrafted (Maine, Cornwall); G5: 4 handcrafted (+ Hokkaido, Brittany) and the procedural generator with ≥ 3 templates.

```json
{ "id": "maine", "name": "coast_maine", "width": 40, "height": 28,
  "tiles": "base64 RLE of TileKind", "depth": "base64 of UInt8",
  "harbors": [{ "x": 6, "y": 20, "berths": 3 }], "spawns": [{ "x": 39, "y": 4, "weights": [1,1,1,2,2,2,3,3] }],
  "headland": { "x": 12, "y": 14 }, "windPrevailing": 1024, "palette": "maine" }
```

**`weekly_mutators.json`** — count G5: 12.

```json
{ "id": "spring_tides", "effects": { "tideAmpDelta": 2 }, "nightLimit": 6, "descKey": "mut_spring_tides" }
```

**`balance.json`** — see §6.

### 5.3 Save Format

`SaveGame { version, contentVersion, replay: Replay, snapshot: GameState, snapshotTick }`. Resume loads the snapshot; a debug verification setting re-simulates from the replay and asserts equal hashes.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `map.width`/`map.height` | 40 / 28 | 32–48 / 22–32 | balance.json |
| `night.lengthTicks` | 5400 | 3600–7200 | balance.json |
| `fog.thickThreshold` | 96 | 64–160 | balance.json |
| `tide.periodTicks` | 2700 | 1800–4500 | balance.json |
| `ship.memoryTicks` | 240 | 120–480 | balance.json |
| `ship.lostThreshold` | 150 | 90–240 | balance.json |
| `ship.anchorThreshold` | 300 | 200–480 | balance.json |
| `ship.patienceTicks` | 1800 | 900–2700 | balance.json |
| `harbor.berthTicks` | 300 | 150–600 | balance.json |
| `aid.recallTicks` | 90 | 30–180 | balance.json |
| `aid.nudgeCooldown` | 150 | 60–300 | balance.json |
| `lighthouse.range` | 7 | 5–10 | aids.json |
| `lighthouse.periodTicks` | 240 | 120–480 | aids.json |
| `foghorn.radius` | 8 | 5–12 | aids.json |
| `reputation.start` | 3 | 1–5 | balance.json |

**Target metrics** (measured by `Tools/sim` with the `AutoPilot` bot at each skill level, ≥ 500 runs per coastline):

| Metric | Target |
| --- | --- |
| Median nights survived, `AutoPilot.novice` | 3–4 |
| Median nights survived, `AutoPilot.expert` | 8–11 |
| Median run length at 1× for expert | 10–16 min |
| Share of runs ending by wreck vs reputation | 60–80% wreck |
| Wrecks violating INV-8 | 0% |
| Score variance across 4 coastlines (expert median) | within ±15% |
| Daily seed: expert survives ≥ 3 nights | 100% of generated dailies (else regenerate) |

## 7. AI Approach

Beacon Coast has no opponent. AI work is (a) ship navigation, which is part of Core rules, (b) a bot player for balance sims, and (c) generators and verifiers for procedural coasts and dailies.

| Component | Algorithm | Budget |
| --- | --- | --- |
| `Navigator` (Core) | A* per R-29 with deterministic tie-breaks; incremental replans limited to 4 ships per tick (round-robin by ID); remaining replans defer to the next tick | ≤ 1.0 ms per tick total on iPad (A16) at 30 ships |
| `AutoPilot.novice` | Places aids at random legal tiles weighted toward the busiest spawn-to-harbor corridor; never moves them | n/a (sim only) |
| `AutoPilot.competent` | Every 300 ticks, scores candidate tiles by "unknown hazard tiles on current ship paths within beam reach" and moves the worst-placed aid there | ≤ 5 ms per decision |
| `AutoPilot.expert` | Greedy plus 2-step lookahead: simulates the next 300 ticks for the top 8 candidate moves using a cloned state; picks the move that minimizes predicted INV-8 warnings and lost-meter sum | ≤ 50 ms per decision (sim only) |
| `CoastGenerator` | Value-noise heightmap (integer) thresholded into land, shallow, and deep; reefs seeded by Poisson-disk on shelf tiles; harbors on concave coast; validated by flood fill (every spawn reaches every harbor at max tide for draft 3) | ≤ 200 ms per coast |
| `DailyFogGenerator` | Seed = SplitMix64(`yyyyMMdd` UTC as Int). Chooses coastline (rotation of 4 handcrafted plus procedural on weekends), fog schedule, and wind. Verifier runs `AutoPilot.expert` for 3 nights; if it fails, increments a salt and retries (max 16) | ≤ 3 s on device; precomputed for 60 days in CI as a check |

Determinism: AI code uses only the run RNG or seeds derived by `SplitMix64(runSeed ^ salt)`. The bot never reads Render or wall-clock time.

## 8. Phases, Tasks, and Gates

### P0 Setup

Standard tasks S0.1–S0.7.

- **BCN-P0.1 Trig table generator.** Deliverable: `Tools/gen-trig/` script and committed `TrigTable.swift` (4096 entries, Fixed). Acceptance: test that `sin²+cos²` is within 2⁻²⁰ of 1 for all entries; regenerating produces a byte-identical file.
- **BCN-P0.2 Map loader stub.** Deliverable: `CoastMap` with RLE decode and one 10×10 test map. Acceptance: round-trip encode/decode test.

```
GATE G0 — Setup
Checks:
  [ ] CI green on main (lint, imports, content-lint, package tests, iOS + macOS builds)
  [ ] App launches to placeholder menu on iPad Pro 13" simulator and macOS
  [ ] Banned-API lint fires on fixture `Tests/Fixtures/BannedAPI.swift`
  [ ] TrigTable regeneration is byte-identical (CI step)
  [ ] docs/ skeleton present; RULES.md contains R-1…R-47 and INV-1…INV-8
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype

Standard tasks S1.1–S1.4.

- **BCN-P1.1 Tide and depth (R-16, R-17).** Acceptance: parameterized tests over a full tide period; exposed-reef transitions emit `tideTurned` events.
- **BCN-P1.2 Fog field (R-11–R-15).** Acceptance: a single bank on an empty map produces the expected density at 9 sampled tiles (golden values); banks leave the map and are removed.
- **BCN-P1.3 Beam coverage and line of sight (R-19–R-21).** Acceptance: golden lit-tile masks for 12 configured lighthouse cases (each pattern, blocked by headland, wraparound at angle 0/4096); coverage of one 7-range lighthouse computed in ≤ 0.1 ms in a `measure` test on the Mac runner.
- **BCN-P1.4 Knowledge maps and A* (R-28, R-29, R-33).** Acceptance: tests for unknown-cost weighting, replanning on newly lit hazard, deterministic tie-breaks, and deadlock resolution.
- **BCN-P1.5 Lost meter and anchoring (R-30, R-31, R-35).** Acceptance: a ship in uniform thick fog with no aids anchors at tick 300 ± 0 and is lost at sea after `patienceTicks`.
- **BCN-P1.6 Docking, wreck, reputation, and run end (R-34–R-38, R-46).** Acceptance: rule tests including the same-tick wreck/dock case.
- **BCN-P1.7 Schedule and upgrades (R-7–R-9, R-40–R-41).** Acceptance: upgrade offers reproduce exactly from a seed; maxed upgrades are excluded.
- **BCN-P1.8 Tick ordering (R-42).** Acceptance: an event-order test asserts the 12-step order through a single crafted tick.
- **BCN-P1.9 Sim CLI.** `Tools/sim --coast maine --seeds 1000 --bot novice` prints nights survived, score, cause of end, INV-8 violations, and final hash.

```
GATE G1 — Rules Engine
Checks:
  [ ] Every rule ID R-1…R-47 has ≥ 1 tagged passing test (script: Tools/check-rule-tags.sh)
  [ ] Property tests INV-1…INV-7 pass over 1,000 random seeds; INV-8 logged with 0 violations for the novice bot on maine
  [ ] BCNCore line coverage ≥ 90%
  [ ] `make sim N=1000` → 0 crashes, 0 illegal states, identical hashes on two runs and on the iPad simulator vs macOS
  [ ] Tick with 30 ships + 6 lighthouses ≤ 2.0 ms on the CI Mac (measure test)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice

Standard tasks S2.1–S2.5. Slice scope: the Maine coastline, nights 1–5, lighthouse (sweep and sector), buoy, foghorn, 3 hulls, 6 upgrades, placeholder art in the final palette, simple Metal fog (or a SpriteKit alpha overlay if Metal is not ready; log an ADR).

- **BCN-P2.1 Board scene.** `BoardScene` renders tiles, depth tint, ships with interpolated positions, aids, beams as translucent cones, and fog. Acceptance: snapshot tests at four device sizes.
- **BCN-P2.2 Heading lines and warnings.** Every ship draws a faint line along its next 8 path tiles; segments crossing an unknown tile that is truly a hazard for that ship turn `#E0533D` and pulse. (This deliberately shows the player hidden truth along a path, which is what makes failures fair; pillar 3.) Acceptance: UI test asserts the warning node appears ≥ 120 ticks before a scripted wreck.
- **BCN-P2.3 Touch interactions.** Drag from the inventory tray to place; drag a placed aid to move; two-finger twist on a lighthouse to set heading; tap a lighthouse to cycle pattern (Harbor Phase only); press and hold for an info card; two-finger tap anywhere to pause. Mouse: drag, scroll wheel or ⌥-drag to rotate, right-click for info, Space to pause.
- **BCN-P2.4 HUD.** Score, night number, night progress ring, reputation lanterns, tide gauge, speed buttons, pause. Acceptance: all HUD controls have accessibility identifiers.
- **BCN-P2.5 Harbor Phase screen.** Two upgrade cards, a "Set Sail" button, and drag-to-rearrange aids. Acceptance: XCUITest picks an upgrade and starts night 2.
- **BCN-P2.6 Results screen.** Score, nights, ships docked by hull, cause of end with a replay of the last 5 seconds (ring buffer of render states, no re-simulation needed).

Slice-specific G2 checks: (a) a new tester docks ≥ 5 ships on night 1 with no instructions (playtest; `_CONVENTIONS.md` §8.2); (b) a full scripted run to wreck plays in XCUITest on iPad and Mac; (c) fog and beams read clearly in screenshots at iPad 11".

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest: launch → night 1 → Harbor Phase → night 2 → scripted wreck → results, on iPad and Mac
  [ ] Debug overlay shows ≥ 60 fps on iPad Pro 13" simulator with 20 ships and 4 fog banks
  [ ] Save mid-night, kill app, resume → identical state hash
  [ ] Heading-line warning precedes every wreck in 200 sim runs (INV-8 visual equivalent)
  [ ] docs/media/slice.mp4 recorded
Sign-off: GLM-SELF
```

### P3 Content and Systems

- **BCN-P3.1 Full aids and patterns.** Flash pattern, bell buoys, and all modifiers. Acceptance: rule tests updated; content-lint validates `aids.json`.
- **BCN-P3.2 Hulls.** All 6 hull classes with sprites (placeholder) and tier gating.
- **BCN-P3.3 Upgrades.** 18 upgrades including `salvage_tug` and `pilot_boat`. Acceptance: each upgrade has a rule test and a description string.
- **BCN-P3.4 Coastlines.** Cornwall, Hokkaido, and Brittany handcrafted (GLM authors them in the in-app Debug Coast Editor, BCN-P3.5); each validated by flood fill.
- **BCN-P3.5 Debug Coast Editor** (debug builds only). Paint tile kinds and depth, place harbors and spawns, export JSON. Acceptance: exported JSON passes content-lint.
- **BCN-P3.6 Night tiers 1–8** in `nights.json`.
- **BCN-P3.7 Tutorial.** Night 0 on a tiny map: three scripted beats (place a lighthouse, a buoy on a hidden reef, a foghorn for a lost ship). No text walls; one short line per beat. Acceptance: XCUITest completes the tutorial.
- **BCN-P3.8 Weekly mutators.** 12 mutators.

```
GATE G3 — Content and Systems
Checks:
  [ ] Content counts: 6 hulls, 3 aids × patterns, 18 upgrades, 4 handcrafted coasts, 8 tiers, 12 mutators
  [ ] content-lint: 0 errors; every content ID referenced by code exists
  [ ] Tutorial completes in XCUITest on iPad and Mac
  [ ] All rule tests green; Core coverage ≥ 90%
Sign-off: GLM-SELF
```

### P4 AI Opponents

For Beacon Coast this phase builds the bots and generators in §7.

- **BCN-P4.1 AutoPilot tiers** (novice, competent, expert).
- **BCN-P4.2 Navigator performance.** Round-robin replanning cap; measure with 30 ships.
- **BCN-P4.3 CoastGenerator** with 3 templates (`fjord`, `cape`, `archipelago`).
- **BCN-P4.4 Balance sims.** `make balance` runs 500 runs per coastline per bot tier and writes `docs/BALANCE.md`.

```
GATE G4 — AI and Generators
Checks:
  [ ] AutoPilot soak: 500 runs × 3 tiers × 4 coasts, 0 crashes, 0 illegal actions
  [ ] Target metrics in §6 met or deviations listed with a proposed balance change
  [ ] CoastGenerator: 1,000 seeds, 100% pass flood-fill validation, p95 ≤ 200 ms on CI Mac
  [ ] Navigator ≤ 1.0 ms per tick at 30 ships (measure test)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability

- **BCN-P5.1 Daily fog** (`DailySeed`, `DailyFogGenerator`, verifier). One attempt counts for the leaderboard; unlimited practice attempts after.
- **BCN-P5.2 Weekly challenge.** One mutator plus one coast per ISO week (UTC).
- **BCN-P5.3 Unlocks.** Coastlines unlock by total ships docked (Maine free; Cornwall 50; Hokkaido 150; Brittany 300; procedural "Uncharted" 500). All unlocks are earnable; no purchases.
- **BCN-P5.4 Stats.** Lifetime ships by hull, best score per coast, nights survived histogram, wrecks by cause.
- **BCN-P5.5 Local leaderboards** with a `LeaderboardService` protocol ready to bind to Game Center in P7 (IDs `bcn.daily`, `bcn.weekly`, `bcn.best.<coast>`).
- **BCN-P5.6 Endless sandbox.** No wrecks end the run (wreck costs 1 reputation instead); scores excluded from leaderboards.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily seeds for the next 60 days generate and verify in CI (expert survives ≥ 3 nights each)
  [ ] Same daily seed produces identical maps on iPad and Mac (hash compare)
  [ ] Unlock thresholds reachable: expert bot hits Brittany unlock within 25 sim runs
  [ ] All standard tests and coverage thresholds (§5 of conventions) pass
  [ ] docs/HANDOFF.md complete (all 10 items in conventions §9 plus §9 below)
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass

- **BCN-P6.1** Final Metal fog pass: two octaves of animated noise inside fog density, beam scattering (brighter where fog is thicker), and a soft vignette. GLM implements.
- **BCN-P6.2** Final coastline art per region (Maine granite and spruce, Cornwall cliffs, Hokkaido snow, Brittany standing stones as land silhouettes); palettes per coast within the master palette.
- **BCN-P6.3** Ship silhouettes, wake trails, and the docking glow.
- **BCN-P6.4** Music stems (3 per tier band) and SFX set; mix with ducking on wreck.
- **BCN-P6.5** Haptics AHAP set.

```
GATE G6 — Aesthetics
Checks:
  [ ] Pillar 1 screenshot test: 10 random frames saved to `docs/media/`, the next hazard identifiable in each within 5 s (GLM self-assessment; human check playtest; `_CONVENTIONS.md` §8.2)
  [ ] 120 fps on iPad Pro (M4) with final fog at 30 ships
Sign-off: GLM-SELF
```

### P7 Platform Features

- **BCN-P7.1 Apple Pencil.** Hover over a lighthouse previews its beam for the next 120 ticks as a faint swept area (preview only, never commits). Squeeze opens the inventory palette at the tip. Pencil drag places and moves aids. Finger fallback for everything.
- **BCN-P7.2 Game Center.** Auth, leaderboards (`bcn.daily`, `bcn.weekly`, four coast bests), 20 achievements, and Game Center challenges bound to the daily leaderboard.
- **BCN-P7.3 iCloud.** Sync stats, unlocks, and an in-progress run; conflict rule: keep the run with the higher tick for the same seed, else the newest.
- **BCN-P7.4 Mac.** Menus (Game, View, Speed), keyboard shortcuts (1/2/3 speeds, Space pause, B/U/F select aid), window resize with letterboxing by map aspect, full screen.
- **BCN-P7.5 Controller (optional).** Cursor-based control; only if time allows (ADR).

```
GATE G7 — Platform
Checks:
  [ ] Pencil hover never mutates state (unit test on adapter + UI test)
  [ ] Game Center sandbox: submit and read back scores for daily and one coast
  [ ] iCloud: run started on iPad resumes on Mac with identical hash
  [ ] Mac: every action reachable by keyboard
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance

- **BCN-P8.1** Color-blind modes: warning lines also dash; hazards use a hatch pattern; beam color stays warm but warning switches to magenta `#D14FD1` in deuteranopia mode.
- **BCN-P8.2** VoiceOver: aids, ships (hull, state, distance to harbor), and an audio "next danger" readout on demand.
- **BCN-P8.3** Reduce Motion: fog animation static noise, no screen shake.
- **BCN-P8.4** Slow mode (0.5×) as an accessibility option; leaderboards still allowed (speed does not change rules).
- **BCN-P8.5** Real-device perf in `docs/PERF.md` for iPad (A16), iPad mini (A17 Pro), iPad Pro (M4), iPhone, and a MacBook Air.

```
GATE G8 — Polish
Checks:
  [ ] Conventions §7 budgets met on real devices (PERF.md)
  [ ] Accessibility Inspector audit: 0 issues on main screens
  [ ] Color-blind simulation screenshots reviewed
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight

- **BCN-P9.1** Internal TestFlight build.
- **BCN-P9.2** Opt-in stats export (a JSON file the tester shares manually): nights, cause of end, coast, and upgrade picks.
- **BCN-P9.3** Balance passes from exported stats; update `balance.json` only through PRs with sim evidence.
- **BCN-P9.4** External group is a maintainer item (`_CONVENTIONS.md` §8.2).

```
GATE G9 — Beta
Checks:
  [ ] Crash-free sessions ≥ 99.5% over ≥ 200 sessions
  [ ] Median tester run 8–15 min; ≥ 70% of testers finish the tutorial
  [ ] No open S1/S2 issues
Sign-off: GLM-SELF
```

### P10 Release Prep

- **BCN-P10.1** App Store metadata draft (name, subtitle, keywords, description), 10 screenshots per size class, a 30-second app preview from a scripted replay.
- **BCN-P10.2** Privacy label (Data Not Collected; Game Center is Apple's), age rating draft (expected 4+), accessibility nutrition labels.
- **BCN-P10.3** Press kit: fact sheet, 6 key-art frames, GIFs of fog clearing.

```
GATE G10 — Release
Checks:
  [ ] Release candidate passes the full CI and a clean-install smoke on all device classes
  [ ] All metadata drafts self-reviewed for copy and technical accuracy against the build
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

Emphasize in `docs/HANDOFF.md`:

- The **heading-line warning** logic (BCN-P2.2) is the fairness backbone; any change needs a sim proving INV-8 still holds.
- **Fragile areas:** angle wraparound at 0/4096 in beam coverage; A* replanning budget under heavy fog (ships can visibly stall if the round-robin starves); the tide boundary where a reef becomes exposed mid-path.
- **Fixed vs float:** Render interpolates positions with `Float`; it must never write back to Core.
- **Priorities for P6–P10:** read `docs/BALANCE.md` and tune nights 4–8 toward the expert target; replace the placeholder fog with the final Metal pass and profile on an A16 iPad.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too similar to Mini Metro in the eyes of players and press | Medium | Medium | Lean on light geometry and fog visuals in all marketing; light is the verb (pillar 2) | GLM |
| Wrecks feel random in thick fog | Medium | High | INV-8 plus heading-line warnings; sim assertion in CI | GLM |
| Metal fog pass too expensive on A16 | Low | Medium | Fog texture is one texel per tile; fall back to SpriteKit alpha overlay | GLM |
| A* cost spikes with many ships | Medium | Medium | Round-robin cap; cache paths; measure test in CI | GLM |
| Dailies occasionally unwinnable | Low | High | Verifier with expert bot and salted retries | GLM |
| Real-world coast names imply accuracy | Low | Low | Call them "inspired by"; no real map data | GLM |

## 11. Out of Scope

- Multiplayer of any kind.
- A level editor in release builds (the Debug Coast Editor stays debug-only).
- Real geographic data or real lighthouse names.
- Weather beyond fog, wind, and tide (no storms or ice) in v1.0.
- In-app purchases, ads, or cosmetic stores.
- Android or web builds.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 6–9 |
| P2 Vertical Slice | GLM | 6–9 |
| P3 Content and Systems | GLM | 6–9 |
| P4 AI and Generators | GLM | 4–6 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GLM | 8–12 |
| P7 Platform | GLM | 4–6 |
| P8 Polish | GLM | 5–7 |
| P9 Beta | GLM | 5–10 |
| P10 Release | GLM | 2–4 |
| **Total** | | **52–81** |

## 13. Open Questions

1. Should one wreck always end the run, or should the base game grant one free wreck? **Default:** one wreck ends the run; `salvage_tug` upgrade provides the exception.
2. Is a fourth aid type (a radio beacon unlocked late) wanted for v1.0? **Default:** no; listed in Out of Scope until after launch.
3. Display typeface for titles? **Default:** SF Pro Display Light, wide tracking.
4. Are regional names (Maine, Cornwall, Hokkaido, Brittany) acceptable, or should coasts be fictional? **Default:** "inspired by" real regions, with fictional harbor names.
5. Price point? **Default:** none set by agents; a maintainer decision; GLM leaves the price unset.
