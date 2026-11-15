# 22 — Rootbound Roadmap

> Grow a fungal network beneath an old-growth forest, trading nutrients with trees for sugar while rival molds creep in from the dark.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Rootbound.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 22 · `rootbound` |
| Code prefix | `RTB` (packages `RTBCore`, `RTBContent`, `RTBAI`, `RTBRender`, `RTBAudio`, `RTBPlatform`, `RTBMeta`) |
| Bundle ID (placeholder) | `com.zyniker.rootbound` |
| Subgenre | Slow real-time strategy (pausable) on a growth network |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 20–40 min per forest (one year, four seasons) |
| Renderer | Metal 4 via `MTKView` for the whole soil board (instanced glowing threads, bloom); SwiftUI for HUD. No SpriteKit in gameplay (ADR-0003) |
| Players | Solo vs 1–3 AI rival molds; campaign of forests |
| Simulation | Fixed 10 ticks per second at 1× (slow RTS), 2× and 4× speed; integer math |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Grow a fungal network beneath an old-growth forest, trading nutrients with trees for sugar while rival molds creep in from the dark.

**Summary:** The board is a top-down slice of forest soil: patches of nitrogen, phosphorus, and water; rocks; decaying logs; and the root zones of a dozen trees. The player is a mycorrhizal fungus that grows by dragging hyphae from its network into the soil. Hyphae absorb nutrients from patches they cross; connecting to a tree's roots opens a trade, where the tree pays sugar for nutrients, generously in summer and not at all in winter. Sugar pays for growth, enzymes, and fruiting bodies, which spore new colonies elsewhere. Rival molds arrive from the edges with their own behaviors: one strangles trees, one wanders and eats threads, and one parasitizes other fungi. Network shape is strategy: a thin, efficient web is cheap but brittle; a redundant mesh survives cuts. The year ends at winter's close; the fungus with the largest living network and the most allied trees wins.

**Pillars:**

1. **The network is the army.** Topology decisions (where to thicken, where to loop, and what to abandon) decide fights more than raw size.
2. **Trees are allies with moods.** Each tree's generosity depends on its health and the season; keeping trees healthy is strategy, not decoration.
3. **Slow and calm, then tense.** Most of the game is deliberate growth; rival contact creates short spikes of tension. Pause is always available.
4. **Beautiful when idle.** The glowing network is pleasant to watch; nutrient flow pulses along threads.
5. **Readable flows.** A single lens shows where sugar and nutrients flow and where the network is fragile (bridges whose loss would cut off a region).

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Loam black `#0B0A0D`, soil umber `#1C1714`, player hyphae cyan `#3FF2E8` (core) with glow `#1B8F99`, sugar flow gold `#F7C948`, nitrogen `#7C6CF0`, phosphorus `#E86AF0`, water `#3A8DDE`, tree roots warm bark `#8A5A3B`, rival molds: strangler rust `#E0603A`, wanderer violet `#A35CFF`, parasite acid green `#A8E63F` |
| Shapes | Threads as smooth curves (Catmull-Rom through nodes) with thickness proportional to capacity; nodes as soft points; roots as branching amber lines; patches as diffuse blotches |
| Typography | SF Pro Rounded Light; titles in SF Pro Display Ultralight |
| Motion | Growth tips crawl with a slight wobble; flow pulses travel along threads; withering threads dim and crumble |
| Music | Slow drones that thicken with network size, soft crackles; a heartbeat-like pulse when rivals touch your network |
| SFX | Creaks of roots, soft pops for fruiting, fizz for enzymes, low rumble for tree death |
| Haptics | Faint tick per growth node while dragging; soft pulse on a new tree alliance; sharp tap when a bridge thread is cut |

**Inspirations:** Mini Metro's line drawing, Mindustry's logistics, and the biology of mycorrhizal networks.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** Metal 4 `MTKView` draws the board: instanced thread segments (tessellated curves), additive glow, a two-pass bloom, and patch fields from a low-resolution texture. SwiftUI overlays the HUD. Rationale: thousands of glowing segments with bloom exceed comfortable SpriteKit node counts (ADR-0003).
- **Simulation:** Core owns a graph (nodes and edges with capacities) on a continuous plane quantized to a 1/16-unit fixed grid; nutrient flow by integer diffusion iterations along edges each tick; soil fields on a 96×64 cell grid.
- **Tick:** 10 per second at 1×.
- **Audio:** generative drones in AVAudioEngine with parameters from network size and contact events.

