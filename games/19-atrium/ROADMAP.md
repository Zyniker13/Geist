# 19 — Atrium Roadmap

> Build a vertical solarpunk arcology where every new floor steals sunlight and air from the gardens below.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 in full before starting. This roadmap only adds what is specific to Atrium.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 19 · `atrium` |
| Code prefix | `ATR` (packages `ATRCore`, `ATRContent`, `ATRAI`, `ATRRender`, `ATRAudio`, `ATRPlatform`, `ATRMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Vertical city builder with roguelite runs |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 20–40 min per run (30 in-game days) |
| Renderer | RealityKit (3D) via `RealityView`, plus a Metal 4 compute pass for the light-bake visualization texture (`ATRRender/LightBake`) |
| Players | Solo only |
| Simulation | Turn-based days; light and air are solved per day on an integer voxel grid in Core |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Build a vertical solarpunk arcology where every new floor steals sunlight and air from the gardens below.

**Summary:** Each run starts on a site (canyon, coast, or ruin) with a small footprint grid and a sky. Every day the player draws module cards (homes, farms, workshops, light wells, vents, solar sails, bridges, and sky-train docks) and stacks them into a tower on a voxel grid. At dusk the day resolves: Core traces the sun's path through the grid to compute daylight hours per cell, solves a simple airflow model through open faces, vents, and atria, checks structural load down each column, and residents react. Happy residents attract more residents and produce; dark, stuffy, or crowded cells breed unrest. Every five days the player picks a cornerstone (a run-defining perk). A run is won by meeting the site's charter goals by day 30.

**Pillars:**

1. **Every floor has a shadow.** Each placement visibly changes light and air below; the preview before placing shows the cost in gold-to-gray light values.
2. **Beautiful by construction.** Any tower the rules allow should look like solarpunk architecture, not a pile of boxes (modules auto-dress based on neighbors, Townscaper-style).
3. **Readable systems.** Three lenses (light, air, load) explain every problem with one tap.
4. **Short, sharp runs.** Thirty days, five cornerstones, and a clear win condition; no endless sprawl.
5. **Hopeful tone.** Failure is gentle (residents leave, the charter is unmet) and never apocalyptic.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | White ceramic `#F3F0E8`, warm ceramic shadow `#D9D2C3`, copper `#B87333`, verdigris `#4FA38A`, leaf green `#5DAA4F`, deep foliage `#2F6B3A`, sky dawn `#F6C9A8`, sky noon `#A9D3F0`, sky dusk `#E59A7B`, light lens gold `#FFD35C`, shadow lens gray `#6E7380`, air lens cyan `#5FD3E6`, load lens red `#E0533D` |
| Shapes | Rounded ceramic shells, copper ribs, arched openings, hanging gardens; modules auto-dress with balconies, planters, and bridges depending on neighbors |
| Typography | SF Pro Rounded; titles in a light geometric face (default SF Pro Display Thin) |
| Motion | Day cycle sweeps the sun across the sky in 6 seconds at dusk resolution; light bands move across facades; leaves sway |
| Music | Ambient choir and soft synths with birdsong that grows with greenery |
| SFX | Ceramic clinks on placement, wind through vents, sky-train chimes, residents' murmur |
| Haptics | Soft snap on placement; low creak pattern on load warnings |

**Inspirations:** Against the Storm's run structure, Townscaper's modular charm and auto-dressing, and solarpunk architecture.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** RealityKit 3D (the concept requires rotating a tower and cutaways). Modules are instanced meshes from a small kit; auto-dressing chooses mesh variants by neighbor masks (computed in `ATRRender`, never in Core).
- **Light solving:** Core computes daylight on an integer voxel grid by 3D DDA ray marching from each cell toward 12 fixed sun directions per day (integer direction vectors per site latitude, committed in `sites/*.json`). Results are integer "light hours" 0–12 per cell face. Metal compute only converts Core's per-cell values into a smooth lightmap texture for display.
- **Airflow:** graph flow over open cells (BFS from open faces with decay), not fluid simulation.
- **Load:** column-based integer accumulation with lateral transfer via bridges.
- **Turn-based** with no ticking clock.

ADRs to create in P0:

- ADR-0003 RealityKit as the renderer (3D) and instanced module kit.
- ADR-0004 Integer voxel light model with 12 sun samples.
- ADR-0005 Graph-based airflow approximation.
- ADR-0006 Auto-dressing lives in Render only.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── ATRCore/Sources/ATRCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Voxel.swift (IVec3), DDA.swift
│   ├── Site/         Site.swift (footprint mask, terrain heights, latitude, prevailing wind), SunPath.swift
│   ├── Grid/         TowerGrid.swift, Cell.swift, Module.swift, ModuleKind.swift, Placement.swift
│   ├── Systems/      LightSolver.swift, AirSolver.swift, LoadSolver.swift, Adjacency.swift, Production.swift
│   ├── People/       Residents.swift, Culture.swift, Happiness.swift, Migration.swift
│   ├── Economy/      Resources.swift (ceramic, copper, soil, energy, food, goods), SkyTrain.swift, Trade.swift
│   ├── Run/          RunState.swift, Charter.swift, Cornerstone.swift, Deck.swift (module cards), DayPhase.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── ATRContent/       ModuleDef.swift, SiteDef.swift, CultureDef.swift, CornerstoneDef.swift, CharterDef.swift, Loader.swift
├── ATRAI/            BuilderBot.swift, PlacementScorer.swift, CharterGenerator.swift, DailyVerifier.swift
├── ATRRender/        TowerView.swift (RealityView), ModuleKit.swift, AutoDress.swift, Lenses.swift, LightBake/LightBake.metal, Cutaway.swift, PreviewGhost.swift
├── ATRAudio/         Ambience.swift, Choir.swift
├── ATRPlatform/      PencilSketch.swift, GameCenterService.swift, CloudSaveService.swift
└── ATRMeta/          Progression.swift, DailySite.swift, Stats.swift, Gallery.swift (tower snapshots)
Resources/Content/    modules.json, sites/*.json, cultures.json, cornerstones.json, charters.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Site and Grid

- **R-1 Grid.** The tower grid is `W × D × H` cells (default 8 × 8 × 24). A site defines a footprint mask (buildable ground cells), terrain height per column (0–4 cells, e.g., canyon walls), latitude band, prevailing wind direction (one of 4), and 12 sun direction vectors.
- **R-2 Cells.** A cell is empty or holds one module. Modules occupy 1 cell, or 2 cells (horizontal or vertical) for `atrium_garden` and `sky_dock`.
- **R-3 Support.** A module must rest on ground (z = terrain height of its column) or on a module below, or be attached to a bridge or cantilever (R-21). Unsupported placements are illegal.

### 4.2 Day Structure

- **R-4 Day phases.** (1) **Dawn:** draw module cards to hand size 5, receive resource income. (2) **Build:** place modules (paying their cost), demolish (refund 50%), or play cornerstone actions. (3) **Dusk:** solve light (R-7), air (R-11), load (R-15), then production (R-19), residents (R-24), trade (R-28), and events. (4) **Night:** charter progress check; every 5th night offer cornerstones (R-31).
- **R-5 Run length.** 30 days. Day 30's night is the final check.
- **R-6 Deck.** The module deck starts with the site's starter list (20 cards). Discarded and played cards cycle; new cards join from rewards and cornerstones. The player may discard up to 2 cards per day to redraw (once).

### 4.3 Light

- **R-7 Sun samples.** For each of 12 sun directions `s_i` (integer vector), a cell face facing outward is lit for sample *i* if a 3D DDA ray from the face center toward `s_i` reaches the grid boundary without entering a solid cell. Solid = module of kind not `glass` and not `light_well`. Terrain columns are solid up to their height.
- **R-8 Light hours.** A cell's light hours `L` = number of samples for which at least one of its exterior faces is lit, plus light delivered by light wells (R-9), capped at 12.
- **R-9 Light wells.** A light well module passes light vertically: it gathers `L_top` = light hours at the topmost well cell of a vertical chain (if open to the sky) and delivers `max(L_top − 2 × depth, 0)` to each adjacent cell at depth `depth` below the top. Mirror upgrades reduce loss to 1 per depth.
- **R-10 Light needs.** Each module has `lightNeed` (homes 4, farms 7, workshops 2, gardens 6). A module with `L < lightNeed` produces at `L / lightNeed` efficiency (integer percent, floored) and its residents lose happiness (R-25).

### 4.4 Air

- **R-11 Air sources.** An empty cell adjacent to the grid boundary on the windward side, or any open terrace (empty cell open to the sky), is an air source with value 10 (windward) or 7 (other sides and above).
- **R-12 Air propagation.** Air spreads by BFS through empty cells, `vent` modules, `atrium_garden` modules, and `light_well` modules. Each step reduces value by 1 (vents and atria by 0). An occupied module's air value is the max value of its adjacent air cells.
- **R-13 Air needs.** Homes need air ≥ 4, farms ≥ 3, workshops ≥ 5 (they produce heat), and workshops reduce adjacent cells' air by 2 (stacking to −4).
- **R-14 Gardens purify.** Each garden or farm adjacent to an air path adds +1 to cells within 2 steps along that path (max +3).

### 4.5 Load

- **R-15 Weight and strength.** Each module has `weight` and `strength`. The load on a module is the sum of weights of all modules it supports (recursively, through vertical stacking and supported bridges).
- **R-16 Stress.** If load > strength, the module is **stressed**. Stressed modules show a crack; at the next Dusk, if still stressed, the module **fails**: it and everything it supports that has no other support path are removed, residents displaced.
- **R-17 Columns.** `column` modules have high strength, no function, and allow a future floor to bear much more weight; `ceramic_shell` upgrades increase a module's strength by 50%.
- **R-18 Load sharing.** A module supported by two or more modules splits its weight equally among them (integer division; remainder to the lowest cell index).

### 4.6 Production and Resources

- **R-19 Production.** At Dusk each module produces per `modules.json` at its efficiency = `min(lightEff, airEff, staffEff)`. Staff efficiency = assigned residents / required residents.
- **R-20 Resources.** `ceramic` and `copper` (building), `soil` (needed by farms and gardens at placement), `energy` (solar sails produce `L` energy; workshops consume), `food` (farms produce; residents consume 1 each per day), and `goods` (workshops produce; trade and happiness).
- **R-21 Bridges and cantilevers.** A `bridge` connects two modules at the same height up to 3 cells apart; cells along it count as supported for the modules placed on top. A `cantilever` extends one cell sideways from a supported module with strength 3.
- **R-22 Deficits.** If food < 0 at Dusk, residents lose 2 happiness each; if energy < 0, workshops produce at 50%.
- **R-23 Income.** Dawn grants base income from the site (ceramic 4, copper 2, soil 1) plus trade deliveries (R-28).

### 4.7 Residents

- **R-24 Residents.** Homes hold 4 residents each. Residents belong to cultures (from `cultures.json`) with preferences (e.g., `canopy` prefers light ≥ 8 and gardens nearby; `forge` prefers workshop adjacency).
- **R-25 Happiness.** Each home has happiness 0–10 computed each Dusk: `+2` if light ≥ need, `+2` if air ≥ need, `+1` per adjacent garden (max 2), `+1` per culture preference met, `−2` if adjacent to more than 2 workshops, `−2` for food deficit, `−1` if stressed; base 3.
- **R-26 Migration.** At Night, each home with happiness ≥ 7 and free capacity attracts 1 resident (if any home has capacity); each home with happiness ≤ 2 loses 1 resident. Arrivals are assigned cultures by the site's culture weights (run RNG).
- **R-27 Staffing.** Residents are assigned to jobs automatically each Dusk: nearest-first by path through the tower (vertical moves via `lift` modules cost 1, stairs within 2 floors free), farms and food first, then workshops, then others.

### 4.8 Trade and Sky-Trains

- **R-28 Sky docks.** A `sky_dock` placed at height ≥ 6 with an open face toward the site's trade direction opens a trade line. Each dock allows one standing trade order per day (e.g., 3 goods → 4 copper) from `trades` in the site file.
- **R-29 Delivery.** Trade orders resolve at Dawn of the next day.

### 4.9 Charters, Cornerstones, and Events

- **R-30 Charter.** A run's charter has 3 goals (e.g., "house 60 residents," "average happiness ≥ 6," "12 farms with light ≥ 7") drawn from `charters.json` weighted by site. Meeting all 3 by day 30 wins; meeting 2 earns a partial result.
- **R-31 Cornerstones.** On nights 5, 10, 15, 20, and 25 the player picks one of three cornerstones (perks), e.g., `mirror_guild` (light wells lose 1 per depth), `wind_temple` (+2 air on all windward sources), `ceramic_kilns` (+50% strength on new homes), `market_spire` (trade orders ×1.5).
- **R-32 Events.** Nights may draw an event (run RNG, weighted): `dust_storm` (air sources −3 for a day), `pilgrims` (+8 residents if capacity), `heat_wave` (workshops −2 air extra), `seed_exchange` (free garden card), `quake` (each module with load ≥ 80% of strength becomes stressed).

### 4.10 Edge Cases

- **R-33** Demolishing a module that supports others is illegal unless every supported module has another support path.
- **R-34** A failure cascade (R-16) resolves top-down in cell index order; displaced residents enter a homeless pool (−3 happiness to all homes in the next Dusk if not rehoused).
- **R-35** Sun rays exactly along a grid line use the DDA tie rule: step x before y before z.
- **R-36** Light wells not open to the sky deliver 0.

### 4.11 Invariants

- **INV-1** Every module has a support path to the ground at the end of each Dusk.
- **INV-2** `0 ≤ L ≤ 12`, `0 ≤ air ≤ 10`, `0 ≤ happiness ≤ 10` for all cells and homes.
- **INV-3** Residents ≤ total home capacity + homeless pool.
- **INV-4** Light solution is independent of module placement order (shuffle test).
- **INV-5** Removing a module never decreases any other cell's light (monotonicity; property test).
- **INV-6** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var day: Int; public var phase: DayPhase; public var rng: SeededRNG
    public var site: SiteID; public var grid: TowerGrid       // [Cell] dense, W*D*H
    public var light: [UInt8]; public var air: [UInt8]; public var load: [UInt16]   // derived each Dusk; hashed
    public var resources: Resources; public var residents: Residents
    public var hand: [CardID]; public var deck: [CardID]; public var discard: [CardID]
    public var charter: Charter; public var cornerstones: [CornerstoneID]; public var tradeOrders: [TradeOrder]
}
public enum Action: Codable, Equatable, Sendable {
    case place(CardID, origin: IVec3, orientation: Orientation), demolish(IVec3)
    case redraw([CardID]), setTrade(dock: IVec3, TradeID), chooseCornerstone(Int), endDay
}
public enum Event: Codable, Equatable, Sendable {
    case placed(ModuleID, IVec3), demolished(IVec3), lightSolved(changed: Int), airSolved(changed: Int)
    case stressed(IVec3), failed([IVec3]), produced(Resources), residentsMoved(arrived: Int, left: Int)
    case eventDrawn(EventID), cornerstoneOffered([CornerstoneID]), charterProgress([Int]), runEnded(RunResult)
}
```

### 5.2 Content Tables

**`modules.json`** — G3: 18 modules; G5: 28.

```json
{ "id": "home_terrace", "kind": "home", "size": [1,1,1], "cost": { "ceramic": 3, "copper": 1 },
  "weight": 3, "strength": 9, "lightNeed": 4, "airNeed": 4, "capacity": 4,
  "solid": true, "produces": {}, "staff": 0, "dressTags": ["balcony", "planter"] }
```

Modules (v1.0): `home_terrace`, `home_canopy`, `farm_hydro`, `farm_orchard`, `garden_hanging`, `atrium_garden`, `workshop_kiln`, `workshop_loom`, `solar_sail`, `light_well`, `mirror_well`, `vent`, `column`, `bridge`, `cantilever`, `lift`, `glass_conservatory`, `sky_dock`, `library`, `bathhouse`, `market_hall`, `school`, `water_tower`, `wind_spire`, `seed_vault`, `observatory`, `chapel_of_light`, `rope_garden`.

**`sites/*.json`** — G3: 2 (canyon, coast); G5: 3 (+ ruin) plus procedural variants by seed (footprint, terrain heights).

```json
{ "id": "coast", "footprint": "base64 8x8 mask", "terrain": [0,0,0,0,1,1,2,2, …], "latitude": "temperate",
  "sun": [[-6,2,3],[-5,3,4],[-3,4,6],[-1,5,7],[1,5,7],[3,4,6],[5,3,4],[6,2,3],[-4,1,2],[4,1,2],[0,6,8],[0,4,5]],
  "wind": "west", "income": { "ceramic": 4, "copper": 2, "soil": 1 }, "trades": ["goods_for_copper", "food_for_ceramic"],
  "cultures": { "canopy": 3, "forge": 2, "tide": 3 } }
```

**`cultures.json`** — G5: 5. **`cornerstones.json`** — G3: 15; G5: 30. **`charters.json`** — G3: 12 goals; G5: 24.

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `grid.size` | 8×8×24 | 6–10 × 6–10 × 16–32 | balance.json |
| `run.days` | 30 | 20–40 | balance.json |
| `hand.size` | 5 | 4–6 | balance.json |
| `light.wellLossPerDepth` | 2 | 1–3 | balance.json |
| `air.windwardSource` | 10 | 8–12 | balance.json |
| `air.workshopPenalty` | 2 | 1–3 | balance.json |
| `happiness.base` | 3 | 2–4 | balance.json |
| `migration.attractThreshold` | 7 | 6–8 | balance.json |
| `migration.leaveThreshold` | 2 | 1–3 | balance.json |
| `demolish.refund` | 50% | 25–75% | balance.json |
| Module stats | per table | ±30% | modules.json |

**Target metrics (sims, ≥ 1,000 runs per site per bot tier):**

| Metric | Target |
| --- | --- |
| `BuilderBot.greedy` full charter wins | 15–30% |
| `BuilderBot.planner` full charter wins | 55–70% |
| Median tower height at day 30 (planner) | 12–18 floors |
| Runs with ≥ 1 structural failure (greedy) | 30–50% (load matters) |
| Share of planner wins using ≥ 2 light wells | ≥ 50% (pillar 1) |
| Cornerstone pick rates (planner) | each ≥ 2% |

## 7. AI Approach

No opponent; AI provides bots for sims and the charter generator and verifier.

| Component | Algorithm | Budget |
| --- | --- | --- |
| `BuilderBot.greedy` | For each card in hand, try every legal placement; score by immediate production + happiness delta after a full Dusk solve; play the best until resources run out | sim only, ≤ 200 ms/day |
| `BuilderBot.planner` | Beam search (width 6) over sequences of up to 3 placements per day; scoring includes charter progress and a lookahead penalty for blocked light on future farm slots | sim only, ≤ 2 s/day |
| `CharterGenerator` | Draws 3 goals by site weights; rejects combos the planner fails in all of 8 seeds | ≤ 10 s offline per daily |
| `DailyVerifier` | Daily site seed → planner must win ≥ 2 of 4 seeds | precomputed in CI for 60 days |

**Performance note:** Dusk solves (light + air + load) for a full 8×8×24 grid must complete in ≤ 30 ms on iPad (A16) for play and ≤ 5 ms on CI Mac for bot sims; use incremental recomputation of only affected columns and ray caches keyed by solid-mask hash.

## 8. Phases, Tasks, and Gates

### P0 Setup

Standard tasks S0.1–S0.7.

- **ATR-P0.1 IVec3 and integer 3D DDA.** Acceptance: known-answer traversal tests including tie cases (R-35).
- **ATR-P0.2 RealityKit placeholder scene** with orbit camera on iPad (one-finger rotate, pinch zoom) and Mac (drag rotate, scroll zoom).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; DDA tests pass
  [ ] RealityView renders a test grid on iPad simulator and Mac
  [ ] RULES.md contains R-1…R-36 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype

Standard tasks S1.1–S1.4.

- **ATR-P1.1 Light solver (R-7–R-10, R-35, R-36).** Acceptance: golden light maps for 15 fixture towers; INV-4 and INV-5 property tests; ≤ 5 ms full solve on CI Mac.
- **ATR-P1.2 Air solver (R-11–R-14).** Golden fixtures.
- **ATR-P1.3 Load solver (R-15–R-18, R-21, R-33, R-34).** Acceptance: cascade fixtures.
- **ATR-P1.4 Production, resources, residents, and migration (R-19–R-27).**
- **ATR-P1.5 Deck, trade, charter, cornerstones, and events (R-4–R-6, R-28–R-32).**
- **ATR-P1.6 Sim CLI.** `Tools/sim --site coast --bot greedy --runs 1000`.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 pass over 1,000 seeds
  [ ] ATRCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
  [ ] Dusk full solve ≤ 5 ms on CI Mac (measure test)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice

Standard tasks S2.1–S2.5. Slice scope: coast site, 12 modules, 5 cornerstones, 1 charter, 30 days.

- **ATR-P2.1 Tower view.** Placeholder ceramic and copper materials; instanced modules; orbit, zoom, and floor-slice cutaway (pinch with two fingers vertically, or a floor slider).
- **ATR-P2.2 Placement.** Drag a card from the hand onto the tower; a ghost module snaps to legal cells; **preview shows light and air deltas** on affected cells as gold/gray and cyan overlays before confirming (pillar 1). Mouse: drag, scroll to change floor, R to rotate orientation.
- **ATR-P2.3 Lenses.** Light, air, and load lens toggles (tap-to-inspect any cell with the numbers).
- **ATR-P2.4 Dusk playback.** Sun sweep (6 s, skippable) with light bands; residents arrive and leave as small figures.
- **ATR-P2.5 Charter panel and results screen.**

Slice checks: a new player understands why a farm is underproducing using the light lens within one minute (playtest; `_CONVENTIONS.md` §8.2); preview deltas match Core (test).

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays a 30-day run (scripted placements) to results on iPad and Mac
  [ ] Placement preview deltas equal Core's post-place solve for 100 random placements
  [ ] ≥ 60 fps in tower view at 150 modules on iPad simulator
  [ ] Save and resume to identical hash
  [ ] docs/media/slice.mp4 recorded
Sign-off: GLM-SELF
```

### P3 Content and Systems

- **ATR-P3.1** 28 modules, 5 cultures, 30 cornerstones, 24 charter goals, events.
- **ATR-P3.2** Canyon and ruin sites; procedural site variants.
- **ATR-P3.3** Auto-dressing v1 (neighbor masks → balcony, planter, bridge, and arch variants) with placeholder meshes.
- **ATR-P3.4** Tutorial: "First Light" (place a home, block it with a farm above, fix with a light well; then a vent).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 28 modules, 3 sites, 5 cultures, 30 cornerstones, 24 goals
  [ ] content-lint 0 errors; tutorial UI test passes
Sign-off: GLM-SELF
```

### P4 AI Opponents

- **ATR-P4.1** BuilderBot greedy and planner; incremental solve caches.
- **ATR-P4.2** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — Bots
Checks:
  [ ] 1,000 runs per site per bot: 0 crashes, 0 illegal actions; targets in §6 met or documented
Sign-off: GLM-SELF
```

### P5 Meta and Replayability

- **ATR-P5.1** Daily Site (date-derived site variant, charter, and deck); one ranked attempt.
- **ATR-P5.2** Unlocks: sites and cultures by charter wins; module cards join the starter pool through progression. All earnable.
- **ATR-P5.3** Gallery: save a snapshot (camera pose + grid) of each finished tower; local only.
- **ATR-P5.4** Stats and charter history.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily Site deterministic and verified for 60 dates
  [ ] All standard tests and coverage thresholds pass
  [ ] docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass

- **ATR-P6.1** Final module kit (ceramic, copper, glass, foliage) with dressing variants; physically based materials.
- **ATR-P6.2** Light-bake visualization via Metal (smooth lightmap from Core values) and sky gradients through the day.
- **ATR-P6.3** Vegetation sway, residents, sky-trains animation.
- **ATR-P6.4** Music and ambience.

```
GATE G6 — Aesthetics
Checks:
  [ ] Pillar 2 test: 20 random planner towers rendered and saved to `docs/media/`; GLM rates ≥ 15 as "architectural" in its self-assessment; human rating playtest; `_CONVENTIONS.md` §8.2)
  [ ] 120 fps on iPad Pro (M4) at 300 modules; 60 fps on A16
Sign-off: GLM-SELF
```

### P7 Platform Features

- **ATR-P7.1 Pencil.** Sketch a vertical stroke to queue a light-well chain; hover previews a placement's light delta; squeeze toggles the lens.
- **ATR-P7.2 Game Center.** Daily leaderboard, achievements, challenges.
- **ATR-P7.3 iCloud** sync for runs and gallery.
- **ATR-P7.4 Mac.** Resizable windows, keyboard camera (WASD orbit, Q/E floor), menus.

```
GATE G7 — Platform
Checks:
  [ ] Pencil queue produces the same Actions as manual placement (test)
  [ ] Game Center sandbox and iCloud round trips
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance

- **ATR-P8.1** Lenses color-blind safe (light as brightness, air as animated particles, load as hatch).
- **ATR-P8.2** VoiceOver floor-by-floor navigation; cell readouts.
- **ATR-P8.3** Reduce Motion: no sway, sun sweep replaced by fade.
- **ATR-P8.4** Real-device perf and memory (< 1.5 GB per conventions for 3D).

```
GATE G8 — Polish
Checks:
  [ ] Budgets met on real devices; accessibility audit clean
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight; crash-free ≥ 99.5%; thermal never "serious" in 30 min on A16
Sign-off: GLM-SELF
```

### P10 Release Prep

Standard P10 tasks; the preview is a slow orbit around a finished tower through a full day.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** light solver performance and cache invalidation; load cascades (R-16, R-34); preview/solve parity.
- **Rendering:** auto-dressing quality is the single biggest lever for pillar 2; the kit pipeline deserves the most care.
- **Priorities for P6–P10:** real module kit and RealityKit performance on A16; charter tuning and cornerstone variety.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| 3D scope too large for a small team | Medium | High | Small kit with dressing variants; no free-form geometry | GLM |
| Light solve slow on A16 | Medium | Medium | Incremental columns, caches, 12 samples only | GLM |
| Towers look like boxes | Medium | High | Auto-dressing, Townscaper lessons, P6 pillar test | GLM |
| Systems feel opaque | Medium | Medium | Preview deltas and lenses | GLM |
| Thermal on long sessions | Low | Medium | 60 fps cap option on A16; static scenes idle | GLM |

## 11. Out of Scope

- Free camera walkthroughs inside the tower.
- Real fluid dynamics or real solar data.
- Multiplayer and sharing towers online.
- Endless sandbox (post-launch candidate).
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 3–4 |
| P1 Rules Engine | GLM | 10–14 |
| P2 Vertical Slice | GLM | 10–14 |
| P3 Content and Systems | GLM | 10–14 |
| P4 Bots | GLM | 4–6 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GLM | 18–26 |
| P7 Platform | GLM | 4–6 |
| P8 Polish | GLM | 6–8 |
| P9 Beta | GLM | 6–10 |
| P10 Release | GLM | 2–4 |
| **Total** | | **77–112** |

## 13. Open Questions

1. 3D (RealityKit) as specified, or a 2.5D isometric fallback to cut scope? **Default:** 3D.
2. Should there be an endless sandbox at launch? **Default:** no (post-launch).
3. Run length 30 days? **Default:** yes.
4. Gallery sharing (export an image) in v1.0? **Default:** yes, image export via the share sheet only (no online gallery).
5. Price? **Default:** the maintainer decides; GLM leaves the price unset.
