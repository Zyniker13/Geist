# 13 — Terrace Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 13 · `terrace` |
| Code prefix | `TR` (packages `TRCore`, `TRContent`, `TRAI`, `TRRender`, `TRAudio`, `TRPlatform`, `TRMeta`) |
| Bundle ID (placeholder) | `com.zyniker.terrace` |
| Subgenre | Cooperative-competitive builder (real-time, pausable) |
| Difficulty tier | Approachable |
| Scope | Small team |
| Session length | 15–45 minutes |
| Renderer | RealityKit (3D isometric diorama) with a Metal water surface shader |
| Players | Solo with AI villages |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Carve rice terraces down a misty mountain and share one stream with three villages, where every field you flood is water someone downhill does not get.
- **Summary:** You carve terraces into a mountainside heightmap, dig channels, and set sluice gates. Water flows downhill in real time through your fields and on to three AI villages. Rice needs the right water depth at each growth stage across wet and dry seasons. Hoarding water raises your harvest but sours relations; sharing through a water-temple schedule raises Harmony, which unlocks festivals and blessings. Cozy endless and challenge modes.
- **Pillars:**
  1. **Water is the shared resource.** Every choice is visible downstream.
  2. **Calm by default.** No fail states in cozy mode; challenge mode adds stakes.
  3. **Tactile earth.** Carving and channeling should feel like sculpting.
  4. **A living diorama.** Mist, light, and water are the art.
- **Aesthetic spec:**
  - Palette: jade terrace `#6FA36F`, young rice `#A8D07A`, ripe rice `#D9C35C`, water mirror `#9CC7D9`, mist `#EEF2F0`, earth `#7A5B3E`, stone `#8E8A82`, temple red `#B84A3A`.
  - Visuals: isometric diorama of a mountain slice with stepped terraces; water as reflective planes with flow ripples; morning mist that burns off; villagers as tiny figures working fields.
  - Audio: gamelan-inspired ambient score (metallophones and gongs, in non-appropriative original compositions), frogs, trickling water by flow rate, temple bells for schedule changes.
  - Haptics: soft grain while carving; a gentle pulse when a sluice opens.
- **Inspirations:** Dorfromantik's and Islanders' cozy minimalism, Townscaper's constraint-driven forms, and Against the Storm's seasons.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** heightmap 64×64 cells; integer terrain height (0–255) and water volume (0–4,095) per cell; deterministic cellular-automaton flow at 10 Hz (fixed order: process cells sorted by terrain height descending, then index); evaporation and rain by season.
- **Rendering:** RealityKit mesh generated from the heightmap (rebuilt per chunk of 16×16 on edit), a Metal-shader water surface via `CustomMaterial`, and particle mist.
- ADRs: ADR-0003 (RealityKit diorama), ADR-0004 (integer water CA), ADR-0005 (chunked mesh rebuilds).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/TRCore/Sources/TRCore/
  Terrain/ Heightmap.swift, Carve.swift (terrace tool), Channel.swift, Sluice.swift, Retaining.swift (walls)
  Water/ FlowCA.swift, Rain.swift, Evaporation.swift, Spring.swift, Outflow.swift
  Farming/ Field.swift (a connected flat terrace region), RiceStage.swift, Yield.swift, Labor.swift
  Villages/ Village.swift, Needs.swift, Relations.swift, Harmony.swift, WaterTemple.swift (schedule), Festivals.swift
  Seasons/ Calendar.swift, Monsoon.swift, Drought.swift
  Reducer.swift, Replay.swift