ADRs to create in P0:

- ADR-0003 Metal-only gameplay renderer with SwiftUI HUD.
- ADR-0004 Graph-diffusion flow model (not max-flow).
- ADR-0005 Fixed-grid quantization of node positions.
- ADR-0006 10 Hz slow-RTS tick.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── RTBCore/Sources/RTBCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, FixedVec2.swift, SpatialHash.swift
│   ├── Soil/         SoilField.swift (N, P, water per cell), Rock.swift, Log.swift, Patch.swift, Regen.swift
│   ├── Network/      Node.swift, Edge.swift, Network.swift, Growth.swift, Thickness.swift, Bridges.swift (Tarjan)
│   ├── Flow/         Absorption.swift, Diffusion.swift, Upkeep.swift, Starvation.swift
│   ├── Trees/        Tree.swift, RootZone.swift, Trade.swift, Health.swift, Season.swift
│   ├── Fungi/        Species.swift, Colony.swift, Fruiting.swift, Spores.swift, Enzymes.swift, Contact.swift
│   ├── Rivals/       RivalBehavior.swift (protocol), Strangler.swift, Wanderer.swift, Parasite.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift, Tick.swift
├── RTBContent/       SpeciesDef.swift, ForestDef.swift, TreeDef.swift, MutationDef.swift, CampaignDef.swift, Loader.swift
├── RTBAI/            RivalDirector.swift, RivalPlanner.swift, PlayerBot.swift, ForestGenerator.swift, DailyVerifier.swift
├── RTBRender/        BoardRenderer.swift (MTKView delegate), ThreadMesh.swift, Bloom.metal, Threads.metal, Fields.metal, Camera.swift, Lenses.swift
├── RTBAudio/         DroneEngine.swift, ContactPulse.swift
├── RTBPlatform/      PencilRouting.swift, GameCenterService.swift, CloudSaveService.swift, HapticsService.swift
└── RTBMeta/          Campaign.swift, Mutations.swift (unlocks), DailyForest.swift, Stats.swift
Resources/Content/    species.json, trees.json, forests/*.json, mutations.json, campaign.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5. Units: positions in fixed units (1 unit = 1 soil cell), time in ticks (10 per second at 1×).

### 4.1 Setup

- **R-1 Board.** A forest board is 96×64 soil cells. Cells hold nitrogen `N`, phosphorus `P`, and water `W` (0–100 each), or are `rock` (impassable) or `log` (rich in N; slowly decays).
- **R-2 Trees.** 8–14 trees, each with a trunk position, a root zone (a set of root segments), species (oak, beech, fir, birch), health 0–100 (start 70), and a mood (`generous`, `neutral`, or `wary`) derived from health and trade history (R-20).
- **R-3 Player colony.** The player starts with one colony: a core node at a spore point and 3 short hyphae, 40 sugar, and the species chosen (R-34).
- **R-4 Rivals.** 1–3 rival molds enter from board edges at scheduled times (forest definition), each with a behavior (R-28).
- **R-5 Calendar.** The year has four seasons of `balance.season.ticks` each (default 4,500 ticks = 7.5 minutes at 1×): spring, summer, autumn, and winter.

### 4.2 Growth

- **R-6 Grow action.** The player drags from an existing node to a target point. The path is quantized into straight segments of ≤ 4 units, avoiding rocks (the UI routes around; Core validates). Growth is queued: each segment costs `growCost × length` sugar (default 2 per unit) paid when the segment starts and takes `growTicks × length` ticks (default 6 per unit) to complete, advancing from the tip.
- **R-7 Growth tips.** At most `balance.growth.maxTips` (default 4; allied trees add tips per R-22) segments grow simultaneously; extra orders wait in a queue shown on screen.
- **R-8 Thickness.** Each edge has thickness 1–3. Thickening an edge (action) costs `thickenCost × length × newLevel` sugar and takes 100 ticks. Capacity = thickness × 4 flow units per tick. Thickness also sets edge HP (10 × thickness) in contact fights (R-31).
- **R-9 Prune.** The player may prune an edge: it is removed immediately, refunding 25% of its build cost; nodes left with no edges wither (R-15).
- **R-10 Crossing.** Player edges cannot cross other player edges without a node (crossing creates a junction node automatically); they cannot cross rival edges (contact instead, R-30).

### 4.3 Absorption and Flow

- **R-11 Absorption.** Every tick, each edge absorbs nutrients from the soil cells it passes through: per cell, `min(cellValue, absorbRate × thickness)` of each of N, P, and W, distributed to the edge's two nodes. Soil values decrease accordingly.
- **R-12 Regeneration.** Soil regenerates per cell toward its base value at `regenRate` per 100 ticks (logs add N to neighbors as they decay).
- **R-13 Diffusion.** Each node holds stocks of N, P, W, and sugar. Every tick, for each edge, `flow = clamp((stock_a − stock_b) / (2 × (1 + max(deg_a, deg_b))), −capacity, capacity)` (the degree term guarantees no node can be drawn below zero in one tick) moves from the higher node to the lower one, computed for all edges from start-of-tick stocks and applied simultaneously (Jacobi iteration, integer division).
- **R-14 Upkeep.** Every 10 ticks each edge consumes `upkeep × length × thickness` sugar from its nodes (split equally). Winter upkeep ×0.5 (dormancy).
- **R-15 Starvation.** A node with 0 sugar for 100 consecutive ticks withers: it and its edges die (no refund), emitting `withered` events. Components disconnected from every sugar source (a tree trade or a colony core) starve progressively by R-14.
- **R-16 Colony core.** The core node holds up to 200 sugar and is the network's heart; if destroyed, the colony's largest connected component promotes a new core at its highest-stock node after 50 ticks; if no component has ≥ 10 nodes, the colony dies.

### 4.4 Trees and Trade

- **R-17 Root contact.** A player node within 1 unit of a root segment forms a **mycorrhizal link** with that tree (automatically, after 30 ticks).
- **R-18 Trade.** Every 10 ticks, each linked tree takes up to `need` N, P, and W from linked nodes (its demand table by species and season) and pays sugar into the linked nodes: `sugarPaid = Σ nutrients received × exchangeRate(season, mood)`. Exchange rates: spring 1.0, summer 1.5, autumn 0.8, winter 0.
- **R-19 Tree health.** Tree health changes every 100 ticks: +2 if its nutrient needs were ≥ 80% met in the period, −2 if < 40%, −5 per active strangler link (R-28), and −1 in drought events. At health 0 the tree dies; its root zone decays into a rich log patch over 600 ticks.
- **R-20 Mood.** Mood is `generous` when health ≥ 70 and the player supplied ≥ 50% of the tree's nutrients last season; `wary` when health ≤ 30 or a rival supplied more; else `neutral`. Generous trees pay ×1.25, wary ×0.75.
- **R-21 Shared trees.** A tree can link with several fungi; it splits its sugar payments in proportion to nutrients each supplied.
- **R-22 Allied trees.** A tree for which the player supplied the majority of nutrients last season is **allied**. Each 2 allied trees grant +1 growth tip (R-7).

### 4.5 Fruiting and Spores

- **R-23 Fruit.** On any node with ≥ 60 sugar and on soil with W ≥ 30, the player may fruit a mushroom (cost 60 sugar, 200 ticks to mature; not in winter).
- **R-24 Spore release.** A mature mushroom releases spores once: the player chooses a target point within radius 30; the landing point is offset by a seeded wind jitter of up to 4 units (shown as a cone before confirming). If the landing cell is not rock and not within 3 units of a rival edge, a new colony starts there (a core node with 20 sugar). Max 3 colonies per player.
- **R-25 Colonies merge.** If two of the player's colonies connect, they merge (the older core stays core).

### 4.6 Enzymes and Contact

- **R-26 Enzyme burst.** The player may target a point within 6 units of any of their nodes: cost 30 sugar, radius 3; after 20 ticks, every rival edge segment within the radius loses 15 HP. Enzymes also reduce soil N by 10 in the area (cost to the soil).
- **R-27 Defensive thickening.** Thicker edges resist: damage to thickness-3 edges is ×0.67.
- **R-28 Rival behaviors.** `strangler` (grows thick rhizomorphs toward trees; its links drain tree health per R-19 instead of trading fairly; aims for the healthiest trees), `wanderer` (a slime-like mass that moves across the board each 50 ticks, consuming any edges it overlaps at 5 HP per tick, and is repelled by enzyme bursts), and `parasite` (grows along existing fungal networks and steals sugar from any node it contacts at 2 per tick per contact).
- **R-29 Rival economy.** Rivals obey the same growth, upkeep, and starvation rules with their own sugar; their behaviors change only targeting and special abilities (asymmetric but rule-bound, no cheating at default difficulty).
- **R-30 Contact.** When a growing tip would reach a rival edge, growth stops and a **front** forms at that point.
- **R-31 Front resolution.** Every 10 ticks at each front, both sides' edges at the contact deal damage to the other: `damage = 2 + sugar stock at the nearest node / 40` (capped at 6), ×1.5 if the attacker's thickness exceeds the defender's. An edge at 0 HP dies; the front advances.

### 4.7 Seasons and Events

- **R-32 Seasons.** Spring: growth cost ×0.8. Summer: trade ×1.5 (R-18), water regeneration ×0.7 (dry). Autumn: logs fall (2–4 new log patches appear, seeded), trade ×0.8. Winter: no fruiting, trade 0, upkeep ×0.5, rival growth ×0.5.
- **R-33 Events.** Seeded per season from the forest's event table: `drought` (W regeneration ×0.3 for 600 ticks), `rainstorm` (W +30 in a region), `windfall` (a tree falls, becoming a large log), `deer_trample` (edges in a region lose 5 HP), `spring_bloom` (one tree's demand ×1.5 for a season).

### 4.8 Species and Victory

- **R-34 Player species.** The player chooses a species with a passive: `velvet_cap` (growth cost −20%), `amber_net` (thickening −30%), `ghost_lace` (enzyme radius +1, cost −10), `old_mother` (allied trees ×1.25 sugar).
- **R-35 Victory.** At the end of winter, score = living edge length / 10 + 25 × allied trees + 10 × living trees linked + 50 × eliminated rivals. The player wins if their score exceeds every rival's. **Early victory:** eliminating all rivals wins immediately. **Defeat:** all player colonies die.
- **R-36 Campaign.** The campaign is a sequence of 8 forests with growing rival pressure; each won forest grants a **mutation** (permanent perk, max 5 equipped).

### 4.9 Edge Cases

- **R-37** Growth orders whose path becomes blocked (rival edge or new log) stop at the obstacle; unspent sugar for incomplete length is refunded.
- **R-38** A node linked to a tree that dies loses the link without penalty.
- **R-39** Diffusion with negative or zero capacities (dead edges) is skipped; dead edges are removed at tick end.
- **R-40** Two fronts at the same edge merge.

### 4.10 Invariants

- **INV-1** All stocks and soil values are ≥ 0 and within caps.
- **INV-2** Total nutrients (soil + all node stocks + tree intake) change only by absorption, regeneration, enzymes, and tree consumption (conservation audit each tick in debug builds).
- **INV-3** Every living node belongs to exactly one colony component; component cores are unique.
- **INV-4** No player edges cross without a junction node.
- **INV-5** Replays deterministic across platforms (fixed-point positions).
- **INV-6** Diffusion is order-independent (shuffle edges, same result).

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var tick: Int; public var season: Season; public var rng: SeededRNG
    public var soil: SoilField                          // [UInt8] × 3 channels + kind mask
    public var trees: [TreeID: Tree]
    public var fungi: [FungusID: Fungus]                // player and rivals; each with colonies, nodes, edges, sugar
    public var growthQueue: [FungusID: [GrowthOrder]]
    public var fronts: [Front]; public var mushrooms: [Mushroom]; public var enzymes: [EnzymeBurst]
    public var events: [ActiveEvent]
}
public struct Edge: Codable, Equatable, Hashable, Sendable {
    public var id: EdgeID; public var a: NodeID; public var b: NodeID
    public var thickness: Int; public var hp: Int; public var lengthFixed: Fixed; public var cells: [CellIndex]
}
public enum Action: Codable, Equatable, Sendable {
    case grow(from: NodeID, path: [FixedVec2]), thicken(EdgeID), prune(EdgeID)
    case fruit(NodeID), releaseSpores(MushroomID, target: FixedVec2), enzyme(target: FixedVec2)
    case cancelOrder(OrderID), setSpeed(Int), pause, resume
}
public enum Event: Codable, Equatable, Sendable {
    case grew(EdgeID), withered([NodeID]), linked(TreeID, FungusID), unlinked(TreeID, FungusID)
    case traded(TreeID, FungusID, sugar: Int), treeMoodChanged(TreeID, Mood), treeDied(TreeID)
    case frontFormed(FrontID), edgeDestroyed(EdgeID, by: FungusID?), colonyFounded(FungusID, ColonyID)
    case rivalArrived(FungusID), seasonChanged(Season), eventStarted(EventID), gameEnded(Result)
}
```

### 5.2 Content Tables

**`species.json`** — player species G3: 4; rival species G3: 3 (one per behavior); G5: 5 player, 5 rival (adds `honey_crust` strangler variant and `blue_wanderer`).

```json
{ "id": "strangler_rust", "behavior": "strangler", "color": "#E0603A", "growthMul": 1.1, "upkeepMul": 0.9,
  "ability": { "treeDrainPer100": 5 }, "arrival": "edge", "aiProfile": "aggressive" }
```

**`trees.json`** — 4 species with demand tables per season.

```json
{ "id": "beech", "demand": { "spring": [6, 3, 8], "summer": [8, 4, 12], "autumn": [4, 2, 6], "winter": [0, 0, 1] },
  "rootSpread": 9, "maxHealth": 100 }
```

**`forests/*.json`** — G3: 4 handcrafted; G5: 8 campaign forests + procedural generator.

```json
{ "id": "mossy_hollow", "size": [96, 64], "soil": "base64 3×UInt8", "rocks": "base64 mask",
  "trees": [{ "species": "beech", "trunk": [30, 22] }], "playerSpawn": [12, 40],
  "rivals": [{ "species": "wanderer_violet", "arriveTick": 3000, "edge": "east" }], "events": { "summer": ["drought"] } }
```

**`mutations.json`** — G5: 20 (e.g., `deep_roots`: absorption +20% in W-rich cells; `night_glow`: rivals reveal at contact range 4).

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `season.ticks` | 4500 | 3000–6000 | balance.json |
| `growth.costPerUnit` | 2 | 1–4 | balance.json |
| `growth.ticksPerUnit` | 6 | 4–10 | balance.json |
| `growth.maxTips` | 4 | 3–6 | balance.json |
| `edge.capacityPerThickness` | 4 | 2–6 | balance.json |
| `upkeep.perUnitThickness` | 1 per 10 ticks per 10 units | ±50% | balance.json |
| `trade.rate` per season | 1.0/1.5/0.8/0 | ±0.3 | balance.json |
| `enzyme.cost` / `radius` / `damage` | 30 / 3 / 15 | 20–50 / 2–4 / 10–25 | balance.json |
| `fruit.cost` / `ticks` | 60 / 200 | 40–100 / 150–300 | balance.json |
| `starve.ticks` | 100 | 60–200 | balance.json |

**Target metrics (sims with `PlayerBot` tiers vs rival AI, ≥ 500 games per forest):**

| Metric | Target |
| --- | --- |
| `PlayerBot.basic` win rate vs normal rivals | 30–45% |
| `PlayerBot.strong` win rate vs normal rivals | 70–85% |
| Median game length (wall clock at 1×) | 25–32 min (with pauses excluded) |
| Strong-bot wins where the network has ≥ 3 cycles | ≥ 60% (pillar 1: redundancy matters) |
| Tree deaths per game | 1–3 |
| Each rival behavior's win share in 3-rival games | 25–40% |

## 7. AI Approach

| Component | Algorithm | Budget |
| --- | --- | --- |
| `RivalDirector` (per rival) | Every 30 ticks: evaluates goals (expand to a resource patch, link a target tree, attack a weak player bridge, retreat and thicken) by utility from its behavior profile; issues growth orders through the same Action API as the player | ≤ 2 ms per decision on A16 |
| `RivalPlanner` | Path planning over the soil grid (A* with costs from rock, soil richness, and enemy proximity) | ≤ 3 ms per path |
| Difficulty tiers | `gentle` (decisions every 60 ticks, 0.8× income), `normal` (30 ticks, 1.0×), `fierce` (20 ticks, 1.0×, smarter bridge targeting using Tarjan bridges of the player's network), `blight` (campaign finale: fierce + 1.2× income, the only tier with a bonus, labeled clearly) | — |
| `PlayerBot.basic/strong` | For sims only: basic grows toward richest patches and nearest trees; strong also keeps redundancy (adds a cycle when a bridge protects > 20% of nodes) and uses enzymes on fronts | sim only |
| `ForestGenerator` | Poisson-disk trees, value-noise soil, rock clusters, logs; validates that the player spawn reaches ≥ 3 trees within 30 units | ≤ 100 ms |

**Determinism:** rivals use `SplitMix64(seed ^ fungusID)`; decisions run inside the tick at fixed intervals so replays are exact.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **RTB-P0.1 FixedVec2, segment math, and spatial hash.** Acceptance: intersection and quantization tests.
- **RTB-P0.2 Metal renderer skeleton.** `MTKView` with a camera (pan, pinch zoom) drawing test segments with glow on iPad and Mac.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; Metal skeleton renders on iPad simulator and Mac
  [ ] RULES.md contains R-1…R-40 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **RTB-P1.1 Soil, absorption, and regeneration (R-1, R-11, R-12).**
- **RTB-P1.2 Network growth, thickness, prune, and crossings (R-6–R-10, R-37).**
- **RTB-P1.3 Diffusion, upkeep, starvation, cores (R-13–R-16, R-39).** Acceptance: INV-2 conservation audit, INV-6 shuffle test.
- **RTB-P1.4 Trees, trade, health, mood, and alliances (R-17–R-22, R-38).**
- **RTB-P1.5 Fruiting and spores (R-23–R-25).**
- **RTB-P1.6 Enzymes, contact, fronts (R-26, R-27, R-30, R-31, R-40).**
- **RTB-P1.7 Rival behaviors as rule modules (R-28, R-29)** with a trivial director.
- **RTB-P1.8 Seasons, events, victory (R-32–R-35).**
- **RTB-P1.9 Sim CLI** `Tools/sim --forest mossy_hollow --bot basic --games 500`.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 over 1,000 seeds
  [ ] RTBCore coverage ≥ 90%
  [ ] `make sim N=1000` (short forests): 0 crashes; identical hashes across runs and platforms
  [ ] A tick with 2,000 edges and 3 rivals ≤ 4 ms on CI Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: one forest, player species `velvet_cap`, one rival (`wanderer`), full year.

- **RTB-P2.1 Board rendering.** Threads by thickness with glow; patches; roots; rival masses; fronts flashing.
- **RTB-P2.2 Grow by dragging.** Drag from any node; the path follows the finger with auto-routing around rocks; cost and time preview; release to queue. Two-finger drag pans, pinch zooms. Mouse: drag, scroll zoom, right-drag pan.
- **RTB-P2.3 Context actions.** Tap an edge to thicken or prune; tap a node to fruit; long-press for info; enzyme button then tap target.
- **RTB-P2.4 Flow lens and fragility lens** (bridges highlighted by how many nodes they protect).
- **RTB-P2.5 HUD.** Sugar, season dial, speed controls, pause, tree list with moods.

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays a full year (scripted orders at 4× speed) to results on iPad and Mac
  [ ] ≥ 60 fps in simulator with 1,500 edges; bloom on
  [ ] Save and resume mid-season to identical hash
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — does topology matter? Are trees meaningful partners?
  [ ] REVIEW: MAHLER — calm, beautiful, and fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **RTB-P3.1** 4 player species and 5 rival species; all events.
- **RTB-P3.2** 8 campaign forests with escalating rival pressure; forest generator.
- **RTB-P3.3** Mutations (20) and the campaign map.
- **RTB-P3.4** Tutorial forest: grow, link a tree, survive winter, defend a front.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 4 + 5 species, 8 forests, 20 mutations, 5 events
  [ ] content-lint 0 errors; tutorial UI test passes
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **RTB-P4.1** RivalDirector and RivalPlanner per behavior; four difficulty tiers.
- **RTB-P4.2** PlayerBot tiers; `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] 500 games per forest per tier: 0 crashes, 0 illegal orders; rival decision p95 ≤ 2 ms (CI scaled)
  [ ] Targets in §6 met or documented
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **RTB-P5.1** Campaign progression with mutations; unlock species by campaign milestones.
- **RTB-P5.2** Daily Forest (procedural, UTC date seed, verified by strong bot winning ≥ 2 of 4).
- **RTB-P5.3** Skirmish setup (forest, rivals, difficulty).
- **RTB-P5.4** Stats: longest network, trees saved, rivals eliminated.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Daily Forest deterministic and verified for 60 dates
  [ ] All standard tests and coverage thresholds pass; docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **RTB-P6.1** Final thread shading (core plus halo, flow pulses), soil textures, root art, rival looks distinct by shape as well as color.
- **RTB-P6.2** Seasonal grading (spring green-tinted, winter frost sparkle on soil).
- **RTB-P6.3** Generative drone engine and SFX; haptics.

```
GATE G6 — Aesthetics
Checks:
  [ ] 120 fps on iPad Pro (M4) at 3,000 edges; 60 fps on A16
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **RTB-P7.1 Pencil.** Fine routing of threads with Pencil (more waypoints, precise curves); hover previews path cost; squeeze toggles lenses.
- **RTB-P7.2 Game Center.** Daily Forest leaderboard, campaign achievements, challenges.
- **RTB-P7.3 iCloud** sync.
- **RTB-P7.4 Mac.** Keyboard: Space pause, 1/2/4 speed, T thicken, P prune, E enzyme; trackpad pinch and two-finger pan.

```
GATE G7 — Platform
Checks:
  [ ] Pencil routes produce valid Actions identical to finger routes for the same waypoints
  [ ] Game Center sandbox and iCloud round trips
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **RTB-P8.1** Rival identification by pattern and outline shape; colorblind palettes.
- **RTB-P8.2** VoiceOver: tree list, colony status, fronts list with jump-to; slow-speed mode.
- **RTB-P8.3** Reduce Motion: no tip wobble; flow pulses replaced by static arrows.
- **RTB-P8.4** Thermal: 30-minute A16 session stays below "serious" (cap bloom resolution adaptively).

```
GATE G8 — Polish
Checks:
  [ ] Budgets and thermal targets met on real devices; accessibility audit clean
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight (Mahler creates records); crash-free ≥ 99.5%
  [ ] Campaign forest 1–3 completion rates match targets
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview is a time-lapse of a network spreading through a forest across a year.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** diffusion stability with large stock differences (oscillation), conservation audit, front resolution with many contacts, and Metal renderer memory with large networks.
- **First tasks:** Claude — renderer performance and thermal; Grok — rival behavior tuning and campaign pacing.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too slow or passive | Medium | High | Speed controls, rival arrival schedule, seasonal pressure | GROK |
| Flow model opaque | Medium | Medium | Flow and fragility lenses, tutorial | GLM |
| Metal-only renderer costly to build | Medium | Medium | Keep the visual vocabulary small; reuse a single thread shader | CLAUDE |
| Thermal on long sessions | Medium | Medium | Adaptive bloom and 60 fps cap option | CLAUDE |
| Rival AI unfair or dumb | Medium | Medium | Same rules as player; utility tuning in sims | GLM → GROK |

## 11. Out of Scope

- Multiplayer.
- 3D soil cross-sections.
- Real species names for rivals (use invented names).
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 3–4 |
| P1 Rules Engine | GLM | 12–16 |
| P2 Vertical Slice | GLM | 10–14 |
| P3 Content and Systems | GLM | 8–12 |
| P4 AI | GLM | 7–10 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 12–16 |
| P7 Platform | CLAUDE | 4–6 |
| P8 Polish | CLAUDE | 5–8 |
| P9 Beta | GROK + CLAUDE | 6–10 |
| P10 Release | CLAUDE + GROK | 2–4 |
| **Total** | | **73–106** |

## 13. Open Questions for Mahler

1. Metal-only gameplay renderer (more control, more work) vs SpriteKit with shaders? **Default:** Metal-only.
2. Campaign of 8 forests? **Default:** yes.
3. Use real fungus species names for the player? **Default:** invented names with an in-game note on the real biology.
4. Allow a fully paused "planning" mode where orders can be queued? **Default:** yes (pause allows all actions).
5. Price? **Default:** Mahler decides in P10.
