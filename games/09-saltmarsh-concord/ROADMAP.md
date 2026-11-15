# 09 — Saltmarsh Concord Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 09 · `saltmarsh-concord` |
| Code prefix | `SC` (packages `SCCore`, `SCContent`, `SCAI`, `SCRender`, `SCAudio`, `SCPlatform`, `SCMeta`) |
| Bundle ID (placeholder) | `com.zyniker.saltmarsh-concord` |
| Subgenre | Ecological 4X (turn-based) |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 30–90 minutes |
| Renderer | SpriteKit (2D hex map) with watercolor shaders |
| Players | Solo vs AI biome; local pass-and-play (two biomes) |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** You are not a civilization but an estuary ecosystem, spreading species and food webs to outcompete an invasive rival biome.
- **Summary:** On a hex map of an estuary, you seed species from your biome's pool into tiles that suit their niche. Populations grow, eat, and die by simple predator–prey rules. Tides and seasons shift salinity and depth. A rival biome spreads too, competing for niches. Each era you draft adaptations. After 40 seasons, the biome with the highest Biodiversity Index wins, unless one biome collapses the other's keystone species first.
- **Pillars:**
  1. **Systems, not soldiers.** Conflict is competition for niches and food, never unit combat.
  2. **Visible food webs.** Every population change can be traced to a cause on screen.
  3. **Balance over growth.** Overgrowth collapses; stability scores.
  4. **A naturalist's notebook.** Beautiful botanical plates teach real ecology lightly.
- **Aesthetic spec:**
  - Palette: paper `#F5F0E3`, estuary brown `#8C7A5B`, marsh green `#7FA36B`, seagrass `#4F7F5A`, brackish teal `#6FA3A0`, deep channel `#3C5F73`, rival biome rust `#B5653A`, annotation ink `#3A3530`.
  - Visuals: watercolor washes per salinity band; species as botanical-plate illustrations with Latin-style (fictionalized) names; hand-drawn arrows for food-web links; naturalist annotations appear as notes.
  - Audio: curlews, gulls, lapping water, wind in reeds; gentle cello and piano themes per season; a soft wash sound as populations spread.
  - Haptics: a gentle ripple at the tide change.
- **Inspirations:** Art of Fauna's naturalist plates and its 2025 inclusivity award, Wingspan's biology-as-strategy, and Dorfromantik's cozy appeal.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** discrete seasons; integer population dynamics (populations in "units" 0–999 per species per tile).
- **Renderer:** SpriteKit hex map; `SKShader` watercolor wash with paper-grain texture; population density shown by stipple density.
- ADRs: ADR-0003 (integer Lotka–Volterra variant), ADR-0004 (hex map 24×18), ADR-0005 (food web graph as content-defined diet lists).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/SCCore/Sources/SCCore/
  Map/ Hex.swift, Tile.swift (salinity 0–4, depth 0–3, substrate), Tides.swift, Seasons.swift, Disturbance.swift (storms, algal blooms, freezes)
  Life/ Species.swift, Niche.swift, Population.swift, Diet.swift, Dispersal.swift, Growth.swift, Predation.swift, Competition.swift, Traits.swift
  Biome/ BiomeState.swift, Actions.swift (seed, adapt, reintroduce, protect), Energy.swift (action points)
  Score/ BiodiversityIndex.swift, Keystone.swift, Victory.swift
  Reducer.swift, Replay.swift
