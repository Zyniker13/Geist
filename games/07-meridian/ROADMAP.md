# 07 — Meridian Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 07 · `meridian` |
| Code prefix | `MR` (packages `MRCore`, `MRContent`, `MRAI`, `MRRender`, `MRAudio`, `MRPlatform`, `MRMeta`) |
| Bundle ID (placeholder) | `com.zyniker.meridian` |
| Subgenre | Age of Sail exploration 4X (turn-based) |
| Difficulty tier | Hardcore |
| Scope | Larger team |
| Session length | 2–6 hour campaigns, played in 20-minute sittings |
| Renderer | SpriteKit chart view with Metal compute for chart texture generation; RealityKit globe view added in P6 |
| Players | Solo vs AI crowns (2–5 crowns); async online via GameKit turn-based (up to 4 humans) in P7 |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** An Age of Sail exploration 4X where the world map is only as accurate as your sailors' reports, and rival crowns sail by charts full of lies.
- **Summary:** Each crown has its own Chart, compiled from ships' logs whose accuracy depends on instruments, captains, and luck. Ships navigate by dead reckoning against that chart, so errors cause missed landfalls and wrecks. You commission voyages, found ports, trade, fight, research navigation, and buy, sell, steal, or forge charts. Victory goes to the crown with the best combination of accurate knowledge, wealth, and holdings.
- **Pillars:**
  1. **Knowledge is the resource.** The true world is hidden; your chart is your advantage and your liability.
  2. **Every chart tells a story.** Errors, rumors, and forgeries are visible and explainable.
  3. **Hardcore systems, calm sittings.** Seasons are turns; saves sync across devices; nothing is timed.
  4. **The map is the art.** A beautiful portolan chart that literally fills in as you play.
- **Aesthetic spec:**
  - Palette: vellum `#EFE3C5`, sepia ink `#5A3E22`, rhumb-line red `#B8452F`, rhumb-line green `#3F6B3A`, gold leaf `#C9A13B`, sea wash `#BFD3C9`, unknown-sea fog `#D9CDB0`, crown colors (5, color-blind-checked).
  - Visuals: portolan rhumb-line networks radiating from compass roses; coastlines drawn in ink with confidence shown by line weight and dashing; sea monsters and cartouches populate uncharted areas and fade as charting improves; ships as small woodcut carracks.
  - Audio: harpsichord, viol consort, and choir; creaking timber and wind; quill sounds when charts update.
  - Haptics: a soft swell for landfall; a crack for a wreck.
- **Inspirations:** Civilization VII Arcade Edition proving appetite for full 4X on iPhone, iPad, and Mac, and Polytopia's lesson that readability beats detail.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **World model:** hex grid 160×80 wrapping east–west (cylinder), with latitude bands; `TruthWorld` is hidden; each crown has a `Chart`.
- **Rendering:** chart rendered into tiled textures (512×512 tiles) by a Metal compute pass from chart vector data (coast segments with error and confidence); SpriteKit composites tiles, ships, and UI. Globe view (RealityKit, P6) maps the same chart texture onto a sphere.
- **Turns:** one turn = one season; up to 160 turns (40 years).
- ADRs: ADR-0003 (cylindrical hex world), ADR-0004 (per-crown Chart model separate from truth), ADR-0005 (tiled chart texture via Metal), ADR-0006 (dead-reckoning navigation model).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/MRCore/Sources/MRCore/
  World/ Hex.swift, TruthWorld.swift, Biomes.swift, Winds.swift (seasonal by latitude), Currents.swift, Hazards.swift (reefs, shoals), Natives.swift (polities)
  Charts/ Chart.swift, CoastSegment.swift, ErrorModel.swift, Compilation.swift, ChartTrade.swift, Forgery.swift
  Fleet/ Ship.swift, ShipClass.swift, Captain.swift, Crew.swift, Provisions.swift, Voyage.swift, DeadReckoning.swift, Navigation.swift, Wreck.swift
  Economy/ Port.swift, Colony.swift, Goods.swift, Markets.swift, Treasury.swift
  Diplomacy/ Relations.swift, Treaties.swift, Espionage.swift
  Military/ NavalCombat.swift, Privateers.swift
  Tech/ TechTree.swift
  Victory/ Scoring.swift
  Reducer.swift, Replay.swift
