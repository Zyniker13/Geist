# 04 — Night Market Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 04 · `night-market` |
| Code prefix | `NM` (packages `NMCore`, `NMContent`, `NMAI`, `NMRender`, `NMAudio`, `NMPlatform`, `NMMeta`) |
| Bundle ID (placeholder) | `com.zyniker.night-market` |
| Subgenre | City logistics (real-time, pausable) |
| Difficulty tier | Approachable |
| Scope | Solo-indie |
| Session length | 10–20 minutes |
| Renderer | SpriteKit (2D) with additive-blend glow shaders |
| Players | Solo |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Route crowds through a pop-up night market that rearranges itself every evening, and keep the lanterns lit and the queues short until dawn.
- **Summary:** Stalls of different colors open on a schedule across a city block. Customers enter through gates and seek a stall of their color. You draw walkways from a limited tile budget, hang lanterns, raise awnings, and place buskers to steer the crowd. Each in-game hour you choose an upgrade. The night ends when a stall's queue overflows for too long; the score is customers served.
- **Pillars:**
  1. **Calm to start, frantic to finish.** The first minutes are meditative; the end is a scramble.
  2. **Crowds you can read.** Every customer is a dot whose color, speed, and path explain the system.
  3. **Real places, abstracted.** Each map evokes a real city's night market through layout and palette.
  4. **One finger is enough.** Every verb is a drag or a tap.
- **Aesthetic spec:**
  - Palette: night ground `#0E1016`, walkway `#2A2E3A`, lantern glow `#FFB547`, stall colors (color-blind-safe set, each with a shape): noodles `#FF5A5F` circle, tea `#3DDC97` triangle, skewers `#FFD23F` square, dumplings `#5AA9FF` diamond, sweets `#C77DFF` star, seafood `#FF8C42` hexagon; rain tint `#7FA7C9`.
  - Shapes: flat minimal tiles, stalls as rounded rectangles with an awning stripe, customers as 5-pt dots with a soft glow.
  - Motion: lantern flicker (1–2% luminance noise), steam puffs at busy stalls, rain streaks.
  - Audio: lo-fi city-pop music in 4 stems added as density rises; sizzle, chatter, and bicycle-bell ambience mixed by crowd density; a soft chime per served customer.
  - Haptics: tick per placed tile; warning pulse when a queue nears overflow.
- **Inspirations:** Mini Metro and Mini Motorways (weighted spawn zones, spawn schedules, and familiar real-world aesthetics) and Thronefall's clean premium loop.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** fixed tick of 30 Hz in `NMCore`; positions in fixed-point sub-tile units (1 tile = 1,024 units, `Int32`); speed multiplier (1×, 2×, 3×) runs more ticks per frame; pause stops ticks.
- **Pathing:** per-stall-color flow fields (Dijkstra over the walkway graph) recomputed only when walkways, lights, awnings, buskers, or weather change.
- **Rendering:** SpriteKit with a pooled `SKSpriteNode` per customer (max 600) and an additive glow layer (`SKEffectNode` avoided for performance; pre-baked glow sprites instead).
- ADRs: ADR-0003 (30 Hz fixed tick), ADR-0004 (flow fields over per-agent A*), ADR-0005 (tile grid 32×20).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/NMCore/Sources/NMCore/
  Model/ Tile.swift, Grid.swift, Walkway.swift, Stall.swift, Gate.swift, Seat.swift, Fixture.swift (lantern, awning, busker, bridge), Customer.swift, Weather.swift, Clock.swift, GameState.swift
  Sim/ Tick.swift, Spawner.swift, FlowField.swift, Movement.swift (density slowdown), Service.swift (queues), Overflow.swift, Scoring.swift
  Actions/ Action.swift, Reducer.swift, Budget.swift
  Replay/ Replay.swift (timed actions by tick)