Packages/SCContent/Sources/SCContent/ SpeciesCatalog.swift, BiomeCatalog.swift, TraitCatalog.swift, MapGenerator.swift, Scenarios.swift, Validation.swift (food-web connectivity)
Packages/SCAI/Sources/SCAI/ RivalBiomeAI.swift, Evaluator.swift, Lookahead.swift, Autoplayer.swift
Packages/SCRender/Sources/SCRender/ EstuaryScene.swift, WatercolorShader.swift, PopulationStipple.swift, FoodWebOverlay.swift, SpeciesPlateView.swift (SwiftUI), SeedingPainter.swift
Packages/SCAudio/Sources/SCAudio/ Soundscape.swift, SeasonMusic.swift
Packages/SCMeta/Sources/SCMeta/ FieldJournal.swift (discovered species), Scenarios.swift, Achievements.swift
Resources/Content/ species.json, biomes.json, traits.json, mapgen.json, scenarios.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Map and Environment**
- R-1 Map 24×18 hexes generated from a seeded estuary template: river inflow (fresh), sea edge (saline), channels (depth 2–3), mudflats, and marsh.
- R-2 Each tile has salinity (0 fresh to 4 marine), depth (0 emergent to 3 channel), and substrate (mud, sand, rock, or peat).
- R-3 Seasons cycle Spring → Summer → Autumn → Winter; 40 seasons total (10 years). Spring floods reduce salinity by 1 in river-adjacent tiles; Summer droughts raise it by 1 on mudflats; tides alternate depth by ±1 on tidal tiles each season.
- R-4 Disturbances (seeded): storm surge (salinity +2 along the coast for one season), algal bloom (kills 30% of filter-feeders in a region unless grazers exceed threshold), and hard freeze (kills 50% of cold-intolerant species on depth 0 tiles).

**Species and Populations**
- R-5 A species has trophic level (Producer, Grazer, Filter-feeder, Predator, Apex, or Decomposer), niche ranges (salinity, depth, substrate), growth rate, carrying capacity per tile, diet (list of species IDs with preference weights), dispersal range, and traits.
- R-6 Each season, for each tile and species, in fixed order Producer → Decomposer → Grazer/Filter-feeder → Predator → Apex:
  - Growth: `N' = N + N × r × (K − N) / K / 100` (integer, `r` as percent), where `K` is the tile capacity reduced to 0 if the niche does not fit.
  - Predation: predators consume prey by diet weights: `eaten = min(preyAvailable, predatorN × consumption / 100)`; predators that eat less than `need` lose `(need − eaten) × starvationRate` population.
  - Competition: species sharing ≥ 2 niche dimensions and trophic level on a tile split capacity proportional to their competitive score (growth + trait bonuses).
  - Decomposers convert deaths into a tile `nutrients` value that increases Producer `K` next season (+1% per 10 nutrient, max +30%).
- R-7 Dispersal: species with N ≥ 30% of K disperse 10% of N to suitable adjacent tiles (range by trait).
- R-8 Extinction: a population below 5 units disappears from the tile; a species with no tiles is extinct for that biome (can be reintroduced at cost).

**Biome Actions (Player and Rival)**
- R-9 Each season a biome has Energy = 3 + floor(Biodiversity Index / 20) (max 6) to spend on: `seed(species, tile)` (cost by trophic level: 1 producer/decomposer, 2 consumer, 3 apex; requires the species to be adjacent to an existing population of yours or at an inflow/sea edge), `adapt(species, trait)` (from drafted traits), `protect(tile)` (no rival seeding for 2 seasons, cost 2), and `restore(tile)` (shift salinity or depth by 1, cost 3, once per tile per year).
- R-10 Both biomes' species coexist on tiles and interact by diet and competition; species belong to a biome owner.

**Eras and Traits**
- R-11 Every 8 seasons is an era; at each era start, each biome drafts 1 of 3 traits (seeded) to apply to one species (e.g. Salt-tolerant: salinity range +1; Burrowing: survives freezes; Generalist diet: +1 diet entry; Rapid spawn: r +15%).

**Scoring and Victory**
- R-12 Biodiversity Index (BI) for a biome = Σ over its species with ≥ 3 tiles of `(10 + 5 × trophicLevelIndex)` + 3 × number of active food-web links between its species (predator eats prey where both present on ≥ 1 shared tile) + stability bonus (species whose total population changed < 20% over the last 4 seasons: +2 each).
- R-13 Keystone: each biome's apex or designated keystone species; if a biome's keystone is extinct for 4 consecutive seasons, that biome collapses and loses immediately.
- R-14 At the end of season 40, higher BI wins; tie → more tiles occupied → more species alive.