Packages/MRContent/Sources/MRContent/ WorldGenerator.swift, CrownCatalog.swift, ShipCatalog.swift, TechCatalog.swift, GoodsCatalog.swift, EventCatalog.swift, Validation.swift
Packages/MRAI/Sources/MRAI/ CrownAI.swift, ExplorationPlanner.swift, TradePlanner.swift, ChartDiplomacy.swift, MilitaryPlanner.swift, Difficulty.swift
Packages/MRRender/Sources/MRRender/ ChartScene.swift, ChartTileRenderer.swift (Metal), Ornaments.swift (monsters, cartouches), VoyagePlotter.swift, LogReader.swift, LedgerViews/, GlobeView.swift (P6)
Packages/MRAudio/Sources/MRAudio/ Score.swift, Sea.swift
Packages/MRMeta/Sources/MRMeta/ Scenarios.swift, Hall.swift (records), Achievements.swift
Resources/Content/ crowns.json, ships.json, tech.json, goods.json, events.json, natives.json, worldgen.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**World and Truth**
- R-1 World generation (seeded) creates continents and islands (30–40% land), latitude-based climate, seasonal wind fields, currents, reefs and shoals, harbors, resources, and native polities.
- R-2 `TruthWorld` is never shown during play except in the end-of-game reveal and the debug overlay (stripped from Release builds).