Packages/NMContent/Sources/NMContent/ MapCatalog.swift (weighted zones), Schedules.swift, UpgradeCatalog.swift, Validation.swift
Packages/NMAI/Sources/NMAI/ AutoPlanner.swift (balance bot), DirectorTuner.swift
Packages/NMRender/Sources/NMRender/ MarketScene.swift, TileLayer.swift, CustomerPool.swift, GlowLayer.swift, Input/WalkwayPainter.swift, HUD/QueueGauges.swift, HUD/UpgradePicker.swift
Packages/NMAudio/Sources/NMAudio/ StemMixer.swift, Ambience.swift
Packages/NMMeta/Sources/NMMeta/ Challenges.swift (daily/weekly), Unlocks.swift, Stats.swift
Resources/Content/ maps/*.json, schedules.json, upgrades.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Map and Setup**
- R-1 The grid is 32×20 tiles; tiles are `ground`, `water` (canal, impassable without a bridge), `building` (impassable), or `plaza`.
- R-2 A map defines gates (2–4 at the edge), weighted spawn zones per stall color, and a stall schedule (R-6).
- R-3 Start: 2 stalls open (seeded positions from zones), 1 gate active, walkway budget 30 tiles, 2 lanterns, 0 awnings, 0 buskers.

**Clock**
- R-4 The night runs from 18:00 to 06:00; one in-game hour = 1,800 ticks (60 seconds at 1×).
- R-5 At each hour boundary the player chooses 1 of 2 upgrade offers (drawn by seed from `upgrades.json` weights); the simulation pauses until a choice is made.

**Stalls, Customers, and Gates**
- R-6 Schedule: new stalls open at scheduled ticks (± seeded jitter of up to 300 ticks), placed by weighted zone sampling on free ground tiles at least 3 tiles from other stalls; a new gate opens at 21:00 and 00:00 if the map has more.
- R-7 Customers spawn at gates at a rate that ramps by hour (`spawnRate[hour]` customers per minute), with color chosen proportionally to open stalls of each color.
- R-8 Customer lifecycle: walk to the nearest reachable stall of its color via flow field → join queue → be served → walk to the nearest reachable free seat within 8 path tiles (if any; sits 300 ticks) → walk to the nearest gate → despawn.
- R-9 A customer with no reachable stall of its color waits at the gate; waiting customers count toward that color's nearest stall's overflow (R-12).

**Movement and Steering**
- R-10 Movement is only on walkway, plaza, and bridge tiles. Edge cost (per tile step): base 10; dark tile (no lantern within radius 3) +6; rain and no awning +12; within busker radius 2 −3 (min 4); corner turn +2.
- R-11 Speed: base 48 units/tick; on a tile with n customers, speed = base × (100 − 15 × (n − 1)) / 100, min 12.

**Service and Overflow**
- R-12 Each stall serves one customer per `serviceTicks` (default 90). Queue capacity is 6 plus waiting gate customers attributed to it. When the queue exceeds capacity, an overflow timer runs (shown as a ring); it resets to 0 when back under capacity. Timer ≥ 600 ticks (20 s) ends the night.
- R-13 Score = customers served; a full night survived (reaching 06:00) adds a dawn bonus of 25% of the score.

**Actions (Allowed While Paused or Running)**
- R-14 `paintWalkway([Tile])` consumes budget per new tile; tiles must be ground or plaza; `eraseWalkway([Tile])` refunds the budget fully (no penalty) but customers on erased tiles are moved to the nearest walkway.
- R-15 `placeFixture(kind, tile)` and `moveFixture(id, tile)`: lanterns light radius 3; awnings cover a 3×3 area; buskers attract within radius 2; bridges span exactly 1–3 water tiles in a straight line.
- R-16 `chooseUpgrade(id)` at hour boundaries; `setSpeed(1|2|3)`; `pause`/`resume`.

**Weather**
- R-17 Rain showers are scheduled by seed (0–3 per night, 90–180 s each, never before 19:00); during rain the R-10 penalty applies.

**Invariants**
- INV-1 Walkway tiles used ≤ budget.
- INV-2 Customers occupy only traversable tiles; no customer is in two queues.
- INV-3 Customers served is non-decreasing.
- INV-4 Flow fields are consistent: following the field from any reachable tile reaches a stall of that color in finite steps.
- INV-5 Replay determinism (same seed and timed actions → same hash at every 1,800-tick checkpoint).

## 5. Data Schemas and Content Tables

```swift
struct Customer: Codable, Hashable { var id: Int; var color: StallColor; var pos: FixedPoint2; var state: CustomerState; var targetStall: Int? }
enum Action: Codable { case paintWalkway([Tile]), eraseWalkway([Tile]), placeFixture(FixtureKind, Tile), moveFixture(Int, Tile), chooseUpgrade(String), setSpeed(Int), pause, resume }
struct TimedAction: Codable { let tick: Int; let action: Action }
enum Event: Codable { case stallOpened(Int), gateOpened(Int), served(Int, StallColor), overflowWarning(Int, progress: Int), rainStarted, rainEnded, hourReached(Int, offers: [String]), nightEnded(score: Int, survived: Bool) }
```

Map file `maps/taipei.json`:
```json
{ "id": "taipei", "name": "Taipei", "size": [32, 20], "tiles": "base64-rle", "gates": [[0, 9], [31, 10], [15, 0]],
  "zones": { "noodles": [[4, 4, 8, 6, 3]], "tea": [[20, 3, 6, 5, 2]] },
  "schedule": "schedule_standard", "palette": "neon_warm" }
```
`upgrades.json` row: `{ "id": "walkway_20", "kind": "budget", "amount": 20, "weight": 30 }`. Upgrade kinds: walkway budget (+20), lanterns (+2), awning (+1), busker (+1), bridge (+1), seating block (+1, 3 seats), faster cooks (one stall serviceTicks −20%), extra queue (one stall capacity +2).

Content counts — G3: 3 maps (Taipei, Bangkok, and Marrakesh), 6 stall colors, 8 upgrade kinds, 1 schedule, tutorial of 6 steps. G5: 6 maps (adds Oaxaca, Seoul, and Istanbul), 3 schedules (Standard, Festival, and Monsoon), daily and weekly challenge modifiers (12), sandbox mode.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `ticksPerHour` | 1800 | 1200–2400 |
| `startBudget` | 30 | 20–50 |
| `serviceTicks` | 90 | 60–150 |
| `queueCapacity` | 6 | 4–10 |
| `overflowTicks` | 600 | 300–900 |
| `spawnRate` (per hour) | 6, 9, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48 | |
| `lanternRadius` | 3 | 2–4 |
| `darkPenalty` | 6 | 3–10 |
| `rainPenalty` | 12 | 6–20 |

Targets (AutoPlanner bot, 1,000 seeded nights per map): median survival 01:00–03:00; ≤ 10% of nights survive to dawn for the bot; first overflow never before 20:00 in ≥ 95% of nights; skilled human (Grok review) should reach dawn on Taipei within 5 attempts.

## 7. AI Approach

No opponent. P4 builds:
- **AutoPlanner:** a heuristic player that, on each stall opening, paints the shortest walkway path (Steiner-tree approximation via successive shortest paths) from the gate network to the stall, places lanterns on the highest-traffic dark tiles, and picks upgrades by a fixed priority. Used only for sims and difficulty tuning.
- **DirectorTuner:** a CLI that sweeps `spawnRate` and schedule jitter to hit targets and writes recommended values to `docs/BALANCE.md` (values only change in JSON after a human or Grok approves).
- **Daily challenge:** seed `hash("NM-daily-" + yyyyMMdd UTC)` picks map, schedule, stall jitter, rain plan, and one modifier; weekly uses ISO week.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.
- NM-P0.1 Fixed-point 2D vector type with tests.
- NM-P0.2 Spike: 600 pooled sprites moving at 120 fps in SpriteKit; record in `docs/PERF.md`.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; 600-sprite spike ≥ 120 fps on Mac and ≥ 60 fps on iPad simulator
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- NM-P1.1 Grid, walkways, budget (R-1, R-14).
- NM-P1.2 Spawner and schedule with seeded jitter (R-6, R-7).
- NM-P1.3 Flow fields with cost modifiers (R-10) and invalidation on edits.
- NM-P1.4 Customer lifecycle, density slowdown, service, overflow, and scoring (R-8, R-9, R-11 to R-13).
- NM-P1.5 Fixtures and weather (R-15, R-17).
- NM-P1.6 Headless `Tools/sim` running full nights with scripted TimedActions; performance target 1 night ≤ 1.5 s CPU on Mac.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-17 tagged tests; INV-1…INV-5 over 500 seeded nights; NMCore coverage ≥ 90%
  [ ] Checkpoint hashes identical across two runs and across Debug/Release builds
  [ ] Headless night ≤ 1.5 s CPU on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- NM-P2.1 `MarketScene` with Taipei map, placeholder palette, and customers as colored dots.
- NM-P2.2 Walkway painting by finger drag (tile snapping; Mini Motorways-style auto-joining tile art from a 16-tile autotile atlas); two-finger drag erases; budget counter.
- NM-P2.3 Lantern and awning placement by drag from a tray; long-press a stall for its queue and service stats.
- NM-P2.4 Hour-boundary upgrade picker; speed controls and pause.
- NM-P2.5 Results screen with served count, survival time, and a heatmap of traffic.
- NM-P2.6 Mac: click-drag paint, right-drag erase, space pauses, 1/2/3 speeds.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full night on Taipei with scripted actions to the results screen on iPad and Mac
  [ ] 400 simultaneous customers at 60 fps on iPad simulator debug overlay
  [ ] Pause/resume and save/resume mid-night restore identical hashes
Sign-off: REVIEW: GROK + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- NM-P3.1 Bangkok and Marrakesh maps with distinct zone weights and features (canals with bridges in Bangkok; narrow alleys in Marrakesh).
- NM-P3.2 All 8 upgrade kinds; buskers; seating; bridges.
- NM-P3.3 Rain with visual and pathing effects.
- NM-P3.4 Tutorial (6 steps) and a calm first-night mode with slower ramp.

```
GATE G3 — Content and Systems
Checks:
  [ ] G3 content counts; content-lint 0 errors
  [ ] Tutorial UI test; every upgrade has tests
Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Balance Bot) (Owner: GLM)
- NM-P4.1 AutoPlanner and DirectorTuner; balance report.

```
GATE G4 — Balance Tooling
Checks:
  [ ] AutoPlanner completes 1,000 nights per map without illegal actions
  [ ] Targets in §6 met or tuning ADR recorded
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- NM-P5.1 Three more maps; Festival and Monsoon schedules.
- NM-P5.2 Daily and weekly challenges with 12 modifiers (e.g. "lanterns cost double", "two gates only", "everyone wants tea").
- NM-P5.3 Unlocks: maps unlock by score thresholds; sandbox unlocks after first dawn.
- NM-P5.4 Stats and 20 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Daily/weekly seeds identical across devices for 30 dates/8 weeks
  [ ] 6 maps pass AutoPlanner sims within targets
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- NM-P6.1 Neon and lantern glow, steam, rain, and per-city palettes.
- NM-P6.2 Four-stem music system tied to crowd density; ambience layers.

```
GATE G6 — Aesthetics: snapshots approved; audio peak ≤ −1 dBFS · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- NM-P7.1 Game Center: per-map leaderboards, daily and weekly challenges, 20 achievements.
- NM-P7.2 iCloud sync of profile and unlocks (nights are short; no mid-night cloud saves, only local).
- NM-P7.3 Pencil: precise painting with hover showing the tile under the tip; squeeze toggles erase.
- NM-P7.4 Mac menus, window resizing (map letterboxes), and full screen.

```
GATE G7 — Platform: leaderboards post in sandbox; iCloud round-trip · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- NM-P8.1 Stall shapes plus colors; a high-contrast mode.
- NM-P8.2 VoiceOver summaries of queue states; an "assist" setting that lengthens overflow timers by 50%.
- NM-P8.3 Perf with 600 customers.

```
GATE G8 — Polish
Checks:
  [ ] 120 fps on iPad Pro M4 with 600 customers; 60 fps on iPad (A16); cold start < 2.0 s
  [ ] Color-blind simulation review passes for all 6 stall colors
Sign-off: REVIEW: GROK + REVIEW: MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: flow-field invalidation, density slowdown tuning, and tick determinism across speed settings.
- First pickups: GROK — map design and city palettes; CLAUDE — rendering performance and glow.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too similar to Mini Motorways | Medium | High | Lean on light, rain, music, and seating mechanics plus the night-market identity | GROK |
| Crowd sim cost on older iPads | Medium | Medium | Cap customers at 600; flow fields not per-agent A* | GLM |
| Cultural representation of real markets | Low | Medium | Abstract layouts; respectful palettes; review by Mahler | MAHLER |

## 11. Out of Scope

Multiplayer; user-made maps sharing; character customization; economy beyond the tile budget.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2–3 |
| P1 | GLM | 6–9 |
| P2 | GLM | 7–10 |
| P3 | GLM | 5–8 |
| P4 | GLM | 3–5 |
| P5 | GLM | 5–8 |
| P6 | GROK + CLAUDE | 8–12 |
| P7 | CLAUDE | 4–6 |
| P8 | CLAUDE | 4–6 |
| P9 | GROK + CLAUDE | 5–8 |
| P10 | CLAUDE + GROK | 2–3 |
| **Total** | | **51–78** |

## 13. Open Questions for Mahler

1. Which six cities ship first? Default: Taipei, Bangkok, Marrakesh, Oaxaca, Seoul, and Istanbul.
2. Should Night Market be pitched to Apple Arcade? Default: build premium-first; pitching is Mahler's call.