**Invariants**
- INV-1 Populations are integers in 0…999 per species per tile.
- INV-2 No population exists on a tile outside its niche for more than one season (it dies during growth with K = 0).
- INV-3 Energy spent per season ≤ Energy available.
- INV-4 The simulation order in R-6 produces identical results regardless of dictionary iteration (sorted iteration enforced).
- INV-5 Replay determinism.

## 5. Data Schemas and Content Tables

```swift
struct SpeciesDef: Codable { let id: String; let name: String; let biome: String; let trophic: Trophic; let salinity: ClosedRange<Int>; let depth: ClosedRange<Int>; let substrates: [Substrate]; let r: Int; let K: Int; let consumption: Int; let need: Int; let diet: [DietEntry]; let dispersal: Int; let traits: [String]; let keystone: Bool; let plate: String; let note: String }
```

`species.json` row:
```json
{ "id": "cordgrass", "name": "Spartina marisca", "biome": "salt_marsh", "trophic": "producer", "salinity": [2, 4], "depth": [0, 1], "substrates": ["mud", "peat"],
  "r": 40, "K": 600, "consumption": 0, "need": 0, "diet": [], "dispersal": 1, "traits": ["stabilizer"], "keystone": false,
  "plate": "plate_cordgrass", "note": "Its roots bind the marsh and slow the tide." }
```

Content counts — G3: 2 biomes (Salt Marsh and Invasive Reed-Crayfish), 16 species each, 18 traits, 2 map templates, 1 scenario. G5: 4 biomes (adds Mangrove and Kelp Reef), 20 species each, 30 traits, 5 map templates, 6 scenarios ("challenges" based on real estuary archetypes, fictionalized), field journal entries for all species.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `seasons` | 40 | 24–60 |
| `baseEnergy` | 3 | 2–4 |
| `dispersalThreshold` | 30% | 20–50% |
| `dispersalShare` | 10% | 5–20% |
| `starvationRate` | 50% | 30–80% |
| `extinctionFloor` | 5 | 1–10 |
| `keystoneCollapseSeasons` | 4 | 2–6 |
| `nutrientBonusCap` | 30% | 10–50% |

Targets (Autoplayer vs Normal AI, 1,000 games per biome pairing): each biome wins 42–58% against each other biome; keystone collapses end 10–25% of games; average species alive at end ≥ 60% of seeded; no single species present in > 80% of winning boards.

## 7. AI Approach

- **Rival biome:** evaluates each candidate action (≤ 150 per season after pruning to tiles adjacent to existing populations) by simulating 2 seasons ahead with the deterministic sim and a heuristic for the player's response (assumes player repeats last season's action pattern); evaluator = BI delta + keystone safety + territory.
- **Difficulty:** Gentle (1-season lookahead, prefers producers), Natural (2 seasons), and Relentless (2 seasons plus targeted competition against player keystone prey).
- **Autoplayer:** same algorithm for balance sims.
- **Budget:** p95 ≤ 1.0 s per AI season on iPad (A16); sims run headless on Mac.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.

```
GATE G0 — Setup: standard checks · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- SC-P1.1 Map, environment, seasons, and disturbances (R-1 to R-4).
- SC-P1.2 Population dynamics in strict order (R-5 to R-8) with analytic tests (e.g. a lone producer approaches K; predator without prey starves on schedule).
- SC-P1.3 Biome actions and eras (R-9 to R-11).
- SC-P1.4 BI, keystone, and victory (R-12 to R-14).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-14 tagged tests; INV-1…INV-5 over 2,000 seeds; SCCore coverage ≥ 90%
  [ ] Ecosystem stability test: a curated 6-species web stays alive for 40 seasons in ≥ 95% of seeds with no actions
  [ ] Headless game ≤ 300 ms CPU (without AI)
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- SC-P2.1 `EstuaryScene` with salinity washes, depth shading, and population stipples per species color.
- SC-P2.2 Seeding by dragging a species plate onto a tile (valid tiles glow; invalid tiles show the failing niche dimension); finger-paint mode seeds along a stroke spending Energy per tile.
- SC-P2.3 Tile inspector: tap a tile for its food web (arrows between present species, with populations and trend arrows).
- SC-P2.4 Season advance with an animated summary (biggest gains, losses, and why).
- SC-P2.5 Salt Marsh vs Invasive biome, 16 species each, Gentle AI, 40 seasons.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a 40-season game on iPad and Mac
  [ ] Season summary reasons match sim causes (test that each listed cause corresponds to a recorded Event)
  [ ] Save/resume identical hash
Sign-off: REVIEW: GROK (is the ecosystem legible and strategic?) + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- SC-P3.1 Traits and era drafts; disturbances with warnings one season ahead.
- SC-P3.2 Species plates (SwiftUI) with niche diagrams and notes.
- SC-P3.3 Tutorial: 8 steps (niches, seeding, food chains, competition, dispersal, tides, eras, keystone).
- SC-P3.4 Pass-and-play mode.

```
GATE G3 — Content and Systems: counts; content-lint 0 errors incl. food-web connectivity; tutorial UI test · Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- SC-P4.1 Rival biome AI with three difficulties; Autoplayer; balance report.

