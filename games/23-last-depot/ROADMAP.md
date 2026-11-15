# 23 — Last Depot Roadmap

> Plan a polar expedition depot by depot, where every pound of food you cache for the return is a pound your team cannot haul toward the pole.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Last Depot.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 23 · `last-depot` |
| Code prefix | `LDP` (packages `LDPCore`, `LDPContent`, `LDPAI`, `LDPRender`, `LDPAudio`, `LDPPlatform`, `LDPMeta`) |
| Bundle ID (placeholder) | `com.zyniker.last-depot` |
| Subgenre | Logistics roguelite (expedition planning and survival) |
| Difficulty tier | Hardcore |
| Scope | Small team |
| Session length | 30–90 min per expedition (resumable; saves daily) |
| Renderer | SpriteKit (2D) for the ice-sheet map and sledging scenes; SwiftUI for planning ledgers and the diary; `SKShader` for blowing snow and photographic grain |
| Players | Solo only |
| Simulation | Day-based turns with auto-advance ("march until something happens") |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Plan a polar expedition depot by depot, where every pound of food you cache for the return is a pound your team cannot haul toward the pole.

**Summary:** Each expedition starts at a coastal hut on a procedurally generated ice sheet with a sponsor, a budget, and a crew roster. In the **Laying Season** (autumn), parties haul supplies south and cache them in depots along the intended route. A short **Winter** at the hut handles repairs, training, and crew relationships. In the **Polar Season** the main party, with support parties that turn back in stages, pushes toward the pole and must return by finding each depot, sometimes in whiteout. The core skill is supply arithmetic under uncertainty: food, fuel, and fodder against distance, weather, surface, and failing machines and animals. The look and sound borrow from early expedition photography and pencil diaries. Crews who die are remembered; each expedition leaves a legacy for the next.

**Pillars:**

1. **The arithmetic is the drama.** The planner shows exact consumption math; uncertainty comes only from weather, surface, and failures, each with visible probabilities.
2. **Margins, not luck.** A well-planned expedition survives bad weather; an expedition planned without margin dies in average weather. Sims must show this (§6).
3. **Every pound matters.** Every item has weight, and every decision about where to cache it is a trade-off between the push and the return.
4. **Quiet dignity.** Tone is restrained; deaths are recorded in the diary, never sensationalized.
5. **Hardcore but fair.** Full information about rules; save-scumming is not needed because the planner lets the player reason about risk before committing.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Snow white `#F4F6F7`, blue shadow `#BFD0DC`, steel blue `#5D7A92`, deep ice `#2C4458`, sepia print `#A08A6B`, paper `#EFE8DA`, pencil graphite `#4A4A48`, single warning ochre `#C98A2B` (no red) |
| Shapes | Ice sheet as a sparse engraved map with sastrugi strokes, crevasse fields as fine hatching, depots as cairns with flags; sledging scenes as small silhouetted figures in wide white space |
| Typography | Typewriter face for the ledger (default: American Typewriter), handwriting-like face for the diary (default: Bradley Hand in display only, with SF Pro fallback for accessibility) |
| Motion | Drifting snow particles; figures plod at a cadence matching surface quality; photographic vignette and grain |
| Music | Sparse solo violin and wind; silence during blizzards except wind |
| SFX | Creaking sledge runners, dogs, ponies, motor sledge engine stutter, wind levels, tent canvas flapping |
| Haptics | Rhythmic soft pulses while marching (cadence by surface); long low rumble in blizzards; single heavy tap on a crevasse incident |

**Inspirations:** FTL's attrition, Against the Storm's run-as-avatar structure, and the logistics of Heroic Age polar expeditions (treated as fiction inspired by history).

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit for the map and scenes; SwiftUI for the planner, ledger, depot cards, and diary (tables, steppers, and text read better natively).
- **Units:** Core uses integer **ounces** for weight and **tenths of a mile** for distance; the UI displays pounds and miles (or kilograms and kilometers via a units setting).
- **Turns:** days. Auto-advance runs day steps until an interrupt (event, decision point, depot reached, or a threshold warning).
- **Weather model:** a seeded Markov chain per region with daily states and a hidden "weather system" layer (multi-day blizzards).

ADRs to create in P0:

- ADR-0003 Integer ounces and tenths of a mile.
- ADR-0004 Day-turn model with interrupts.
- ADR-0005 Weather Markov model.
- ADR-0006 SwiftUI planning surfaces over SpriteKit map.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── LDPCore/Sources/LDPCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Weight.swift, Distance.swift
│   ├── Ice/          IceSheet.swift (node graph), Surface.swift, Crevasse.swift, Landmark.swift, Glacier.swift
│   ├── Weather/      WeatherState.swift, WeatherSystem.swift, Visibility.swift, Temperature.swift
│   ├── Expedition/   Expedition.swift, Party.swift, Sledge.swift, Load.swift, Transport.swift (man, dog, pony, motor)
│   ├── People/       CrewMember.swift, Health.swift (frostbite, scurvy, exhaustion, injury), Skills.swift, Morale.swift
│   ├── Supplies/     Item.swift, Ration.swift, Fuel.swift (leakage), Depot.swift, Cairn.swift
│   ├── Daily/        DayStep.swift, Marching.swift, Navigation.swift (depot finding), Consumption.swift, Incidents.swift
│   ├── Season/       LayingSeason.swift, Winter.swift, PolarSeason.swift
│   ├── Run/          RunState.swift, Sponsor.swift, Goals.swift, Score.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── LDPContent/       ItemDef.swift, TransportDef.swift, CrewDef.swift, SponsorDef.swift, IncidentDef.swift, SheetTemplate.swift, Loader.swift
├── LDPAI/            PlannerBot.swift, SupplySolver.swift (margin calculator), SheetGenerator.swift, WeeklyVerifier.swift, Advisor.swift
├── LDPRender/        SheetScene.swift, PartyNode.swift, DepotNode.swift, SledgingScene.swift, Shaders/
├── LDPAudio/         WindEngine.swift, Violin.swift
├── LDPPlatform/      DiaryPencil.swift (PencilKit), GameCenterService.swift, CloudSaveService.swift
└── LDPMeta/          Legacy.swift, Memorial.swift, WeeklyExpedition.swift, Stats.swift
Resources/Content/    items.json, transports.json, crew.json, sponsors.json, incidents.json, sheets/*.json, weather.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5. Weights in ounces (oz), distances in tenths of a mile (dm, "deci-miles"), temperatures in whole °F.

### 4.1 Setup

- **R-1 Ice sheet.** A directed graph of 40–70 nodes from the Hut (coast) to the Pole, with alternative routes (barrier, glacier, and plateau sections). Each edge has a length (dm), surface class (`hard`, `soft`, `sastrugi`, `crevassed`, `glacier`), and elevation gain.
- **R-2 Budget.** The sponsor provides a budget (in pounds sterling of the era, displayed as £) to buy supplies, animals, and machines before departure from the ship (pre-expedition shop).
- **R-3 Crew.** The roster offers 12–16 candidates; the player hires up to 12. Each has skills (navigation, dog driving, pony handling, mechanics, medicine, and endurance, each 0–3), traits (e.g., `stoic`, `quarrelsome`, `optimist`, and `steady`; traits may modify the probabilities listed in these rules but never the random stream itself), and health stats.
- **R-4 Calendar.** Laying Season: 45 days. Winter: 6 abstract weeks (one decision per week). Polar Season: up to 120 days; the last ship leaves on day 120, and anyone not at the Hut by then is lost.

### 4.2 Parties and Transport

- **R-5 Parties.** A party is 1–5 crew with 0–2 sledges and transport units. Parties move independently; each day each party has an order (R-9).
- **R-6 Transport units.** `man` (crew pull; 200 lb pull capacity per person on hard surface), `dogs` (team of 9 pulls 900 lb; eats dog food 1.5 lb per dog per day), `pony` (pulls 800 lb; eats fodder 10 lb per day; suffers below −20 °F; can be slaughtered for 150 lb of depot meat), `motor_sledge` (pulls 2,000 lb; uses 6 lb fuel per 10 miles; daily breakdown chance R-17). Exact values in `transports.json`.
- **R-7 Effective pull.** Daily distance = `basePace(transport, surface) × min(1, pullCapacity / load) × fatigueFactor × weatherFactor`, in dm, floored. Loads above 130% of capacity cannot move.
- **R-8 Relay.** A party may relay: carry half the load forward, return, and carry the rest (distance made good = one third of the daily distance, consumption full).

### 4.3 Daily Orders and Steps

- **R-9 Orders.** `march(toward: node)`, `relay(toward:)`, `lieUp` (stay in tent), `layDepot(items)`, `takeFromDepot(items)`, `buildCairn` (marker; half a day), `layFlagLine` (lateral flags for depot finding, half a day, uses flags), `slaughterPony`, `repairMotor`, `returnToward(node)`, `split(into parties)`, `merge(party)`.
- **R-10 Day step order.** For each day: (1) weather roll for each region (R-20); (2) apply each party's order in party ID order; (3) consumption (R-12); (4) health checks (R-14); (5) incidents (R-17); (6) depot decay (R-19); (7) check interrupts and end conditions.
- **R-11 Auto-advance.** The player may set multi-day orders; the game advances day by day until an **interrupt**: a weather change to blizzard or whiteout, a party reaching a node or depot, food or fuel for any party falling below 3 days, an injury or death, a motor breakdown, or a decision event.

### 4.4 Consumption and Health

- **R-12 Rations.** Each crew member eats a daily ration chosen per party: `full` (pemmican 12 oz, biscuit 16 oz, butter 2 oz, sugar 3 oz, cocoa 1 oz, tea 0.5 oz = 34.5 oz), `reduced` (26 oz), or `starvation` (18 oz). Fuel: 1 party-day of cooking per tent uses 6 oz paraffin (2 tents for parties of 5). Without fuel, no hot food or water: exhaustion +2 per day.
- **R-13 Calories and condition.** Each crew member has `condition` 0–100 (start 90). Daily change: full ration on hard surface +0; soft or sastrugi −1; glacier or plateau −2; reduced ration −2 extra; starvation −4 extra; lying up in a blizzard −1 (cold). Below 40, pace −25%; at 0, the crew member dies.
- **R-14 Frostbite.** Daily risk by temperature and wind: `p = max(0, (−10 − temp) / 10) × 2% × windFactor`, −50% for `stoic`, +50% for condition < 40. Each case reduces endurance; three cases disable a crew member (must ride on a sledge, adding 160 lb load).
- **R-15 Scurvy.** Without fresh meat (pony meat, seal, or penguin from coast events) for 60 days, each crew member's scurvy level rises by 1 per 10 days; each level −5 condition per week; a medical skill ≥ 2 in the party halves progression.
- **R-16 Morale.** Party morale 0–10. Losses, starvation rations, and long blizzards lower it; reaching depots, good surfaces, and milestones raise it. At ≤ 2, `quarrelsome` crew may refuse orders other than `returnToward` (decision event).

### 4.5 Incidents

- **R-17 Incidents.** Daily incident checks per party from `incidents.json`, weighted by surface and transport: `crevasse_fall` (on crevassed edges: chance 3% per crossing day, −25% with a rope-team skill; outcomes: injury, sledge lost, or animals lost), `motor_breakdown` (chance per day 15% − 5% per mechanic skill level; repair takes 1–3 days and spare parts), `dog_fight`, `pony_collapse` (below −20 °F, 4% per day per pony), `snow_blindness` (on bright days without goggles), `tent_torn` (blizzards), and `seal_hunt_opportunity` (coast only).
- **R-18 Incident visibility.** The planner and the march screen show each risk's daily probability for the current order (pillar 1).

### 4.6 Depots

- **R-19 Depot decay.** Paraffin in depots leaks: each depot loses `leakRate × daysSinceLaid` of its fuel, where leakRate is 0.5% per day for standard cans and 0.1% for sealed cans (an upgrade). Food does not decay. Depots buried by drift (≥ 6 blizzard days nearby) require digging (half a day).
- **R-20 Weather.** Each region has a Markov chain over states `clear`, `overcast`, `wind`, `blizzard`, `whiteout`, with temperatures by month and elevation and a hidden multi-day system variable. Blizzard: no marching (lying up forced unless the player forces a march: pace ×0.3, frostbite ×3). Whiteout: navigation checks (R-21).
- **R-21 Finding depots.** When a returning party reaches the edge of a depot's node in `overcast`, `wind`, or `whiteout`, it must find the depot: chance = `base(visibility) + 15% per cairn + 25% per flag line + 10% per navigation skill level of the best navigator`, capped at 98%. Base: clear 100% (no check), overcast 85%, wind 70%, whiteout 30%. A failed search costs half a day and allows a retry next half day (weather may change).
- **R-22 Navigation.** In whiteout, marching parties may **drift**: 20% per day (−5% per navigation level) of veering onto an adjacent edge (often a crevassed one if adjacent).

### 4.7 Seasons

- **R-23 Laying Season.** Parties may travel out, lay depots, and return to the Hut. Ponies and motors are most valuable here. The season ends on day 45; parties not at the Hut by then lose 10 condition per day until they arrive (early winter).
- **R-24 Winter.** Six weekly decisions: repair motors, train skills (+1 skill for one crew member per week), sew sealed cans (+N sealed cans), mend tents, hold a lecture (+morale), rest (+condition), or hunt (if seals available). Random hut events (fire, illness, quarrel) from the winter deck.
- **R-25 Polar Season.** The main party and support parties depart; support parties turn back at chosen depots carrying only what they need to return. The pole is reached at the Pole node; the return uses the same or alternative routes.

### 4.8 Sponsors, Goals, Scoring, and Legacy

- **R-26 Sponsor goals.** Each sponsor (from `sponsors.json`) sets a primary goal (reach the pole and return) and 1–2 secondary goals: geological samples (weight to carry back), photographs (plates), speed (reach the pole by day *N*), no animal use, or no losses.
- **R-27 Score.** Pole reached +500; each crew member returned alive +100; secondary goals +100–300 each; remaining budget +1 per £10; −200 per death. Expeditions that do not reach the pole but return everyone score 200 + 100 per crew alive ("a gallant failure").
- **R-28 Legacy.** After an expedition, the player picks one **lesson** from three (legacy perks such as `sealed_cans_standard`, `ski_training`, `flag_line_drill`, `better_rations`), carried to all future expeditions (max 6 active). Deceased crew appear in the Memorial with their diary entries.
- **R-29 Ironman.** Saves are automatic and single-slot per expedition (no manual reload). A "Practice" mode allows reloading the morning of any day and does not count for leaderboards or legacy.

### 4.9 Edge Cases

- **R-30** A crew member who dies while their party has no other members leaves the party's sledge as a lost depot (others may find it with a navigation check).
- **R-31** Splitting a party splits sledges and loads exactly as the player assigns; the UI prevents unassigned items.
- **R-32** A pony slaughtered at a depot node adds its meat to that depot; elsewhere to the party's load (if capacity allows; excess abandoned).
- **R-33** If all crew are lost or the last ship leaves, the expedition ends.

### 4.10 Invariants

- **INV-1** Every item is in exactly one place: hut store, a sledge, a depot, consumed, or lost (conservation audit).
- **INV-2** No party's load exceeds 130% of its capacity after any order.
- **INV-3** Condition, morale, and skills stay within their ranges.
- **INV-4** The planner's projected consumption equals the engine's actual consumption under the same weather sequence (planner uses the same functions; test with fixed weather).
- **INV-5** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var day: Int; public var season: SeasonPhase; public var rng: SeededRNG
    public var sheet: IceSheet; public var weather: [RegionID: WeatherState]
    public var hutStore: Inventory; public var depots: [NodeID: Depot]
    public var parties: [PartyID: Party]; public var crew: [CrewID: CrewMember]
    public var budget: Int; public var sponsor: SponsorID; public var goals: [GoalProgress]
    public var legacy: [LessonID]; public var diary: [DiaryEntry]; public var mode: RunMode   // ironman, practice
}
public struct Party: Codable, Equatable, Hashable, Sendable {
    public var id: PartyID; public var crew: [CrewID]; public var sledges: [Sledge]; public var transport: [TransportUnit]
    public var at: NodeID; public var progress: Int /* dm along current edge */; public var edge: EdgeID?
    public var order: Order; public var ration: Ration; public var morale: Int
}
public enum Action: Codable, Equatable, Sendable {
    case buy(ItemID, qty: Int), hire(CrewID), formParty([CrewID], loads: [SledgeLoad]), setOrder(PartyID, Order)
    case setRation(PartyID, Ration), advance(days: Int?), resolveDecision(DecisionID, choice: Int)
    case winterChoice(WinterChoice), chooseLesson(Int)
}
public enum Event: Codable, Equatable, Sendable {
    case dayBegan(Int, [RegionID: WeatherState]), marched(PartyID, dm: Int), depotLaid(NodeID, Inventory)
    case depotFound(NodeID, PartyID), depotSearchFailed(NodeID, PartyID), consumption(PartyID, Inventory)
    case incident(PartyID, IncidentID, Outcome), frostbite(CrewID), death(CrewID, cause: Cause)
    case interrupt(Reason), poleReached(PartyID, day: Int), expeditionEnded(Result)
}
```

### 5.2 Content Tables

**`items.json`** — G3: 24 items (rations, fuel, equipment, scientific kit).

```json
{ "id": "paraffin_can_sealed", "weightOz": 192, "contentsOz": 160, "cost": 3, "leakPerDayPermille": 1, "unlock": "sealed_cans_standard" }
```

**`transports.json`** — 4 types with pace tables by surface.

```json
{ "id": "dogs", "unit": "team_of_9", "pullLb": 900, "foodItem": "dog_pemmican", "foodOzPerDay": 216,
  "pace": { "hard": 180, "soft": 120, "sastrugi": 100, "crevassed": 80, "glacier": 60 }, "cost": 220 }
