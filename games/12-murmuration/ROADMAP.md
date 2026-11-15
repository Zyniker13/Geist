# 12 — Murmuration Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 12 · `murmuration` |
| Code prefix | `MU` (packages `MUCore`, `MUContent`, `MUAI`, `MURender`, `MUAudio`, `MUPlatform`, `MUMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Real-time territory control |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 5–10 minutes per day |
| Renderer | Metal (MTKView) instanced rendering for birds and landscape layers, hosted in SwiftUI (no SpriteKit) |
| Players | Solo vs AI flock; local two-flock versus on one iPad |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Steer a flock of thousands of starlings with sweeping gestures to claim roosts, evade falcons, and outmaneuver a rival flock.
- **Summary:** You guide a flock by drawing curves the flock follows. Feeding on fields grows the flock; falcons dive on thin edges and split it; wind currents help or hinder. At dusk, the flock with the most birds settled in each roost claims it. A migration campaign crosses twelve regions, each a short day.
- **Pillars:**
  1. **Gesture is the only interface.** No buttons during play; the flock responds to fingers.
  2. **Emergent beauty is the feedback.** Good play looks like a breathtaking murmuration.
  3. **Five minutes, complete.** A day is a full game.
  4. **Gentle to learn, subtle to master.** Cohesion, splitting, and timing reward skill.
- **Aesthetic spec:**
  - Palette (dusk gradient per region): apricot `#F6B48F`, rose `#D9849B`, violet `#6E5A99`, dusk indigo `#2E2A4F`; birds in ink `#1B1A22` with slight iridescent highlights `#3E5C6B`; rival flock in warm sepia `#5A3B2A`; fields as soft ochre `#C9A35B` and green `#7E9C6A`.
  - Visuals: minimal landscape silhouettes in layered parallax; birds as ink-wash strokes rendered with instancing and motion blur; falcons as sharp dark crescents.
  - Audio: generative ambience where the wingbeat bed thickens with flock size and density; soft pads per region; a whoosh as the flock turns sharply.
  - Haptics: continuous light texture during steering scaled by flock speed; a sharp tap when a falcon strikes.
- **Inspirations:** Dinosaur Polo Club's mechanic-first minimalism and the essay on Bad North's fusion of beauty and strategy.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** CPU, fixed 30 Hz tick, fixed-point boids (`Int32` positions in a 4,096×3,072 world unit space) with a uniform spatial hash; up to 3,000 birds per flock (two flocks max 4,000 total). Swift SIMD integer types allowed in Core.
- **Rendering:** Metal instanced quads, interpolated between ticks at 120 Hz; GPU never feeds back into gameplay (determinism).
- ADRs: ADR-0003 (CPU fixed-point boids for determinism), ADR-0004 (Metal instancing), ADR-0005 (bird cap 3,000 per flock).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/MUCore/Sources/MUCore/
  Sim/ Bird.swift, Flock.swift, SpatialHash.swift, Boids.swift (separation, alignment, cohesion), Leader.swift (gesture-driven target path), Wind.swift, Energy.swift, Growth.swift
  World/ Region.swift, Field.swift, Roost.swift, Obstacle.swift (cliffs, towers), DayClock.swift
  Predators/ Falcon.swift, Dive.swift
  Scoring/ RoostClaim.swift, Victory.swift
  Reducer.swift, Replay.swift
Packages/MUContent/Sources/MUContent/ RegionCatalog.swift, Campaign.swift, Modifiers.swift, Validation.swift
Packages/MUAI/Sources/MUAI/ RivalFlockAI.swift, FalconAI.swift, Autoplayer.swift
Packages/MURender/Sources/MURender/ FlockRenderer.swift (Metal), Landscape.swift, GestureInput.swift, Shaders/*.metal
Packages/MUAudio/Sources/MUAudio/ WingbeatGranular.swift, Pads.swift
Packages/MUMeta/Sources/MUMeta/ Migration.swift, Daily.swift, Achievements.swift
Resources/Content/ regions/*.json, campaign.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**World and Day**
- R-1 A region is a 2D world with fields (food), roosts (2–5), obstacles, and a seeded wind field (vector per 256-unit cell, changes every 20 seconds).
- R-2 A day lasts 4,800 ticks (160 seconds at 1×); the last 900 ticks are dusk, when roost claims accumulate.

**Flock Control**
- R-3 The player's input produces a `LeaderPath` (sequence of world points sampled at tick resolution); the flock's leader point moves along the path at the flock's max speed.
- R-4 Gestures map to actions: one finger draws the leader path; two fingers apart draws two paths and splits the flock proportionally by nearest path (sub-flocks); a pinch condenses (cohesion ×2 for 60 ticks, then cooldown 120 ticks); lifting all fingers leaves the leader point circling its last position.
- R-5 Sub-flocks merge automatically when their centroids are within 200 units for 30 ticks.

**Boids**
- R-6 Each tick each bird updates velocity: separation (neighbors within 24 units), alignment (within 64), cohesion (within 96), leader attraction (toward the leader point of its sub-flock), wind, and obstacle avoidance; weights in `balance.json`; speed clamped to `[minSpeed, maxSpeed]`.
- R-7 Neighbor queries use the spatial hash with deterministic iteration order (sorted by bird ID within a cell).

**Energy, Feeding, and Growth**
- R-8 Flock energy (per sub-flock, 0–1,000) drains by 1 per tick per 100 birds while flying; birds within a field's radius feed, adding energy by field richness (fields deplete and regrow).
- R-9 For every 200 energy above 600, the sub-flock gains 5% birds (spawned at the flock's centroid); at 0 energy, birds drop out at 1% per 10 ticks.

**Predators**
- R-10 Falcons patrol and select dive targets: the bird group with the lowest local density at the flock's edge; a dive kills birds within a 30-unit radius of its path (density-dependent: fewer kills in dense areas) and forces a split if the dive passes through the centroid region.
- R-11 Dense flocks (average neighbor count ≥ 10) reduce dive success by 50%.

**Roosts and Victory**
- R-12 During dusk, each roost counts birds within its radius per flock each tick; claim points accrue to the flock with the majority.
- R-13 At day end, a roost is claimed by the flock with the most claim points; the day's winner holds more roosts (tie → more birds alive). In solo-objective regions (no rival), the goal is to roost a target number of birds.

**Invariants**
- INV-1 Bird count changes only through growth, falcons, starvation, and roost settling events.
- INV-2 Birds never occupy obstacle interiors at tick end.
- INV-3 Simulation is deterministic across devices (checkpoint hashes every 300 ticks).
- INV-4 Spatial hash queries return exactly the neighbors a brute-force search returns (property test on 1,000 configurations).

## 5. Data Schemas and Content Tables

```swift
struct Bird { var pos: SIMD2<Int32>; var vel: SIMD2<Int32>; var subFlock: UInt8 }  // stored in struct-of-arrays inside Flock
struct RegionDef: Codable { let id: String; let size: [Int]; let fields: [FieldDef]; let roosts: [RoostDef]; let obstacles: [Polygon]; let windSeedOffset: Int; let falcons: Int; let rival: RivalDef?; let palette: String; let objective: Objective }
enum Action: Codable { case leaderPath(subFlock: Int, points: [Point]), split(paths: [[Point]]), condense, pause, resume }
```

Region row example:
```json
{ "id": "fenlands", "size": [4096, 3072], "fields": [ { "center": [800, 2200], "radius": 220, "richness": 4 } ],
  "roosts": [ { "center": [3400, 900], "radius": 180 } ], "obstacles": [], "windSeedOffset": 7, "falcons": 1,
  "rival": { "startBirds": 600, "difficulty": "gentle" }, "palette": "dusk_apricot", "objective": { "type": "versus" } }
```

Content counts — G3: 6 regions, 2 falcon behaviors, rival flock, tutorial (5 steps). G5: 12-region migration campaign, 6 daily modifiers (strong winds, extra falcons, scarce fields, fog, double roosts, and tiny flock), local two-flock versus mode, daily wind map.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `startBirds` | 800 | 300–1500 |
| `maxBirdsPerFlock` | 3000 | fixed |
| `sepRadius/alignRadius/cohRadius` | 24/64/96 | |
| `weights sep/align/coh/leader/wind` | 1.5/1.0/0.8/1.2/0.6 (Fixed) | |
| `maxSpeed/minSpeed` | 40/18 units per tick | |
| `energyDrainPer100` | 1 | |
| `diveRadius` | 30 | 20–50 |
| `densityShield` | 10 neighbors | 6–14 |
| `dayTicks` / `duskTicks` | 4800 / 900 | |

Targets (Autoplayer vs Gentle/Normal/Hard rival, 500 days per region): Autoplayer win rates 85% / 60% / 35%; median flock size at dusk 1,000–2,500; falcon losses 5–20% of peak flock.

## 7. AI Approach

- **Rival flock AI:** a steering planner that chooses waypoint sequences (fields → safe corridors → contested roost) by scoring field richness, falcon proximity, wind assistance, and the player's flock position; replans every 60 ticks; Hard uses splits to contest two roosts.
- **Falcon AI:** target selection per R-10 with cooldowns; patrol along region edges.
- **Autoplayer:** gesture-generating bot for sims and UI tests (produces `LeaderPath` actions).
- **Budget:** AI planning ≤ 0.5 ms per tick; whole sim tick (4,000 birds) ≤ 4 ms on iPad (A16).

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- MU-P0.1 Spike: 4,000 fixed-point boids at 30 Hz on CPU plus Metal instanced rendering at 120 fps on Mac; record tick time.

```
GATE G0 — Setup: standard checks; boid tick ≤ 4 ms for 4,000 birds on Mac Release build · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- MU-P1.1 Spatial hash and boids (R-6, R-7, INV-4).
- MU-P1.2 Leader paths, splits, condense, and merges (R-3 to R-5).
- MU-P1.3 Energy, feeding, and growth (R-8, R-9).
- MU-P1.4 Falcons (R-10, R-11).
- MU-P1.5 Roosts, dusk, and victory (R-1, R-2, R-12, R-13).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-13 tagged tests; INV-1…INV-4; MUCore coverage ≥ 90%
  [ ] Checkpoint hashes identical across two runs, Debug vs Release, and on an arm64 simulator vs Mac
  [ ] Headless day ≤ 10 s CPU with 4,000 birds on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- MU-P2.1 `FlockRenderer` with interpolation, simple landscape layers, and region palette.
- MU-P2.2 Gesture input: one-finger path, two-finger split, pinch condense; visual trace of the leader path fading over 1 s.
- MU-P2.3 Three regions with a Gentle rival and one falcon.
- MU-P2.4 Dusk claim visualization (roosts fill with flock color) and results card.
- MU-P2.5 Mac: click-drag path, ⌥-drag second path, scroll-pinch to condense.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays three days with Autoplayer-generated gestures on iPad and Mac
  [ ] 120 fps on Mac and 60 fps on iPad simulator with 3,000 birds
  [ ] Pause/resume preserves checkpoint hashes
Sign-off: GLM-SELF
```

### P3 Content and Systems
- MU-P3.1 Six regions with obstacles and wind patterns; two falcon behaviors.
- MU-P3.2 Tutorial (5 steps) and solo-objective regions.
- MU-P3.3 Local two-flock versus on one iPad (each player owns half the screen's touches by flock color nearest).

```
GATE G3 — Content and Systems: counts; content-lint 0 errors; tutorial UI test; versus mode UI test · Sign-off: GLM-SELF
```

### P4 AI Opponents
- MU-P4.1 Rival flock AI with three difficulties; falcon AI tuning; balance report.

```
GATE G4 — AI: 500 days per region with 0 crashes; win rates within targets or ADR; AI budget met · Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- MU-P5.1 Twelve-region migration campaign with carried flock size between regions.
- MU-P5.2 Daily wind map and 6 modifiers; local best scores.
- MU-P5.3 Achievements (20) and stats (largest flock, longest unbroken flight).

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Campaign completes in an Autoplayer UI test
  [ ] Daily identical across devices for 30 dates
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- MU-P6.1 Ink-wash bird shader with motion blur and iridescence; layered dusk landscapes per region.
- MU-P6.2 Granular wingbeat synthesis driven by flock size, density, and turning rate; regional pads.

```
GATE G6 — Aesthetics: snapshots and screen recordings approved · Sign-off: GLM-SELF
```

### P7 Platform Features
- MU-P7.1 ProMotion: verify 120 Hz interpolation; Game Center daily leaderboard, campaign leaderboards, 20 achievements; iCloud progress.
- MU-P7.2 Pencil: path drawing with hover preview of the leader path; Mac trackpad gestures (two-finger pan to split).

```
GATE G7 — Platform: iCloud round-trip; leaderboards post in sandbox · Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- MU-P8.1 Reduce Motion: lower bird count rendering and no camera sway; high-contrast rival flock patterning.
- MU-P8.2 Assist steering option (auto-avoid falcons).
- MU-P8.3 Thermal testing for 30 minutes.

```
GATE G8 — Polish: 120 fps on iPad Pro M4 with 4,000 birds; 60 fps on iPad (A16); no serious thermal state in 30 min · Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: GLM-SELF
GATE G10 — Release: assets approved · Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- Fragile areas: fixed-point boid stability (oscillation at high cohesion), determinism across devices, and thermal load.
- Priorities for P6–P10: rendering and thermal optimization; region design and rival tuning.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Shallow strategy | Medium | High | Splits, falcons, wind, and contested roosts; G2 review on decision depth | GLM |
| CPU sim too heavy on older iPads | Medium | Medium | Bird cap scaling by device class (documented, deterministic per mode) | GLM |
| Steering feels imprecise | Medium | High | Leader point visualization and tuned leader weight | GLM |

## 11. Out of Scope

Online multiplayer; other bird species as playable flocks (post-launch idea); narrative.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3–4 |
| P1 | GLM | 6–9 |
| P2 | GLM | 7–10 |
| P3 | GLM | 4–6 |
| P4 | GLM | 4–6 |
| P5 | GLM | 4–6 |
| P6 | GLM | 8–12 |
| P7 | GLM | 3–5 |
| P8 | GLM | 4–6 |
| P9 | GLM | 4–6 |
| P10 | GLM | 2–3 |
| **Total** | | **49–73** |

## 13. Open Questions

1. Should device-class bird caps be allowed (breaking cross-device leaderboard parity)? Default: leaderboards use a fixed cap of 3,000 on all devices; visuals may render fewer.