**Charts**
- R-3 A `Chart` is a set of `CoastSegment { hexes, offsetEW, offsetNS, confidence (0–100), source (voyage, purchase, theft, forgery), age }` and known points of interest (harbors, hazards, rumored lands).
- R-4 When a ship sights coast (within sight radius 2, 3 with crow's nest tech), its log records the coast with an error: north–south error from latitude instruments (`±0–1` hex by tech), east–west error from accumulated dead-reckoning drift since the last fixed position (R-9).
- R-5 Compilation: when a ship returns to a home port, its log is compiled into the crown's chart; overlapping segments are merged by confidence-weighted average offset (integer math) and confidence increases; contradictory segments beyond 3 hexes remain as alternatives flagged "disputed".
- R-6 Charts can be traded (diplomacy), sold, stolen (espionage), or forged (the forger chooses segments to shift; forged segments carry hidden negative confidence known only to the forger).
- R-7 Rumors: native contacts and events add `rumor` segments with confidence 10–30.

**Navigation**
- R-8 Voyages are plotted as waypoints on the crown's chart. Each season a ship moves up to `speed × windFactor` hexes along its plotted course as the crew believes it to be.
- R-9 Dead reckoning: the ship's believed position and true position diverge each season by an east–west drift `d` drawn from the seeded RNG in `[−driftMax, +driftMax]` (by tech and captain Navigation skill) and by current effects unless the ship has current knowledge; latitude is corrected each season if the ship has a latitude instrument. A fixed position resets drift on landfall at a charted harbor with confidence ≥ 70.
- R-10 Hazards: entering a true reef/shoal hex risks wreck (`baseWreck` reduced by charted hazard knowledge and captain skill); storms by season and latitude damage hull and crew.
- R-11 Provisions: ships carry provisions in crew-seasons; at 0 provisions, crew suffer scurvy (−20% crew per season), morale falls, and mutiny becomes possible.

**Economy, Colonies, and Diplomacy**
- R-12 Ports and colonies produce goods by terrain and population; markets have prices per good that respond to supply (integer elasticity tables).
- R-13 Trade routes are standing orders between ports along charted courses; their success uses the navigation rules each season.
- R-14 Relations (−100 to +100) with other crowns and native polities; treaties: trade, chart exchange, non-aggression, alliance. Detected forgeries reduce relations by 40 with the victim and 15 with all others.
- R-15 Naval combat: simultaneous broadside exchange by ship class firepower, crew, and weather gauge; boarding; capture of a ship captures its log.

**Technology**
- R-16 Tech tree in 5 branches: Navigation (latitude instruments, log line, backstaff, chronometer), Shipbuilding, Cartography (compilation error reduction, projection), Medicine (scurvy mitigation), and Statecraft (espionage, charters). Research uses scholars funded by treasury.

**Victory**
- R-17 Score at game end (turn limit or "Map of the World" project completion): Chart Accuracy (true-coast hexes charted within 1 hex, weighted by confidence) × 3 + Wealth/100 + Colonies × 20 + Discoveries (first true charting of each landmass) × 15 + Treaties held × 5. A crown that completes the Map of the World project (requires 60% world accuracy and the chronometer) gains +150 and ends the game at the end of that year.

**Invariants**
- INV-1 Nothing in a crown's Chart or UI reveals truth not obtained through sighting, trade, theft, rumor, or forgery (each segment has provenance).
- INV-2 Ships' true positions are always on water; wrecks remove ships and logs.
- INV-3 Treasury, provisions, and crew within valid ranges.
- INV-4 Replay determinism at season checkpoints.
- INV-5 World generation always yields at least 4 landmasses and a sailable route between all home ports.

## 5. Data Schemas and Content Tables

```swift
struct CoastSegment: Codable, Hashable { let id: Int; var hexes: [Hex]; var offsetEW: Int; var offsetNS: Int; var confidence: Int; var provenance: Provenance; var turnRecorded: Int; var disputedWith: [Int] }
struct Ship: Codable, Hashable { let id: Int; var classID: String; var truePos: Hex; var believedPos: Hex; var drift: Int; var hull: Int; var crew: Int; var provisions: Int; var captain: CaptainID; var log: [LogEntry]; var orders: VoyageOrders }
```

`ships.json`: `{ "id": "carrack", "speed": 4, "hull": 60, "crew": 80, "cargo": 40, "guns": 12, "cost": 900, "tech": null }`. `tech.json`, `goods.json`, `crowns.json` (5 crowns with asymmetric bonuses: e.g. "Lusitania" cheaper caravels and better latitude, "Albion" privateers, "Hollandia" fluyts and trade, "Castilla" colony growth, "Venetia" chart forgery and espionage — all fictionalized names), `events.json` (≥ 120 by G5), `natives.json` (polity templates).

Content counts — G3: 3 crowns, 6 ship classes, 30 techs, 12 goods, 50 events, 6 native polity templates, 1 world preset. G5: 5 crowns, 9 ship classes, 45 techs, 18 goods, 120 events, 10 polity templates, 4 world presets (Pangaea-ish, Archipelagos, Twin Continents, Random), scenario: "The Spice Race" (short 40-turn), tutorial campaign.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `driftMax` (no tech) | 3 hexes/season | 1–5 |
| `latitudeErrorNoInstrument` | 1 | 0–2 |
| `baseWreck` | 25% | 10–40% |
| `scurvyLossPct` | 20 | 10–30 |
| `compileConfidenceGain` | 15 | 5–25 |
| `forgeryDetectChance` | 10%/season used | 5–25% |
| `turnLimit` | 160 | 60–200 |
| `worldLandPct` | 35 | 25–45 |

Targets (AI-only games, 200 per preset, Hard): each crown wins 12–28% in 5-crown games; median game length 120–160 turns; average wrecks per crown 6–15 per game; chart accuracy of winner at end 45–70%.

## 7. AI Approach

- **Same knowledge as players:** each AI crown plans only from its own Chart (INV-1 applies to AI).
- **Utility AI** with planners: Exploration (frontier value: unknown area adjacent to charted coast, weighted by rumor confidence and distance), Trade (route profit estimates from known prices), Colonization (site value from charted resources), Diplomacy (chart trades when expected accuracy gain outweighs rival gain; forgeries by personality), and Military (privateering on predicted routes).
- **Personalities:** Explorer, Merchant, Conqueror, Schemer, and Scholar weights in `ai_personalities.json`.
- **Difficulty:** Cabin Boy, Navigator, Admiral, and Sovereign (bonuses only in research cost and treasury, never in knowledge).
- **Budget:** full AI turn for 4 rivals p95 ≤ 3 s on iPad (A16), done in a background `Task` while the player reviews the season report.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.
- MR-P0.1 Cylindrical hex math (wrap distance, neighbors, lines) with tests.
- MR-P0.2 Spike: Metal chart tile renderer from 2,000 coast segments; pan/zoom at 120 fps on Mac.

```
GATE G0 — Setup: standard checks; chart spike perf logged · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- MR-P1.1 World generation (R-1, INV-5) with 500-seed validation.
- MR-P1.2 Charts, sighting error, and compilation (R-3 to R-5, R-7).
- MR-P1.3 Navigation, drift, hazards, and provisions (R-8 to R-11).
- MR-P1.4 Economy and trade routes (R-12, R-13).
- MR-P1.5 Diplomacy, chart trade, forgery, and naval combat (R-6, R-14, R-15).
- MR-P1.6 Tech tree and scoring (R-16, R-17).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-17 tagged tests; INV-1…INV-5 over 300 seeded random-play games; MRCore coverage ≥ 90%
  [ ] Headless 160-turn random game ≤ 20 s CPU on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- MR-P2.1 Chart view: pan, pinch, coast confidence by line style, unknown fog with placeholder monsters.
- MR-P2.2 Voyage plotter: drag waypoints on the chart; projected provisions and risk shown; commission ship and captain.
- MR-P2.3 Season resolution with a season report (log excerpts, landfalls, wrecks).
- MR-P2.4 Return-to-port compilation animation (chart updates segment by segment).
- MR-P2.5 One crown vs one simple AI crown on a small world (80×40), 40 turns, exploration and trade only.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays 40 turns with scripted voyages on iPad and Mac
  [ ] INV-1 live assertion in debug; end-of-game reveal compares chart vs truth
  [ ] Save/resume identical hash
Sign-off: REVIEW: GROK (is charting with error compelling?) + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- MR-P3.1 Colonies, markets, and goods to G3 counts.
- MR-P3.2 Diplomacy screens, chart trading UI (preview what a trade reveals at a summary level), and espionage/forgery.
- MR-P3.3 Naval combat resolution UI.
- MR-P3.4 Tech tree UI; events with choices.
- MR-P3.5 Tutorial campaign: 10 guided turns.

```
GATE G3 — Content and Systems: G3 counts; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- MR-P4.1 Crown AI with planners and personalities; difficulty tiers.
- MR-P4.2 AI-only sims and balance report.

```
GATE G4 — AI
Checks:
  [ ] 200 AI-only games per preset: 0 crashes; INV-1 holds for all AI crowns
  [ ] AI turn p95 ≤ 3 s for 4 rivals on Mac (iPad simulator reported)
  [ ] Win spread within targets or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- MR-P5.1 Five crowns, four world presets, and "The Spice Race" scenario.
- MR-P5.2 End-of-game reveal and "Hall of Charts" gallery (save finished charts as images).
- MR-P5.3 Achievements (30), stats, and game setup options (turn limit, land percentage, AI count).

```
GATE G5 — Meta and Replayability
Checks:
  [ ] All presets pass INV-5 for 500 seeds and AI sims within targets
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- MR-P6.1 Final portolan rendering: rhumb lines, compass roses, cartouches, monsters, and gold leaf; ink line weights by confidence.
- MR-P6.2 RealityKit globe view using the chart texture.
- MR-P6.3 Score and sea ambience.

```
GATE G6 — Aesthetics: globe ≥ 60 fps on iPad (A16); snapshots approved · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- MR-P7.1 Pencil: annotate charts (private notes layer), sketch routes, hover to show coast confidence and provenance.
- MR-P7.2 GameKit turn-based async for up to 4 humans (season turns; simultaneous orders committed then resolved by the host device's deterministic reducer, verified by state hashes on all devices).
- MR-P7.3 iCloud saves (large saves compressed with LZFSE).
- MR-P7.4 Mac: menus, shortcuts, multiple windows (chart and ledger).

```
GATE G7 — Platform: async 3-human game completes in sandbox with matching hashes; iCloud round-trip · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- MR-P8.1 Ledger views accessible to VoiceOver; chart summaries by region.
- MR-P8.2 Memory budget with 160×80 world and full chart: < 1.0 GB.

```
GATE G8 — Polish: perf budgets; cold start < 2.0 s; load save < 2.0 s · Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: knowledge provenance (INV-1), compilation merge math, and multiplayer hash verification.
- First pickups: GROK — crown asymmetry, events writing, and AI personalities; CLAUDE — chart renderer and multiplayer.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Scope too large | High | High | Cut combat depth and Map of the World project first; ship 3 crowns if needed | MAHLER |
| Error mechanic feels unfair | Medium | High | Clear provenance, risk projections, and fixed-position mechanics | GROK |
| Colonial-era themes | Medium | Medium | Fictional crowns; natives as polities with agency; Mahler review | MAHLER |
| AI too slow | Medium | Medium | Background turns, cached frontier evaluation | GLM |

## 11. Out of Scope

Land warfare beyond colony defense values; religion systems; real-time battles; more than 5 crowns; server-backed matchmaking.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 4–5 |
| P1 | GLM | 25–35 |
| P2 | GLM | 18–25 |
| P3 | GLM | 25–35 |
| P4 | GLM | 20–30 |
| P5 | GLM | 15–20 |
| P6 | GROK + CLAUDE | 25–40 |
| P7 | CLAUDE | 15–20 |
| P8 | CLAUDE | 10–15 |
| P9 | GROK + CLAUDE | 15–25 |
| P10 | CLAUDE + GROK | 4–6 |
| **Total** | | **176–256** |

## 13. Open Questions for Mahler

1. Fictionalized crowns vs historical nations? Default: fictionalized.
2. Ship v1 without online multiplayer? Default: yes if P7 is late; async is the first cut.