Packages/TRContent/Sources/TRContent/ MountainGenerator.swift, VillagePersonalities.swift, FestivalCatalog.swift, Challenges.swift, Validation.swift
Packages/TRAI/Sources/TRAI/ VillageAI.swift, Negotiation.swift, Autoplanner.swift
Packages/TRRender/Sources/TRRender/ DioramaView.swift (RealityView), TerrainMesh.swift, WaterMaterial.swift, Mist.swift, CarveInput.swift, Villagers.swift, Panels/ (SwiftUI: TempleSchedule, VillageLedger)
Packages/TRAudio/Sources/TRAudio/ Metallophones.swift, WaterAmbience.swift
Packages/TRMeta/Sources/TRMeta/ CozyMode.swift, Challenges.swift, Gallery.swift (photo mode), Achievements.swift
Resources/Content/ mountains.json, villages.json, festivals.json, challenges.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Terrain and Tools**
- R-1 A seeded mountain heightmap of 64×64 cells includes a spring at the top (constant inflow), slopes, rock outcrops (uncarvable), and an outflow at the bottom edge. The player's land is the upper third; three villages occupy the middle and lower thirds in order (Upper, Middle, and Lower).
- R-2 Carve: drag across cells to flatten them to a single target height (the height of the first touched cell), within the player's land; each carved cell costs 1 Labor; slope changes greater than 3 between adjacent carved cells require a retaining wall (auto-placed, +1 Labor).
- R-3 Channel: lower a 1-cell-wide path by 2 height units (min 0 relative to neighbors); costs 1 Labor per cell.
- R-4 Sluice: placed on a channel cell; open or closed (closed blocks flow); toggling is free; 1 Labor to place.
- R-5 Labor regenerates by village population (player's hamlet: 4 Labor per in-game day) and is spent immediately.

**Water**
- R-6 Each tick (10 Hz), the spring adds inflow volume by season; cells are processed in descending terrain-height order; each cell distributes water to lower neighbors (4-connected) proportional to height-plus-water differences (integer division, remainder kept), capped by a flow rate.
- R-7 Evaporation removes 1 volume per 20 ticks from cells with water < 32 in the dry season; rain adds volume to all cells during the wet season and monsoon events.
- R-8 Water that reaches the bottom edge leaves the map (outflow).

**Fields and Rice**
- R-9 A field is a connected region of ≥ 4 flat carved cells at the same height; planting costs 1 Labor per cell at the start of a season.
- R-10 Rice stages (per season of 30 in-game days): Seedling (needs water depth 8–24), Tillering (24–64), Flowering (32–64), Ripening (0–16, drain the field). Each day in range adds 1 health; out of range subtracts 1; yield = cells × average health × stage multiplier.
- R-11 Harvest at the end of Ripening adds rice to the player's store; rice feeds labor and is offered at festivals.

**Villages and Harmony**
- R-12 Each AI village has fields and water needs per stage; a village's satisfaction rises when its fields are in range and falls when starved of water.
- R-13 Relations (0–100) with each village change with satisfaction attributable to upstream flow (the player's outflow into their land is measured each day).
- R-14 Water Temple schedule: a calendar of 30-day seasons divided into 6 five-day windows; for each window the player assigns priority (Self, Upper, Middle, or Lower). During a window assigned to a village, the player's main sluices receive a target (open) and Harmony rises if honored; ignoring the schedule costs Harmony.
- R-15 Harmony (0–100, shared) unlocks festivals at 40/60/80 (each gives a blessing: e.g. +1 Labor per day, monsoon warning, faster growth) and is the score in cozy mode; challenge mode scores total harvest × (Harmony / 50).
- R-16 Monsoon (wet-season event, seeded) multiplies rain ×3 for 5 days: unwalled terraces with water above capacity erode (cells lose 1 height), damaging fields. Drought (dry-season event) halves spring inflow for 10 days.

**Modes**
- R-17 Cozy mode: endless years, no failure; Harmony and harvest tracked. Challenge mode: 3 years, scored; a village whose relations stay below 15 for a season leaves (challenge penalty).

**Invariants**
- INV-1 Total water is conserved each tick except spring inflow, rain, evaporation, and outflow (tested by accounting).
- INV-2 Terrain heights are only modified by carve, channel, wall placement, and erosion events.
- INV-3 Labor never negative.
- INV-4 Flow results are independent of hash-map iteration (sorted processing enforced).
- INV-5 Replay determinism at daily checkpoints.

## 5. Data Schemas and Content Tables

```swift
struct Cell: Codable, Hashable { var height: UInt8; var water: UInt16; var kind: CellKind; var owner: Owner; var carved: Bool; var wall: Bool }
struct Village: Codable, Hashable { let id: Int; var personality: String; var fields: [FieldID]; var satisfaction: Int; var relation: Int }
enum Action: Codable { case carve([Cell2]), channel([Cell2]), placeSluice(Cell2), toggleSluice(Int), plant(FieldID), harvest(FieldID), setTempleWindow(window: Int, priority: Priority), pause, resume, setSpeed(Int) }
```

`villages.json` personality row:
```json
{ "id": "patient", "name": "The Patient Elders", "satisfactionDecay": 1, "relationSensitivity": 0.6, "festivalFavor": "lantern" }
```

Content counts — G3: 3 mountain templates, 4 village personalities, 6 festivals/blessings, tutorial (7 steps). G5: procedural mountain generator plus 6 handmade mountains, 8 personalities, 12 festivals, 10 challenge scenarios, photo mode.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `tickHz` | 10 | fixed |
| `ticksPerDay` | 300 | 200–600 |
| `springInflow` wet/dry | 24/12 per tick | |
| `flowRateCap` | 64 | 32–128 |
| `laborPerDay` | 4 | 3–6 |
| `stageRanges` | per R-10 | |
| `monsoonRainMultiplier` | 3 | 2–4 |
| `harmonyGainHonor` / `lossIgnore` | 2 / 4 per window | |

Targets (Autoplanner, 500 challenge runs per mountain): median challenge score within a 20% band across mountains; Harmony ≥ 60 achievable while harvest ≥ 70% of max greedy harvest (proves sharing is viable); villages leave in ≤ 15% of Autoplanner runs.

## 7. AI Approach

- **Village AI:** each village plants, tends, and sets its own sluices to maximize its yield with available inflow; satisfaction and relations update by rules; personalities alter sensitivity.
- **Negotiation:** at season start, villages request temple windows based on stage needs; the request list is shown to the player.
- **Autoplanner (sims only):** carves a standard terrace ladder from templates, follows village requests above a Harmony threshold, and drains for ripening on schedule.
- **Budget:** village AI per day ≤ 5 ms; water CA ≤ 2 ms per tick on iPad (A16).

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.
- TR-P0.1 Spike: RealityKit heightmap mesh (64×64) with chunk rebuild ≤ 8 ms and a water material; 120 fps on Mac.

```
GATE G0 — Setup: standard checks; mesh spike logged · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- TR-P1.1 Heightmap, carve, channel, sluice, walls, and labor (R-1 to R-5).
- TR-P1.2 Water CA, rain, evaporation, and outflow (R-6 to R-8) with conservation tests (INV-1).
- TR-P1.3 Fields, rice stages, and yield (R-9 to R-11).
- TR-P1.4 Villages, relations, temple schedule, and Harmony (R-12 to R-15).
- TR-P1.5 Monsoon, drought, erosion, and modes (R-16, R-17).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-17 tagged tests; INV-1…INV-5 over 300 seeded years; TRCore coverage ≥ 90%
  [ ] Headless year ≤ 3 s CPU on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- TR-P2.1 Diorama view with orbit (one-finger drag on empty sky or two-finger rotate), pinch zoom, and tap-to-inspect.
- TR-P2.2 Carve by dragging across terrain (preview outline of the flattened area and Labor cost), channel tool, and sluice placement and toggling.
- TR-P2.3 Water visualization: depth color plus flow ripples; field stage indicators (in-range glow).
- TR-P2.4 One mountain, 2 villages, temple schedule panel (SwiftUI), and one full year in cozy mode.
- TR-P2.5 Mac: mouse orbit with right-drag, scroll zoom, and tool shortcuts (C carve, H channel, S sluice).

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays one full year with scripted tools on iPad and Mac
  [ ] Water accounting overlay matches INV-1 in debug builds
  [ ] 60 fps on iPad simulator while water flows over the whole mountain
Sign-off: REVIEW: GROK (is sharing water a meaningful dilemma?) + REVIEW: MAHLER (is it soothing and beautiful?)
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- TR-P3.1 Three mountains, four personalities, and six festivals.
- TR-P3.2 Monsoon/drought warnings and erosion visuals; retaining walls.
- TR-P3.3 Tutorial (7 steps) and the village ledger panel.

```
GATE G3 — Content and Systems: counts; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- TR-P4.1 Village AI, negotiation, and Autoplanner; balance report.

```
GATE G4 — AI: 500 runs per mountain with 0 crashes; budgets met; targets met or ADR · Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- TR-P5.1 Procedural mountain generator (validated: spring reaches outflow; each village has ≥ 6 flat-able cells of farmland); six handmade mountains.
- TR-P5.2 Ten challenge scenarios; eight personalities; twelve festivals.
- TR-P5.3 Photo mode (hide UI, time-of-day slider, depth of field) and 20 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] 500 generated mountains pass validation and Autoplanner sims
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- TR-P6.1 Final terrain materials, water reflections, mist, time-of-day lighting, and villager animation.
- TR-P6.2 Original gamelan-inspired score (composed for the game; cultural consultant recommended, Mahler decides) and water ambience scaled by flow.

```
GATE G6 — Aesthetics: snapshots approved; 120 fps on iPad Pro M4 · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- TR-P7.1 Pencil: sketch channels and terrace outlines with hover previews of flattened height; squeeze switches tools.
- TR-P7.2 Game Center challenge leaderboards and 20 achievements; iCloud save sync for cozy worlds.
- TR-P7.3 Mac menus, shortcuts, and window resizing; photo mode export to Photos (with permission prompt).

```
GATE G7 — Platform: iCloud round-trip of a cozy world; photo export works · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- TR-P8.1 Water depth readable without color (contour lines option); field stage icons.
- TR-P8.2 VoiceOver panels for fields, villages, and schedule; Reduce Motion removes camera drift and mist animation.
- TR-P8.3 Battery: a 30 fps cozy option for long sessions.

```
GATE G8 — Polish: perf budgets for 3D (memory < 1.5 GB); cold start < 2.0 s · Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: water CA conservation and performance, chunked mesh rebuilds, and temple schedule edge cases.
- First pickups: CLAUDE — rendering and water material; GROK — village personalities and festival design.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Cultural sensitivity (Balinese subak inspiration) | Medium | Medium | Fictional setting, original music, respectful research and consultant | MAHLER |
| Water sim too slow on older iPads | Medium | High | 64×64 cap, sorted CA in tight loops, profiling in P0 | GLM |
| Too low-stakes for strategy players | Medium | Medium | Challenge mode with scored dilemmas | GROK |

## 11. Out of Scope

Crops other than rice in v1; multiplayer; real-world locations; full village management.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3–4 |
| P1 | GLM | 8–12 |
| P2 | GLM | 12–16 |
| P3 | GLM | 6–9 |
| P4 | GLM | 5–8 |
| P5 | GLM | 8–12 |
| P6 | GROK + CLAUDE | 15–22 |
| P7 | CLAUDE | 5–7 |
| P8 | CLAUDE | 5–8 |
| P9 | GROK + CLAUDE | 6–10 |
| P10 | CLAUDE + GROK | 2–4 |
| **Total** | | **75–112** |

## 13. Open Questions for Mahler

1. Should the setting be explicitly Balinese or a fictional terraced culture? Default: fictional, inspired by several terrace traditions.