```
GATE G4 — AI
Checks:
  [ ] 1,000 games per pairing: 0 illegal actions; AI season p95 ≤ 1.0 s (Mac measured)
  [ ] Relentless beats Gentle ≥ 75%
  [ ] Balance targets met or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- SC-P5.1 Mangrove and Kelp Reef biomes; G5 counts; 5 map templates.
- SC-P5.2 Six scenarios with special goals (e.g. "restore a drained marsh", "survive a decade of storms").
- SC-P5.3 Field journal (species discovered, plates unlocked by play) and 24 achievements.
- SC-P5.4 Seeded "weekly estuary" challenge.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] All 6 biome pairings within 40–60% balance
  [ ] Weekly seed identical across devices for 8 weeks
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- SC-P6.1 Watercolor shader, paper grain, and plates for all species.
- SC-P6.2 Soundscape mixing by tile composition under the camera; season themes.

```
GATE G6 — Aesthetics: snapshots approved · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- SC-P7.1 Pencil: paint seeding with pressure controlling stroke width (1–2 tiles); hover shows salinity, depth, and substrate; squeeze opens the species palette.
- SC-P7.2 Game Center achievements, weekly leaderboard, iCloud saves.
- SC-P7.3 Mac menus and shortcuts.

```
GATE G7 — Platform: iCloud round-trip; Pencil paint and finger paint produce identical actions for identical tiles · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- SC-P8.1 Species distinguished by stipple shape as well as color; high-contrast map mode.
- SC-P8.2 VoiceOver tile descriptions and food-web lists.

```
GATE G8 — Polish: perf budgets; VoiceOver completes the tutorial · Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; SC-P9.1 an ecology-literate tester review for plausibility (Mahler approves testers).

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: sim order and integer rounding; food-web connectivity validation.
- First pickups: GROK — species design and biome asymmetry; CLAUDE — watercolor rendering and plate views.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Chaotic dynamics feel random | Medium | High | Damped equations, summaries with causes, and 1-season previews | GROK |
| Ecology inaccuracies | Medium | Low | Fictionalized species; plausible rules; tester review | GROK |
| Low perceived agency | Medium | Medium | Strong action set (restore, protect, adapt) and keystone tension | GROK |

## 11. Out of Scope

Human settlements; climate-change campaign narrative; real species names; multiplayer online.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 10–14 |
| P2 | GLM | 10–14 |
| P3 | GLM | 10–14 |
| P4 | GLM | 8–12 |
| P5 | GLM | 10–14 |
| P6 | GROK + CLAUDE | 15–22 (plus illustration) |
| P7 | CLAUDE | 5–7 |
| P8 | CLAUDE | 5–8 |
| P9 | GROK + CLAUDE | 8–12 |
| P10 | CLAUDE + GROK | 3–4 |
| **Total** | | **86–123** |

## 13. Open Questions for Mahler

1. Real or fictionalized species? Default: fictionalized with real-inspired behavior.
2. Should conservation partners be considered (like Art of Fauna)? Default: Mahler's decision post-launch.
