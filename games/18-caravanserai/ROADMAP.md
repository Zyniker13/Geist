# 18 — Caravanserai Roadmap

> Lead a camel caravan across a procedurally generated Silk Road, buying low, selling high, and choosing which oasis legends to believe.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Caravanserai.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 18 · `caravanserai` |
| Code prefix | `CVS` (packages `CVSCore`, `CVSContent`, `CVSAI`, `CVSRender`, `CVSAudio`, `CVSPlatform`, `CVSMeta`) |
| Bundle ID (placeholder) | `com.zyniker.caravanserai` |
| Subgenre | Trading roguelite with a branching route map |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 30–60 min per run (3 acts) |
| Renderer | SpriteKit (2D) with a miniature-painting style; `SKShader` for gold-leaf shimmer and heat haze |
| Players | Solo only |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Lead a camel caravan across a procedurally generated Silk Road, buying low, selling high, and choosing which oasis legends to believe.

**Summary:** A run crosses three regions (the Salt Desert, the High Passes, and the Grass Sea), each a branching map of 12–16 nodes that ends at a great city. Each leg costs days, water, and fodder, and the load camels carry slows them down. At caravanserais and cities the player trades goods whose prices drift and respond to the player's own sales and to rival caravans moving along the same roads. Information is the edge: the player remembers prices only where they have been, and rumors (some false) hint at prices elsewhere. Oases hold legends: a lost city, a singing dune, or a well of sweet water, which can be a fortune or a trap. Guards, guides, and event cards shape each leg. The run ends at the last city; the score is the fortune the player brings home.

**Pillars:**

1. **Every leg is a load-out decision.** Before each departure the player weighs water, fodder, goods, and speed. If the best choice is obvious in more than half of departures, the pillar fails.
2. **Knowledge is money.** Remembered prices, rumors, and reputation produce most of the profit; blind trading should lose money on average.
3. **Risk is chosen, not imposed.** Legends and dangerous shortcuts are opt-in with honest odds bands ("the elders say most who seek it return").
4. **The road is a painting.** Each region is a distinct miniature-painting panel; the caravan's progress across it is satisfying to watch.
5. **One more run.** Masters, relics, and a daily route keep the first hour of the next run fresh.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Lapis `#26428B`, saffron `#E3A72F`, turquoise `#3BA6A0`, vermilion `#C8452D`, sand `#E8D3A6`, rose madder `#B5566A`, ink `#231A14`, gold leaf `#D4AF37` (shader shimmer) |
| Shapes | Persian-miniature flat perspective, ornamental borders around every panel, figures with patterned textiles; route nodes as illuminated roundels |
| Typography | A naskh-inspired display face for titles only if licensing allows (Q3); default New York for titles and SF Pro for numbers |
| Motion | Caravan walks across the panel with a gentle bob; heat haze shader over desert legs; gold-leaf glints on market wares |
| Music | Oud and santur, frame drum on legs; market ambience with haggling murmurs; a distinct theme per region |
| SFX | Camel bells (pitch by caravan size), coin clinks, wind and sand, wells |
| Haptics | Coin drop per sale (batched), heavy thud on a camel loss, soft pulse on arrival |

**Inspirations:** Slay the Spire's branching run map, FTL's attrition, and classic trading games; Persian miniature painting.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit panels with parallax layers; markets as SwiftUI overlays (lists and charts read better as native UI).
- **Economy math:** integer prices (in copper `c`; 100 c = 1 silver displayed), fixed-point elasticity.
- **Time:** discrete days. No real-time play.
- **Charts:** Swift Charts for price-history sparklines in the market UI (allowed: first-party).

ADRs to create in P0:

- ADR-0003 Integer currency and price model.
- ADR-0004 Market simulation including rival caravans as market actors.
- ADR-0005 SwiftUI market overlay over SpriteKit map.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── CVSCore/Sources/CVSCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Money.swift
│   ├── Map/          RegionMap.swift, Node.swift (city, caravanserai, oasis, well, ruin, pass, camp), Edge.swift (terrain, days, hazard)
│   ├── Caravan/      Caravan.swift, Camel.swift, Crew.swift (guards, guides, handlers), Load.swift, Supplies.swift
│   ├── Market/       Good.swift, Market.swift, PriceModel.swift, Elasticity.swift, RivalCaravan.swift, PriceMemory.swift, Rumor.swift
│   ├── Travel/       Leg.swift, DailyStep.swift, Hazard.swift, Weather.swift
│   ├── Events/       EventCard.swift, Choice.swift, Outcome.swift, Legend.swift
│   ├── Run/          RunState.swift, Master.swift, Relic.swift, Reputation.swift, Score.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── CVSContent/       GoodDef.swift, RegionDef.swift, EventDef.swift, LegendDef.swift, MasterDef.swift, RelicDef.swift, Loader.swift
├── CVSAI/            MapGenerator.swift, TraderBot.swift, RoutePlanner.swift, DailyVerifier.swift
├── CVSRender/        RegionPanelScene.swift, CaravanNode.swift, RouteOverlay.swift, Shaders/
├── CVSAudio/         RegionMusic.swift, Bells.swift
├── CVSPlatform/      GameCenterService.swift, CloudSaveService.swift, PencilJournal.swift (PencilKit), HapticsService.swift
└── CVSMeta/          Progression.swift, DailyRoute.swift, Stats.swift, Codex.swift (legends and goods discovered)
Resources/Content/    goods.json, regions/*.json, events.json, legends.json, masters.json, relics.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Setup

- **R-1 Run.** Three acts, one region each. Each region is a directed acyclic node map of 7 rows (12–16 nodes) from a start node to a great city, generated from the run seed (§7).
- **R-2 Master.** The player picks a caravan master from three offered (of eight). The master sets starting silver, camels, crew, and a perk.
- **R-3 Starting caravan.** Default: 6 camels, 2 handlers, 1 guard, 0 guides, 300 silver, 12 days of water, and 12 days of fodder.

### 4.2 Caravan and Load

- **R-4 Capacity.** Each camel carries 10 load units. Water, fodder, and goods all count: 1 day of water for the whole caravan weighs `ceil(camels / 3)` units; fodder likewise. Each good has a weight per unit (`goods.json`).
- **R-5 Speed.** Base speed is 1 edge-day per day. If load > 80% of capacity, each edge takes +1 day per 3 edge-days (rounded up); if > 100%, the caravan cannot depart.
- **R-6 Crew.** Handlers: 1 per 4 camels needed; each missing handler gives each camel a 5% daily chance to stray. Guards reduce hazard damage (R-14). Guides reveal hazard types on adjacent edges and cut desert edge days by 1 (minimum 1).
- **R-7 Upkeep.** Each day consumes 1 water-day and 1 fodder-day (one each for the whole caravan). Crew wages are paid at each city: 2 silver per crew member per day elapsed since the last city.
- **R-8 Thirst and hunger.** A day without water: each camel has 25% chance to die; crew morale −2. A day without fodder: camels lose 1 strength (max 3); at 0 a camel dies.
- **R-9 Morale.** Crew morale 0–10, starts 7. Wages unpaid, thirst, and losses lower it; festivals, profitable trades (> 50% margin on a sale), and rest raise it. At 0, one crew member deserts per day.

### 4.3 Travel

- **R-10 Legs.** From a node the player chooses an outgoing edge. Each edge has terrain (`dunes`, `hardpan`, `pass`, `steppe`, `river`), base days (1–4), and a hazard rating (0–3) that is visible as a band (`safe`, `uneasy`, `dangerous`, `deadly`) only if a guide is present or the edge was rumored; otherwise shown as `unknown`.
- **R-11 Daily step.** Each travel day: (1) consume upkeep (R-7); (2) roll weather from the region table (sandstorm, heat, snow, clear); (3) roll a hazard check with probability `hazard × 10%` (+10% in bad weather); (4) resolve strays (R-6); (5) advance.
- **R-12 Weather effects.** Sandstorm: +1 day and 1 water-day lost unless sheltered (a guide shelters). Heat: water use ×2. Snow (passes): fodder use ×2 and +1 day.
- **R-13 Hazards.** A hazard draws from the region's hazard deck: `bandits`, `raiders`, `quicksand`, `rockfall`, `lame_camel`, `sickness`, and `toll`. Each has a resolution with guard checks.
- **R-14 Guard checks.** Bandit and raider strength `s` (from the card, 2–8). The caravan's defense = guards × 2 + master perk. If defense ≥ s: driven off (+morale). Otherwise lose `(s − defense) × 10%` of goods by value (random goods, seeded) or pay a toll of equal value (player's choice).

### 4.4 Nodes

- **R-15 Node kinds.** `city` (big market, recruit, buy camels, rest), `caravanserai` (small market, rest, rumors), `oasis` (water, fodder, legend), `well` (water only), `ruin` (event card, possible relic), `camp` (nomad trade with barter only), and `pass` (toll or event).
- **R-16 Rest.** Resting a day at a city or caravanserai restores +2 morale and camel strength +1 and costs upkeep; markets tick one day (R-22).
- **R-17 Supplies.** Water and fodder are bought at markets at prices that vary by node (oases sell water at 1 c per unit; deep desert caravanserais at 6 c).

### 4.5 Markets

- **R-18 Goods.** Each region has 10–14 goods (silk, spice, tea, glass, salt, horses, jade, paper, dyes, incense, wool, and so on). Each good has a weight, a base price per region, a **demand profile** per node type, and a volatility.
- **R-19 Price model.** Each market keeps, per good, `stock` and `price`. Price = `base × demandFactor(node) × (targetStock / max(stock, 1))^elasticity`, computed with `Fixed`, rounded to integer copper, clamped to `[0.25×, 4×]` base.
- **R-20 Trading.** Buying 1 unit removes 1 from stock (price rises); selling adds 1 (price falls). Quotes in the UI show the marginal price for each additional unit. A sale and buy-back in the same visit always lose at least the spread (spread 8%), so arbitrage loops are impossible.
- **R-21 Price memory.** The caravan remembers the last price it saw at each visited market per good, with the day seen. Memory is shown with age; it does not update without a visit or a rumor.
- **R-22 Market drift.** Every day, every market's stock moves toward its target by 10% plus a seeded shock (volatility × N(0,1) approximated by the sum of 4 uniform draws).
- **R-23 Rival caravans.** 3–5 rival caravans travel the region (simple agents, §7) and trade at nodes they visit, moving prices exactly as the player would. Their positions are visible only when they share a node with the player or when rumored.
- **R-24 Rumors.** At caravanserais the player may buy a rumor (5 silver) or hear one free per visit. A rumor states a price band for one good at one node, or a hazard band for one edge, or a legend hint. Rumors are true with probability `rumorTruth` (default 75%; +15% with high reputation at the source node); a false rumor shifts the band by ±2 steps.
- **R-25 Reputation.** Each city has reputation −5…+5 with the caravan. Fair trading (not dumping more than 20 units of a good in one visit), paying tolls, and delivering contracts raise it; dumping and fleeing a toll lower it. Reputation shifts prices ±1% per point and changes rumor truth.
- **R-26 Contracts.** Cities offer 1–3 contracts: deliver N units of a good to a named city within D days for a fixed reward and reputation. Failing costs reputation −2.

### 4.6 Legends

- **R-27 Legends.** Oases carry a legend (from `legends.json`) with a detour (an extra hidden branch of 1–3 days), a stated odds band (`most return`, `some return`, `few return`), and outcome tables. The true probabilities are fixed per band (most 75%, some 50%, few 25%), and the stated band is always honest (pillar 3).
- **R-28 Legend outcomes.** Success: a relic, treasure goods, a shortcut edge to a later row, or a permanent perk. Failure: lost days, water, camels, or crew. Outcomes draw from the run RNG at the moment the detour resolves.

### 4.7 Relics and Masters

- **R-29 Relics.** Passive modifiers (e.g., `astrolabe`: hazard bands always visible; `brass_scales`: spread 4%; `nomad_tent`: sandstorms never cost days). Max 6 relics.
- **R-30 Master perks.** One perk per master (e.g., `the_silk_widow`: silk prices +10% when selling; `the_old_soldier`: +2 defense; `the_cartographer`: sees one extra row ahead).

### 4.8 Acts, Scoring, and Loss

- **R-31 Act end.** Reaching the great city ends the act: pay wages, then a **Grand Bazaar** (larger market and a camel and crew market). The next region starts with the caravan as is; supplies and goods carry over; prices in the new region are new.
- **R-32 Score.** At the end of act 3, score = silver + value of carried goods at the final city's buy prices (half value) + relics × 50 + reputation sum × 20.
- **R-33 Loss.** The run ends in failure if the caravan has 0 camels, or 0 crew, or cannot pay wages at a city (debt) after selling everything. Failure score = silver at the moment of loss × 0.5 (still recorded for stats; not on leaderboards).
- **R-34 Day pressure.** Each act has a soft deadline (`balance.act.days`: 30, 32, 34). For each day over the deadline, the great city's sale prices drop 2% for the act's final market (the season is ending).

### 4.9 Edge Cases

- **R-35** Buying more than capacity is rejected (`RuleError.overCapacity`); the UI shows a capacity bar.
- **R-36** If a camel dies while overloaded, excess load is dropped in this order: cheapest goods per weight first, then fodder, then water.
- **R-37** A legend detour that ends in failure still returns the caravan to the oasis node.
- **R-38** Rival caravans never visit the same node on the same day as each other (they queue), but may share with the player.

### 4.10 Invariants

- **INV-1** Silver ≥ 0 at all times except the moment of debt detection.
- **INV-2** Load ≤ capacity after every action except the transient in R-36, which resolves in the same step.
- **INV-3** Prices stay within clamps (R-19).
- **INV-4** No sequence of trades in a single visit increases silver plus goods value at local prices (no arbitrage; property test with random trade sequences).
- **INV-5** Replays deterministic across platforms.
- **INV-6** Legend success frequencies over 100,000 trials match the band within ±1%.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var act: Int; public var day: Int; public var rng: SeededRNG
    public var region: RegionMap; public var position: NodeID; public var visited: Set<NodeID>
    public var caravan: Caravan; public var markets: [NodeID: Market]; public var rivals: [RivalCaravan]
    public var memory: PriceMemory; public var rumors: [Rumor]; public var reputation: [NodeID: Int]
    public var contracts: [Contract]; public var relics: [RelicID]; public var master: MasterID
    public var pendingEvent: EventInstance?
}
public enum Action: Codable, Equatable, Sendable {
    case pickMaster(Int)
    case buy(GoodID, qty: Int), sell(GoodID, qty: Int), buySupplies(water: Int, fodder: Int)
    case hire(CrewKind), dismiss(CrewKind), buyCamel, sellCamel
    case buyRumor, acceptContract(ContractID), rest
    case depart(EdgeID), seekLegend, chooseEventOption(Int), continueTravel
}
public enum Event: Codable, Equatable, Sendable {
    case traded(GoodID, qty: Int, total: Int), priceSeen(NodeID, GoodID, Int)
    case dayPassed(Int, weather: Weather), hazard(HazardID, outcome: Outcome), camelLost(reason: LossReason)
    case crewDeserted(CrewKind), rumorHeard(Rumor), legendResolved(LegendID, success: Bool)
    case arrived(NodeID), actEnded(Int), runEnded(RunResult)
}
```

### 5.2 Content Tables

**`goods.json`** — G3: 24 goods across 3 regions; G5: 36.

```json
{ "id": "silk_bolt", "weight": 1, "base": { "salt_desert": 1800, "high_passes": 2400, "grass_sea": 3100 },
  "demand": { "city": 1.2, "caravanserai": 1.0, "camp": 0.7 }, "volatility": 0.06, "elasticity": 0.35, "icon": "good_silk" }
```

**`regions/*.json`** — 3 regions.

```json
{ "id": "salt_desert", "rows": 7, "nodeWeights": { "caravanserai": 4, "oasis": 3, "well": 2, "ruin": 2, "camp": 1 },
  "edgeTerrain": { "dunes": 5, "hardpan": 3 }, "weather": { "clear": 6, "heat": 3, "sandstorm": 2 },
  "hazardDeck": ["bandits", "quicksand", "lame_camel", "sickness"], "goods": ["salt", "glass", "silk_bolt"] }
```

**`events.json`** — G3: 30 event cards; G5: 60. **`legends.json`** — G3: 10; G5: 18. **`masters.json`** — G3: 4; G5: 8. **`relics.json`** — G3: 16; G5: 30.

```json
{ "id": "singing_dune", "band": "some", "detourDays": 2,
  "success": [{ "relic": "dune_flute" }, { "goods": { "incense": 6 } }],
  "failure": [{ "water": -4 }, { "camels": -1 }], "textKey": "legend_singing_dune" }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `camel.capacity` | 10 | 8–12 | balance.json |
| `market.spread` | 8% | 5–12% | balance.json |
| `market.driftRate` | 10%/day | 5–20% | balance.json |
| `rumor.truth` | 75% | 60–90% | balance.json |
| `rumor.price` | 5 silver | 2–10 | balance.json |
| `wage.perCrewDay` | 2 silver | 1–4 | balance.json |
| `hazard.perRating` | 10% | 6–15% | balance.json |
| `act.days` | 30/32/34 | ±6 | balance.json |
| `rivals.count` | 4 | 3–6 | balance.json |
| Good elasticity and volatility | per table | ±50% | goods.json |

**Target metrics (sims, ≥ 2,000 runs per bot):**

| Metric | Target |
| --- | --- |
| `TraderBot.blind` (random trades, ignores memory) average profit | negative (pillar 2) |
| `TraderBot.informed` run completion | 55–70% |
| `TraderBot.expert` run completion | 80–90% |
| Median run length (days) | 85–105 |
| Legend detours taken by expert bot that improve final score | 45–60% (risk is meaningful both ways) |
| Most profitable good share of expert profit | ≤ 25% |
| Master win rates (expert) | within ±8% of each other |

## 7. AI Approach

No opponent; AI covers rival caravans (market actors), bots for balance sims, the map generator, and the daily verifier.

| Component | Algorithm | Budget |
| --- | --- | --- |
| `RivalCaravan` (Core) | Each day: if at a node, sell goods whose local price ≥ 1.2× their purchase price; buy the good with the best known margin to a random reachable city within 3 rows; move along the shortest path. Uses its own RNG stream. | ≤ 0.2 ms per rival per day |
| `TraderBot.blind` | Random legal trades and random edges | sim only |
| `TraderBot.informed` | Greedy: uses price memory and rumors to pick the best single-good margin to the next city; buys supplies for the longest known leg + 2 | sim only |
| `TraderBot.expert` | `RoutePlanner` expectimax over the next 2 rows: evaluates edges by expected profit minus expected losses (hazard bands × losses), with load optimization by greedy value/weight knapsack | ≤ 50 ms per decision |
| `MapGenerator` | Slay-the-Spire-style row graph: 7 rows, 2–3 nodes per row, edges without crossings, node kinds drawn by region weights, constraints (≥ 1 water source within 2 days of every node; ≥ 1 caravanserai per 2 rows) | ≤ 50 ms |
| `DailyVerifier` | For the daily route, the expert bot must complete the run in ≥ 3 of 5 seeds derived from the daily seed; otherwise salt and regenerate | ≤ 3 s |

**Determinism:** rival and bot RNGs derive from `SplitMix64(runSeed ^ actorID)`.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **CVS-P0.1 Money type** (integer copper with formatting outside Core). Acceptance: arithmetic tests and overflow traps.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-38 and INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **CVS-P1.1 Caravan, load, speed, and upkeep (R-3–R-9).**
- **CVS-P1.2 Travel, weather, and hazards (R-10–R-14).**
- **CVS-P1.3 Market model and trading (R-18–R-22).** Acceptance: INV-4 property test with 10,000 random trade sequences.
- **CVS-P1.4 Rivals, memory, rumors, reputation, and contracts (R-21, R-23–R-26).**
- **CVS-P1.5 Legends, relics, masters, act end, scoring, and loss (R-27–R-34).** Acceptance: INV-6 frequency test.
- **CVS-P1.6 MapGenerator** (needed for P1 sims). Acceptance: 10,000 seeds satisfy all constraints.
- **CVS-P1.7 Sim CLI.** `Tools/sim --bot informed --runs 2000` → completion, profit, cause of loss.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 property tests pass
  [ ] CVSCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
  [ ] Blind bot average profit < 0 (pillar 2 early check)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: act 1 only (Salt Desert), 8 goods, 2 masters, 12 events, 4 legends, 3 rivals.

- **CVS-P2.1 Region panel.** Node roundels, edges with terrain glyphs and hazard bands, the caravan figure animating along legs, and a fog of unvisited rows beyond the next 2.
- **CVS-P2.2 Departure planner.** Drag the caravan to a neighboring node to preview days, water and fodder needed (with weather risk), and capacity; a load slider for supplies. Confirm with "Depart."
- **CVS-P2.3 Market overlay (SwiftUI).** Goods list with local price, remembered prices elsewhere (age badges), marginal-price quotes, sparkline (press and hold), and buy/sell steppers.
- **CVS-P2.4 Event and legend cards** with choices and honest odds bands.
- **CVS-P2.5 Ledger.** Day count, silver, morale, camels, and crew HUD.

Slice checks: a new player completes act 1 with a profit in their second attempt (Mahler); departures present a non-obvious choice (Grok).

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest completes act 1 (scripted) to the Grand Bazaar on iPad and Mac
  [ ] Save and resume mid-leg and mid-market to identical hash
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — are load-out and route decisions interesting? Is information valuable?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **CVS-P3.1** Regions 2 and 3 with goods, hazards, and weather.
- **CVS-P3.2** 60 events, 18 legends, 8 masters, 30 relics.
- **CVS-P3.3** Contracts and reputation UI.
- **CVS-P3.4** Tutorial: a short "first crossing" (4 nodes) teaching load, a trade, a rumor, and a hazard.
- **CVS-P3.5** Codex: discovered goods, legends, and relics.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 3 regions, 36 goods, 60 events, 18 legends, 8 masters, 30 relics
  [ ] content-lint 0 errors; every event outcome references valid IDs
  [ ] Tutorial UI test passes
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **CVS-P4.1** Rival caravan behavior tuning (they must neither crash markets nor be invisible: rivals should move a good's price ≥ 10% in 20–40% of player visits).
- **CVS-P4.2** TraderBot tiers and `RoutePlanner`.
- **CVS-P4.3** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI and Bots
Checks:
  [ ] 2,000 runs per bot tier: 0 crashes, 0 illegal actions
  [ ] Targets in §6 met or deviations documented with proposals
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **CVS-P5.1 Masters unlock** by completed runs and achievements; all earnable.
- **CVS-P5.2 Daily Route.** Date-derived seed; same maps, markets, and master for everyone; one ranked attempt.
- **CVS-P5.3 Ascension-style "Hard Roads."** 10 cumulative difficulty levels (shorter deadlines, lower rumor truth, more raiders, and so on).
- **CVS-P5.4 Stats:** best fortune per master, most profitable goods, legends survived.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Daily Route deterministic and verified for 60 dates
  [ ] Hard Roads levels each reduce expert completion monotonically (sim)
  [ ] All standard tests and coverage thresholds pass
  [ ] docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **CVS-P6.1** Three region panels in final miniature style, ornamental borders, and node roundels.
- **CVS-P6.2** Market scenes for city and caravanserai (illustrated headers).
- **CVS-P6.3** Music per region and market; SFX; haptics.

```
GATE G6 — Aesthetics
Checks:
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **CVS-P7.1 Pencil journal.** A PencilKit notebook page per run for jotting prices (saved with the run, never read by rules); hover over a node previews the leg.
- **CVS-P7.2 Game Center.** Daily and best-fortune leaderboards, 30 achievements, challenges.
- **CVS-P7.3 iCloud** run sync.
- **CVS-P7.4 Mac.** Keyboard trade (arrows select goods, B/S buy and sell, ⇧ for ×5), menus.

```
GATE G7 — Platform
Checks:
  [ ] Journal persists across devices; Game Center sandbox round trip
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **CVS-P8.1** VoiceOver for markets (good, price, trend, remembered elsewhere).
- **CVS-P8.2** Dynamic Type throughout the SwiftUI market.
- **CVS-P8.3** Color-blind safe hazard bands (icons plus color).
- **CVS-P8.4** Perf on A16 iPad.

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
  [ ] Tester completion rate of act 1 on first run 30–60%
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview shows a departure, a market haggle, and a legend gamble.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** the price model's interaction with rivals (runaway crashes); INV-4 no-arbitrage is a regression guard for any economy change.
- **Content voice:** event and legend texts set the tone; Grok owns them after G5. Avoid stereotypes of real peoples; regions and cities are fictional composites (Q2).
- **First tasks:** Grok — tune goods tables and legends for pillar 1 and 3; Claude — market UI ergonomics on iPhone compact width.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Spreadsheet feel | Medium | High | Painted panels, quick trade steppers, strong arrival moments | GROK |
| Dominant trade route or good | Medium | Medium | Elasticity, rivals, and sims | GLM → GROK |
| Cultural depiction concerns | Medium | Medium | Fictional composites, respectful research, consultant review if budget allows (Mahler) | GROK + MAHLER |
| Too much attrition (frustration) | Medium | Medium | Honest bands, hazard visibility with guides, Hard Roads opt-in | GROK |

## 11. Out of Scope

- Multiplayer and trading between players.
- Real historical cities or figures.
- Combat beyond guard checks.
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 9–13 |
| P2 Vertical Slice | GLM | 8–11 |
| P3 Content and Systems | GLM | 10–14 |
| P4 AI and Bots | GLM | 5–8 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 12–18 |
| P7 Platform | CLAUDE | 4–6 |
| P8 Polish | CLAUDE | 4–6 |
| P9 Beta | GROK + CLAUDE | 6–10 |
| P10 Release | CLAUDE + GROK | 2–4 |
| **Total** | | **66–99** |

## 13. Open Questions for Mahler

1. Three acts per run? **Default:** yes, with a short one-act "Caravan Day" mode later (out of scope v1.0).
2. Fictional city names inspired by the Silk Road, or historical names? **Default:** fictional composites.
3. Display typeface with Persian-style calligraphy? **Default:** New York for v1.0; revisit if a licensed face is approved.
4. Allow undo for trades within a market visit? **Default:** yes until departure.
5. Price? **Default:** Mahler decides in P10.