```

**`crew.json`** — G3: 40 crew archetype templates for roster generation (invented names; no real expedition members).

**`sponsors.json`** — G3: 5; G5: 10. **`incidents.json`** — G3: 20; G5: 36. **`sheets/*.json`** — G3: 2 handcrafted + generator templates; G5: 4 + generator. **`weather.json`** — Markov matrices per region and month.

```json
{ "region": "plateau", "month": 12, "states": ["clear","overcast","wind","blizzard","whiteout"],
  "matrix": [[60,20,12,4,4],[30,40,15,7,8],[20,20,35,15,10],[5,10,25,50,10],[15,25,20,10,30]],
  "tempF": { "mean": -18, "spread": 12 }, "systemChance": 6 }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `season.laying.days` | 45 | 35–60 | balance.json |
| `season.polar.days` | 120 | 100–140 | balance.json |
| `ration.full.oz` | 34.5 | 30–40 | balance.json |
| `condition.dailyLoss` by surface | 0/1/1/2/2 | ±1 | balance.json |
| `frostbite.base` | 2% | 1–4% | balance.json |
| `depot.find.base` overcast/wind/whiteout | 85/70/30 | ±15 | balance.json |
| `depot.find.cairn` / `flagLine` | 15 / 25 | 10–20 / 15–35 | balance.json |
| `motor.breakdown.base` | 15% | 8–25% | balance.json |
| `fuel.leak.standard` | 0.5%/day | 0.2–1.0% | balance.json |
| `budget.start` | £8,000 | 6,000–12,000 | sponsors.json |

**Target metrics (sims, ≥ 2,000 expeditions per bot tier per sheet):**

| Metric | Target |
| --- | --- |
| `PlannerBot.margin20` (20% safety margin on all legs) pole-and-return rate | 55–70% |
| `PlannerBot.margin0` (no margin) pole-and-return rate | 5–15% (pillar 2) |
| `PlannerBot.margin40` (very conservative) pole-reached rate | 25–40% (too much margin is also costly) |
| Median expedition length (real time for an engaged player) | 50–80 min |
| Deaths per expedition (margin20) | 0.3–1.0 |
| Share of failures caused by depot-finding in whiteout | 15–30% |

## 7. AI Approach

No opponent. AI covers the supply solver (used by both the planner UI and bots), bots for sims, the sheet generator, the weekly verifier, and the advisor.

| Component | Algorithm | Budget |
| --- | --- | --- |
| `SupplySolver` | Given a route, party plan, and margins, computes per-leg consumption, required depot contents, and load per day by forward simulation under the **expected** weather (mean pace) and under a **bad** weather quantile (80th percentile days lost from 1,000 Monte Carlo weather samples, seeded) | ≤ 300 ms on A16 for a full plan; cached |
| `PlannerBot.marginN` | Chooses a route by shortest expected days; builds a depot plan with `SupplySolver` at margin N%; issues orders; responds to interrupts with simple rules (lie up in blizzards, reduce rations if behind) | sim only |
| `SheetGenerator` | Builds a graph from coast to pole with 2–3 alternative corridors, surface fields by noise, crevasse bands near glaciers, and landmarks; validates that a margin20 plan exists within the budget | ≤ 200 ms |
| `WeeklyVerifier` | Weekly expedition (ISO week, UTC): margin20 bot must succeed in ≥ 40% of 50 seeded weather samples | ≤ 20 s in CI |
| `Advisor` | Rule-based warnings on the planner ("Return from Depot 4 has 2 days of fuel margin under bad weather") | ≤ 50 ms |

**Determinism:** Monte Carlo samples use `SplitMix64(planHash ^ sampleIndex)` so the planner's numbers are stable for the same plan; they never advance the game RNG.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **LDP-P0.1 Weight and distance types** with display formatters (imperial and metric) outside Core.
- **LDP-P0.2 Inventory type** with conservation audit helpers.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-33 and INV-1…INV-5
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **LDP-P1.1 Ice sheet, surfaces, and transport pace (R-1, R-5–R-8).**
- **LDP-P1.2 Orders and day steps with interrupts (R-9–R-11).**
- **LDP-P1.3 Consumption and health (R-12–R-16).**
- **LDP-P1.4 Incidents (R-17, R-18)** with per-day probabilities exposed for UI.
- **LDP-P1.5 Depots, weather, finding, and navigation (R-19–R-22).** Acceptance: Markov chain stationary distributions match fixtures within ±1% over 1,000,000 days.
- **LDP-P1.6 Seasons, winter, sponsors, scoring, and legacy (R-23–R-29).**
- **LDP-P1.7 SupplySolver** (needed early; it is the planner's engine). Acceptance: INV-4 test with fixed weather.
- **LDP-P1.8 Sim CLI** `Tools/sim --sheet ross_like --bot margin20 --runs 2000`.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-5 over 1,000 seeds
  [ ] LDPCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
  [ ] margin0 vs margin20 success gap ≥ 35 percentage points (pillar 2 early check)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: one sheet, a short "Coastal Survey" variant (laying season plus a 40-day push to a landmark instead of the pole), man-hauling and dogs only, 12 incidents.

- **LDP-P2.1 Sheet map.** Nodes, edges with surface glyphs, depots, parties; pinch and pan.
- **LDP-P2.2 Planner (SwiftUI).** Route picker (tap nodes), per-leg table (days expected and bad-weather days, food, fuel, load), depot cards with contents and steppers, and margin badges. Drag items between hut, sledges, and depot cards.
- **LDP-P2.3 March screen.** Sledging scene with weather, daily log, interrupt cards with choices, and per-day risk readouts.
- **LDP-P2.4 Auto-advance controls.** "March until something happens," with a speed slider for the daily animation.
- **LDP-P2.5 Diary.** Auto-written daily entries (template-based, from events) in a pencil diary page.

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest completes the Coastal Survey (scripted plan) on iPad and Mac
  [ ] Planner numbers equal engine outcomes under fixed weather for 50 plans (INV-4 via UI adapter)
  [ ] Save and resume mid-march to identical hash
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — is the supply arithmetic dramatic and legible?
  [ ] REVIEW: MAHLER — compelling enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **LDP-P3.1** Ponies and motor sledges with all rules; winter decisions and hut events.
- **LDP-P3.2** Full polar season with support parties and the pole.
- **LDP-P3.3** 36 incidents, 10 sponsors, 24 items, crew roster generator.
- **LDP-P3.4** Tutorial: "The First Depot" (lay one depot 3 days out and return), then "The Margin" (a guided plan that fails without margin and succeeds with it).
- **LDP-P3.5** Diary templates (≥ 150) with tone review notes for Grok.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 4 transports, 24 items, 36 incidents, 10 sponsors, 150 diary templates
  [ ] content-lint 0 errors; tutorial UI tests pass
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **LDP-P4.1** PlannerBot tiers (margin 0, 20, 40) and the Advisor.
- **LDP-P4.2** SheetGenerator with validation.
- **LDP-P4.3** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — Bots and Generators
Checks:
  [ ] 2,000 expeditions per bot per sheet: 0 crashes, 0 illegal orders
  [ ] Targets in §6 met or documented
  [ ] SupplySolver p95 ≤ 300 ms (CI scaled)
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **LDP-P5.1** Legacy lessons (24) and the Memorial.
- **LDP-P5.2** Weekly Expedition (ISO week seed): fixed sheet, sponsor, and roster; one ironman attempt per week.
- **LDP-P5.3** Expedition archive: replay any finished expedition day by day with full information.
- **LDP-P5.4** Difficulty presets (Gentle Season, Standard, Heroic Age) changing weather severity and budget.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Weekly expeditions deterministic and verified for 12 weeks ahead
  [ ] Archive replays match recorded hashes
  [ ] All standard tests and coverage thresholds pass; docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **LDP-P6.1** Final map engraving style, photographic sledging scenes with grain and vignette, hut interior for winter.
- **LDP-P6.2** Diary visual design (paper, pencil, pressed-flower margins for milestones).
- **LDP-P6.3** Wind engine (layered by weather), violin themes, SFX, haptic cadence.
- **LDP-P6.4** Grok edits diary templates and incident texts for restraint and dignity.

```
GATE G6 — Aesthetics
Checks:
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **LDP-P7.1 Pencil.** Handwritten diary notes alongside auto entries (PencilKit, stored with the save); hover over a depot shows contents and bad-weather margin; squeeze opens the planner.
- **LDP-P7.2 Game Center.** Weekly expedition leaderboard, achievements (gallant failure, no losses, and so on), challenges.
- **LDP-P7.3 iCloud** sync (single-slot ironman respected across devices: latest day wins).
- **LDP-P7.4 Mac.** Multiple windows (map and planner side by side), keyboard shortcuts for advance, lie up, and depot actions.

```
GATE G7 — Platform
Checks:
  [ ] Ironman cannot be rolled back via iCloud conflicts (test: older day never overwrites newer)
  [ ] Game Center sandbox round trip; Mac multi-window works
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **LDP-P8.1** VoiceOver for the planner tables and daily log; Dynamic Type throughout SwiftUI surfaces.
- **LDP-P8.2** High-contrast mode for snow scenes (white-on-white risk).
- **LDP-P8.3** Diary readable in SF Pro when the accessibility font setting is on.
- **LDP-P8.4** Perf on A16 (Monte Carlo solver budget).

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
  [ ] ≥ 60% of testers report understanding why their expedition failed (survey Mahler approves)
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview shows planning a depot, a whiteout search, and a returning party reaching the hut. Store copy states clearly that the game is fiction inspired by the Heroic Age of exploration.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** planner/engine parity (INV-4), conservation (INV-1), depot-finding probabilities in whiteout, and auto-advance interrupt coverage (a missed interrupt can kill a party unfairly).
- **Tone:** diary and incident text must stay restrained; Grok owns the voice after G5.
- **First tasks:** Grok — margin tuning so pillar 2 holds on all sheets; Claude — planner UX on iPhone and Mac multi-window.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too spreadsheet-like | High | High | Strong scenes and diary, Advisor summaries, collapsible tables | GROK + CLAUDE |
| Deaths feel unfair | Medium | High | Visible probabilities, interrupts, margins | GLM → GROK |
| Insensitive treatment of real history | Low | Medium | Fiction inspired by history; invented crew; restrained tone | GROK + MAHLER |
| Long sessions without saves | Low | Medium | Daily autosave; resume anywhere | GLM |
| Monte Carlo slow on device | Medium | Medium | Cache by plan hash, sample counts adaptive | GLM |

## 11. Out of Scope

- Real historical expeditions, names, or reenactments.
- Multiplayer or race-against-rival-expeditions modes (post-launch idea).
- 3D scenes.
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 12–16 |
| P2 Vertical Slice | GLM | 10–14 |
| P3 Content and Systems | GLM | 10–14 |
| P4 Bots and Generators | GLM | 5–8 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 10–14 |
| P7 Platform | CLAUDE | 4–6 |
| P8 Polish | CLAUDE | 5–7 |
| P9 Beta | GROK + CLAUDE | 6–10 |
| P10 Release | CLAUDE + GROK | 2–4 |
| **Total** | | **70–102** |

## 13. Open Questions for Mahler

1. Ironman by default with a separate Practice mode? **Default:** yes.
2. Imperial units by default (period feel) with a metric toggle? **Default:** yes.
3. Include the Winter phase, or skip straight to the Polar Season? **Default:** include as six quick decisions.
4. Should a rival expedition (racing to the pole) exist in v1.0? **Default:** no; post-launch.
5. Price? **Default:** Mahler decides in P10.
