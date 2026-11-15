# 11 — Lanternfall Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 11 · `lanternfall` |
| Code prefix | `LF` (packages `LFCore`, `LFContent`, `LFAI`, `LFRender`, `LFAudio`, `LFPlatform`, `LFMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Real-time-with-pause defense (roguelite run of nights) |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 15–25 minutes per night; 7-night run |
| Renderer | SpriteKit (2D) plus Metal 2D lighting pass |
| Players | Solo |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Defend a sleeping village through one long night by carrying, placing, and rationing light, because the creatures in the dark advance only where shadows reach.
- **Summary:** Creatures emerge from the forest at dusk and move only through cells dark enough for them. You place lanterns and torches that burn oil, order villagers to carry lights, and manage oil stores until dawn. Houses and trees cast shadows, wind flickers flames, and different creatures fear different colors of light. Between nights you trade, upgrade, and draft relics across a seven-night run.
- **Pillars:**
  1. **Light is territory.** Every decision is about where light falls and where shadows remain.
  2. **Pause is always available.** Real time builds tension; pause gives control.
  3. **Shadows are readable.** Players can always see the darkness map that creatures use.
  4. **Warm against cold.** The art is a duel between amber light and indigo night.
- **Aesthetic spec:**
  - Palette: night indigo `#141A33`, deep shadow `#0A0D1C`, amber flame `#FFB24A`, ember red `#E0612F`, moonstone blue `#7FB7FF`, phosphor green `#8CFF9E`, silhouette black `#050608`, paper-cut highlight `#F6E7C8`.
  - Visuals: shadow-puppet silhouettes (houses, trees, villagers, and creatures as cut-paper shapes with jointed limbs), light rendered as warm pools with soft falloff; creatures visible as silhouettes with glinting eyes at the edge of light.
  - Audio: frame drum heartbeat that quickens with threat, crickets that fall silent near creatures, crackling flames, wind gusts, a rooster at dawn.
  - Haptics: flicker pulses when a flame gutters; a heavy thump when a creature reaches a house.
- **Inspirations:** Thronefall's build-then-defend loop, Bad North's readable silhouettes and short battles, and the Kingdom series.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** fixed 30 Hz tick; grid 40×28 cells; integer light levels 0–8 per cell computed in Core with symmetric shadowcasting (deterministic, CPU) per light source, recomputed only when lights or occluders change, and per-tick flicker applied as an integer modifier from a seeded wind schedule.
- **Rendering:** a Metal lighting pass in `LFRender` renders smooth light from the same light sources for visuals, but gameplay uses only Core's integer grid. A debug overlay shows the gameplay darkness grid.
- ADRs: ADR-0003 (gameplay light grid in Core, visual light in Metal), ADR-0004 (symmetric shadowcasting), ADR-0005 (30 Hz tick).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/LFCore/Sources/LFCore/
  Map/ Cell.swift, Grid.swift, Occluders.swift (houses, trees, walls), Village.swift
  Light/ LightSource.swift (lantern, torch, brazier, carried light), LightColor.swift, Shadowcast.swift, LightGrid.swift, Wind.swift, Oil.swift
  Units/ Villager.swift, Creature.swift, CreatureKinds.swift, Pathing.swift (darkness-constrained), Jobs.swift (carry, refill, repair)
  Night/ NightClock.swift, Spawns.swift, Damage.swift, Dawn.swift
  Run/ RunState.swift, DayPhase.swift (trade, upgrade, relic draft), Relics.swift
  Reducer.swift, Replay.swift
Packages/LFContent/Sources/LFContent/ CreatureCatalog.swift, LightCatalog.swift, RelicCatalog.swift, VillageGenerator.swift, NightModifiers.swift, Validation.swift
Packages/LFAI/Sources/LFAI/ CreatureDirector.swift (wave pacing), CreatureBrains.swift, Autoplayer.swift
Packages/LFRender/Sources/LFRender/ VillageScene.swift, LightingPass.swift (Metal), SilhouetteNodes.swift, DarknessOverlay.swift, PlacementInput.swift, DayScreens/
Packages/LFAudio/Sources/LFAudio/ Heartbeat.swift, Ambience.swift, Fire.swift
Packages/LFMeta/Sources/LFMeta/ Unlocks.swift, Daily.swift, Achievements.swift
Resources/Content/ creatures.json, lights.json, relics.json, villages.json, modifiers.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Map and Light**
- R-1 Grid 40×28. Cells are ground, house (occluder, has HP 10, contains sleepers), tree (occluder), wall (occluder), well (oil refill point), or forest edge (spawn).
- R-2 A light source has color (amber, moonstone, or phosphor), radius r (lantern 4, torch 3, brazier 6, carried light 2), intensity 8 at the source, falling by `8 × d / (r + 1)` (integer) with distance d, and blocked by occluders via symmetric shadowcasting.
- R-3 Cell light level = maximum over sources of their contribution (0–8) per color; the cell's effective light for a creature uses the color weights for that creature (R-9).
- R-4 Wind: a seeded schedule of gusts; during a gust, sources not sheltered (no occluder within 1 cell upwind) lose 2 intensity; torches have a 10% chance per gust to go out.
- R-5 Oil: lanterns and braziers burn oil per second (lantern 1 per 10 s, brazier 1 per 5 s); each has a reservoir (lantern 12, brazier 20); at 0 oil the source goes out. Torches burn 90 s and then go out (no refill).

**Villagers and Jobs**
- R-6 Villagers (4–8 by village) can be ordered to: carry a light (becomes a mobile carried light), refill (walk to a well, take oil, refill a target), relight (relight an extinguished source), or repair (restore house HP). Villagers move 1 cell per 10 ticks through lit cells and 1 cell per 15 ticks through dark cells; villagers in darkness adjacent to a creature are attacked.
- R-7 The player can place new sources from the village stock (lanterns, torches, braziers) on ground cells within 2 cells of a villager or house, and reposition existing lanterns by assigning a villager to carry them.

**Creatures**
- R-8 Creatures spawn from forest edge cells according to the night's spawn schedule (R-12) and path toward the nearest house using A* over cells whose effective light ≤ their tolerance; if no path exists, they wait at the darkest reachable cell and probe (every 3 seconds re-path).
- R-9 Creature kinds (G3 set): Shade (tolerance 1, all colors weight 1, moves fast); Gloam (tolerance 3 to amber, 0 to moonstone: repelled by blue); Mothwraith (attracted to the brightest cell within 6, extinguishes the source it reaches unless it is phosphor); Burrower (ignores light while underground for 4 s, surfaces in darkness); Hollow Hound (tolerance 2, hunts villagers in darkness first); Wick-eater (drains 1 oil per second from adjacent sources).
- R-10 Creatures adjacent to a house deal damage per second; a house at 0 HP loses its sleepers (run penalty: −1 Hope each).
- R-11 Creatures in light above their tolerance flee at 1.5× speed to darkness and lose 1 HP per second (light is the only weapon; relics add more).

**Night and Run**
- R-12 A night lasts 6 real minutes at 1× (10,800 ticks) from dusk to dawn, with spawn waves at fixed times plus seeded variation; dawn kills all remaining creatures.
- R-13 Run: 7 nights. Hope starts at 10 (sleepers saved); losing all Hope ends the run. Between nights (Day phase): trade oil and crafts at the market, upgrade houses (lamp posts, shutters), and draft 1 of 3 relics.
- R-14 Night modifiers (from night 3): fog (all radii −1), new moon (base ambient light 0 instead of 1), storm (gusts double), harvest moon (ambient 2), and many more in `modifiers.json`.

**Invariants**
- INV-1 Light levels are integers 0–8 per color per cell; recomputed light equals a from-scratch shadowcast (test after every change).
- INV-2 Creatures never occupy cells with effective light above their tolerance except while fleeing or using a special ability (Burrower, Mothwraith).
- INV-3 Oil reservoirs within 0…max.
- INV-4 Replay determinism at 1,800-tick checkpoints across speeds and pauses.

## 5. Data Schemas and Content Tables

```swift
struct LightSource: Codable, Hashable { let id: Int; var kind: LightKind; var color: LightColor; var cell: Cell; var oil: Int; var lit: Bool; var carriedBy: Int? }
struct CreatureDef: Codable { let id: String; let hp: Int; let speedTicksPerCell: Int; let tolerance: [LightColor: Int]; let behavior: Behavior; let houseDamagePerSec: Int; let abilities: [String] }
enum Action: Codable { case placeLight(LightKind, LightColor, Cell), assignJob(villager: Int, Job), pause, resume, setSpeed(Int), dayBuy(String), dayUpgrade(String), draftRelic(String) }
```

`creatures.json` row:
```json
{ "id": "gloam", "hp": 6, "speedTicksPerCell": 12, "tolerance": { "amber": 3, "moonstone": 0, "phosphor": 2 }, "behavior": "nearest_house", "houseDamagePerSec": 1, "abilities": [] }
```

Content counts — G3: 6 creatures, 3 light colors, 4 light kinds, 20 relics, 3 village layouts, 6 night modifiers, tutorial (6 steps). G5: 12 creatures (including 2 boss nights: "The Long Dark" and "The Moth Queen"), 40 relics, procedural village generator, 15 modifiers, daily night.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `nightTicks` | 10800 | 7200–14400 |
| `startHope` | 10 | 6–14 |
| `lanternOilMax` / burn | 12 / 1 per 300 ticks | |
| `braziers` oil / burn | 20 / 1 per 150 ticks | |
| `torchTicks` | 2700 | 1800–3600 |
| `gustPenalty` | 2 | 1–3 |
| `ambientLight` | 1 | 0–2 |
| `wavesPerNight` | 5–8 by night | |

Targets (Autoplayer, 1,000 runs): run completion 25–40% at default difficulty; average Hope lost per night 0.5–1.5; no relic in > 50% of winning runs; each creature type responsible for 10–30% of house damage.

## 7. AI Approach

- **Creature brains:** per-kind behaviors (pathing over the darkness-constrained graph, probing, fleeing); deterministic.
- **Creature Director:** paces waves using a tension curve (target threat level by night time), selecting spawn edges where the player's light coverage is weakest (Hard) or randomly (Easy).
- **Autoplayer:** heuristic player that keeps lights fueled, covers house approaches by ray coverage, and responds to creature kinds by color; used for sims.
- **Budget:** creature updates for 80 creatures ≤ 1 ms per tick on iPad (A16).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- LF-P0.1 Spike: Metal 2D lighting pass with 40 lights and occluder shadows at 120 fps on Mac.

```
GATE G0 — Setup: standard checks; lighting spike logged · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- LF-P1.1 Grid, occluders, and shadowcast light grid (R-1 to R-3) with golden light maps.
- LF-P1.2 Wind and oil (R-4, R-5).
- LF-P1.3 Villagers and jobs (R-6, R-7).
- LF-P1.4 Creatures, pathing, damage, and fleeing (R-8 to R-11).
- LF-P1.5 Night clock, spawns, dawn, and run structure (R-12 to R-14).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-14 tagged tests; INV-1…INV-4 over 500 seeded nights; LFCore coverage ≥ 90%
  [ ] Headless night ≤ 1.0 s CPU on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- LF-P2.1 `VillageScene` with placeholder silhouettes and the Metal lighting pass.
- LF-P2.2 Drag lights from a tray onto valid cells (valid cells highlighted); drag from a villager to a target to assign a job; pinch on a lantern to swap color if the village stocks that color.
- LF-P2.3 Darkness overlay toggle (shows creature-passable cells per selected creature kind).
- LF-P2.4 Two-finger tap pauses; speed 1×/2×.
- LF-P2.5 One village, 3 creature kinds, 3 nights with Day phase (market and 6 relics).
- LF-P2.6 Mac: drag and drop, right-click for job menu, space to pause.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes 3 nights on iPad and Mac with scripted actions
  [ ] Visual light and gameplay light agree: snapshot test compares lit/dark classification within 1 cell
  [ ] 60 fps on iPad simulator with 40 lights and 60 creatures
Sign-off: GLM-SELF
```

### P3 Content and Systems
- LF-P3.1 All G3 creatures, lights, relics, layouts, and modifiers.
- LF-P3.2 Day phase screens: market, house upgrades, and relic draft.
- LF-P3.3 Tutorial (6 steps).

```
GATE G3 — Content and Systems: counts; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF
```

### P4 AI Opponents
- LF-P4.1 Creature Director with Easy, Normal, and Hard pacing; Autoplayer; balance report.

```
GATE G4 — AI
Checks:
  [ ] 1,000 Autoplayer runs: 0 crashes; creature update budget met
  [ ] Run completion within targets per difficulty or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- LF-P5.1 Procedural village generator (validated: every house reachable by creatures, wells reachable by villagers).
- LF-P5.2 G5 creatures, bosses, relics, and modifiers; unlockable villages and starting relics.
- LF-P5.3 Daily night; 25 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] 500 generated villages pass validation and sims
  [ ] Daily identical across devices for 30 dates
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- LF-P6.1 Cut-paper silhouettes with jointed animation, flame flicker, ember particles, and dawn transition.
- LF-P6.2 Heartbeat drum tied to threat, crickets that fall silent near creatures, and fire SFX.

```
GATE G6 — Aesthetics: snapshots approved · Sign-off: GLM-SELF
```

### P7 Platform Features
- LF-P7.1 Pencil hover previews a light's coverage before placement; squeeze opens the light tray; pressure sets lantern shutter width for directional lanterns (relic).
- LF-P7.2 Game Center: daily leaderboard, best run per village, 25 achievements; iCloud saves at day boundaries and mid-night.
- LF-P7.3 Mac menus and shortcuts; controller support.

```
GATE G7 — Platform: iCloud round-trip; controller completes a night · Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- LF-P8.1 High-contrast darkness overlay; creature outlines option; color alternatives (light colors also differ by flame shape).
- LF-P8.2 Assist mode (slower creatures, longer oil).

```
GATE G8 — Polish: 120 fps on iPad Pro M4 with 60 lights and 80 creatures; 60 fps on iPad (A16); cold start < 2.0 s · Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: GLM-SELF
GATE G10 — Release: assets approved · Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- Fragile areas: the agreement between visual and gameplay light; shadowcast recomputation triggers.
- Priorities for P6–P10: creature roster and relic synergies; lighting pass performance.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Visual light misleads players | Medium | High | Darkness overlay and agreement tests | GLM |
| Micromanagement overload | Medium | Medium | Pause, job queues, and villager auto-refill relic | GLM |
| Too similar to Thronefall/Kingdom | Low | Medium | Light-as-territory mechanic is unique | GLM |

## 11. Out of Scope

Combat units; base building beyond house upgrades; multiplayer; story campaign.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3 |
| P1 | GLM | 8–12 |
| P2 | GLM | 10–14 |
| P3 | GLM | 8–12 |
| P4 | GLM | 5–8 |
| P5 | GLM | 8–12 |
| P6 | GLM | 12–18 |
| P7 | GLM | 5–8 |
| P8 | GLM | 5–8 |
| P9 | GLM | 8–12 |
| P10 | GLM | 2–4 |
| **Total** | | **74–111** |

## 13. Open Questions

1. Tone: eerie but gentle (all ages) or genuinely scary? Default: eerie but gentle, 9+ rating.
