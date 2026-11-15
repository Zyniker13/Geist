# 05 — Dispatch Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 05 · `dispatch` |
| Code prefix | `DS` (packages `DSCore`, `DSContent`, `DSAI`, `DSRender`, `DSAudio`, `DSPlatform`, `DSMeta`) |
| Bundle ID (placeholder) | `com.zyniker.dispatch` |
| Subgenre | Real-time-with-pause operational wargame |
| Difficulty tier | Hardcore |
| Scope | Small team |
| Session length | 45–120 minute scenarios; save anywhere |
| Renderer | SpriteKit (2D staff map) plus PencilKit annotation layer |
| Players | Solo vs AI |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Command a 1916 corps from a château headquarters where every order travels by runner, wire, or pigeon, and arrives late into a battle that has already changed.
- **Summary:** You never see the true battlefield. Your staff map shows what officers last reported, with timestamps and their personal biases. Orders are written to division commanders and physically travel to them; officers interpret orders through their traits. You allocate artillery, reserves, and supply, pause at will, and annotate your map with Pencil. Fronts and officer rosters are procedural, and scenarios are historically inspired with fictional sector names.
- **Pillars:**
  1. **The map is a belief.** Everything shown is a report, never omniscient truth (except in the after-action replay).
  2. **Latency is the enemy.** Good play anticipates; bad play reacts.
  3. **People, not counters.** Officers have names, traits, and voices that color reports and execution.
  4. **Desk-grade depth with a calm interface.** Dense information, but always pausable and legible.
- **Aesthetic spec:**
  - Palette: map paper `#E9E1CC`, contour brown `#9A7B55`, friendly grease pencil `#2C4A7A`, enemy grease pencil `#A3322A`, typewriter ink `#22201C`, carbon blue `#3D4E6B`, stale-report gray `#9C978C`.
  - Visuals: 1:20,000 staff map with contours, woods, villages, and trench lines; unit symbols in period-style NATO-like boxes drawn as if by hand; report markers fade toward gray as they age.
  - Dispatches: typewritten carbon-copy slips with officer signature, time sent, and time received.
  - Audio: sparse piano and cello score, distant artillery rumble scaled by intensity, Morse clicks for wire arrivals, pigeon wingbeats, a runner's knock.
  - Haptics: a click when a dispatch arrives; a deep rumble when a barrage you ordered begins (as reported).
- **Inspirations:** The strong iPad adaptations of Twilight Struggle and Through the Ages, Feral's general-in-a-tent framing for ROME, and the premium wargame niche.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Simulation:** fixed tick = 10 game-seconds; speeds 1× (1 game-minute per real second), 4×, 16×, and pause. All Core math integer or `Fixed`.
- **Two models:** `TruthState` (the real battle) and `BeliefState` (per-HQ knowledge built only from received reports). Render reads `BeliefState` during play and `TruthState` only in after-action replay.
- **Map:** hex grid of 250 m hexes, 64×40 per scenario.
- **Text:** deterministic template-based dispatch generation (no network, no language model) with officer voice tables.
- **Annotations:** PencilKit `PKCanvasView` overlay in `DSRender`, saved per scenario as `PKDrawing` data alongside saves (never in Core).
- **Layout:** iPad uses a split view (map plus dispatch board); Mac and iPad Stage Manager support a second window for the dispatch board.
- ADRs: ADR-0003 (truth/belief split), ADR-0004 (tick length), ADR-0005 (template text generation), ADR-0006 (PencilKit annotations outside Core).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/DSCore/Sources/DSCore/
  Map/ Hex.swift, Terrain.swift, MapGrid.swift, Roads.swift, WireNetwork.swift
  Forces/ Unit.swift (battalion), Formation.swift (brigade/division), Officer.swift, Traits.swift, Supply.swift, Artillery.swift
  Orders/ Order.swift, Courier.swift (runner/wire/pigeon), Interpretation.swift
  Sim/ Tick.swift, Movement.swift, Combat.swift (fixed-point attrition), Morale.swift, Barrage.swift, WireDamage.swift, Initiative.swift (officers acting without orders)
  Intel/ Report.swift, ReportGenerator.swift (noise by reliability), BeliefState.swift
  Victory/ Objectives.swift, Scoring.swift
  Reducer.swift, Replay.swift
Packages/DSContent/Sources/DSContent/ ScenarioCatalog.swift, FrontGenerator.swift, OfficerNames.swift, VoiceTables.swift, Validation.swift
Packages/DSAI/Sources/DSAI/ EnemyCommander.swift, InfluenceMap.swift, OperationalPlanner.swift, TacticalExecutor.swift, Difficulty.swift
Packages/DSRender/Sources/DSRender/ StaffMapScene.swift, ReportMarkers.swift, OrderComposer.swift, DispatchBoard.swift, AnnotationLayer.swift (PencilKit), AfterActionReplay.swift
Packages/DSAudio/Sources/DSAudio/ Score.swift, Battlefield.swift, Telegraph.swift
Packages/DSMeta/Sources/DSMeta/ Campaign.swift, Ironman.swift, Stats.swift
Resources/Content/ scenarios/*.json, officers.json, voices.json, units.json, terrain.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Map and Forces**
- R-1 Hex terrain: open, woods, village, ridge (elevation 1–2), marsh, river (crossable at bridges/fords), trench (friendly or enemy), wire (obstacle), road.
- R-2 Units are battalions with `men`, `morale` (0–100), `ammo` (0–100), `fatigue` (0–100), `entrenchment` (0–3), and `type` (infantry, machine-gun company, field artillery battery, heavy battery, cavalry, engineers).
- R-3 Formations: brigade (2–4 battalions) under division (2–3 brigades plus artillery) under corps (player). Each division and brigade has an `Officer`.
- R-4 Officer traits (1–5 each): Aggression, Caution, Initiative, Reliability, and Endurance. Traits drive interpretation (R-12), initiative (R-13), and report accuracy (R-16).

**Orders and Transmission**
- R-5 The player writes orders only to division officers (and the corps artillery and reserve). Order types: `attack(objective, hFrom: Time)`, `advance(to)`, `hold(line)`, `withdraw(to)`, `bombard(area, from, to, intensity)`, `creepingBarrage(path, lift: minutes)`, `releaseReserve(to, division)`, `resupply(division, priority)`, `report(now)`.
- R-6 Each order chooses a courier: runner (travel time = path movement time × 1.0 with a loss chance per hex under fire 2%), wire (delay 5–15 minutes if the wire path from HQ to the division HQ is intact; impossible otherwise), or pigeon (fixed 30 minutes, 10% loss, only from forward to HQ for reports unless lofts exist).
- R-7 Wire paths are graphs; each barrage tick on a wire hex cuts it with probability by intensity; engineers repair at 1 hex per 20 minutes when ordered or by initiative.
- R-8 An order arrives at time `sent + delay`; officers act on the latest order received; superseded orders are ignored.

**Simulation**
- R-9 Movement: battalions move hex to hex with time cost by terrain and fatigue; roads halve cost; formations keep cohesion (max 2 hexes between brigade units) unless ordered otherwise.
- R-10 Combat (each tick, between adjacent engaged units and in fire range for machine guns and artillery): `losses = firepower × fireModifier(terrain, entrenchment, visibility) × suppressionFactor / 1000` (fixed-point); morale loss proportional to losses relative to strength; at morale < 25 a unit breaks and withdraws toward its rear; at < 10 it routs.
- R-11 Artillery: barrages apply suppression (reduces target firepower) and casualties within the area per tick; creeping barrages advance at the ordered lift rate; ammunition is consumed per battery-tick; friendly fire occurs if friendly units are in the barrage area.
- R-12 Interpretation: when an officer receives `attack`, a Caution ≥ 4 officer delays until a preparatory barrage on the objective has been reported (or 30 minutes pass); Aggression ≥ 4 commits reserves early and may exceed the objective by 1–2 hexes; Endurance affects fatigue recovery; formulas in `balance.json`.
- R-13 Initiative: officers with Initiative ≥ 3 act without orders when (a) their unit is attacked and holding is untenable (withdraw), (b) an adjacent enemy unit breaks (exploit 1–2 hexes), or (c) their wire is cut and their last order is stale > 60 minutes (follow default posture). Initiative actions are reported later.

**Intelligence**
- R-14 `BeliefState` holds, per known unit (friendly or enemy), the last reported position, strength estimate, posture, and report time. It is updated only when a report arrives at HQ.
- R-15 Reports are sent by officers every `reportInterval` minutes (trait-dependent), on contact, on breaking, and on order receipt; they travel back via the same courier rules (R-6).
- R-16 Report noise: strength estimates are off by up to `(6 − Reliability) × 8%`; enemy unit positions are off by up to `(6 − Reliability) / 2` hexes; Aggressive officers overstate enemy losses; Cautious officers overstate enemy strength (biases in `balance.json`).
- R-17 Observation: enemy units are reported only if within 3 hexes of a friendly unit (2 in woods; 5 from ridges); aircraft reconnaissance (scenario-dependent) reports a rectangle at fixed times.

**Victory**
- R-18 Scenarios define objectives (hexes with VP and hold duration), casualty ratio scoring, and a time limit; result tiers: Decisive Victory, Victory, Draw, Defeat, Disaster.

**Invariants**
- INV-1 `BeliefState` never contains information not delivered by a report (test: every belief entry has a source report ID with arrival time ≤ now).
- INV-2 No order affects a unit before its arrival time.
- INV-3 Men, ammo, and morale stay in valid ranges; men never increase except by scenario reinforcements.
- INV-4 Replay determinism at every 60-minute checkpoint.
- INV-5 Pausing and changing speed do not change outcomes for identical timed actions.

## 5. Data Schemas and Content Tables

```swift
struct Order: Codable, Hashable { let id: Int; let to: OfficerID; let kind: OrderKind; let courier: Courier; let sentAt: GameTime }
struct Report: Codable, Hashable { let id: Int; let from: OfficerID; let sentAt: GameTime; let arrivesAt: GameTime; let observations: [Observation]; let text: DispatchText }
struct Observation: Codable, Hashable { let subject: UnitRef; let hex: Hex; let strengthEstimate: Int; let posture: Posture; let confidence: Int }
struct DispatchText: Codable, Hashable { let templateID: String; let slots: [String: String] } // rendered by localization
```

`officers.json`: name pools (fictional), rank, trait ranges, voice ID. `voices.json`: template sets per voice (terse, florid, anxious, laconic, formal), e.g.
```json
{ "voice": "anxious", "templates": { "contact": ["{time}. Enemy in strength at {place}, estimate {strength} battalions. Request instructions urgently."], "breaking": ["{time}. {unit} cannot hold. Withdrawing to {place}."] } }
```
`units.json`: firepower, range, speeds, ammo use per type. `scenarios/*.json`: map seed or hand map, OOBs, objectives, time limit, weather, recon schedule, briefing text.

Content counts — G3: 3 scenarios (1 tutorial, 2 standard), 5 voices with ≥ 12 templates each per report type, 40 officer names per side, 6 unit types. G5: procedural front generator, 6 handmade scenarios, a 5-operation linked campaign, Ironman mode, and a scenario editor (basic, JSON-backed).

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `tickSeconds` | 10 | fixed |
| `runnerLossPerHexUnderFire` | 2% | 0–5% |
| `wireDelayMin/Max` | 5/15 min | |
| `pigeonDelay` | 30 min | 20–45 |
| `wireCutChancePerIntensity` | 1.5% | |
| `breakMorale` / `routMorale` | 25 / 10 | |
| `reportInterval` (by trait) | 20–60 min | |
| `noisePerReliabilityStep` | 8% | 4–12% |
| `entrenchBonus` per level | 20% | |
| `mgFireMultiplier` | 3.0 | |

Targets (AI vs AI Hard, 300 runs per scenario, both sides): side balance 40–60% wins per scenario (excluding intended asymmetry); median scenario completion 60–110 game-minutes per real 30–60 minutes at mixed speed; report-age median at HQ 15–35 minutes.

## 7. AI Approach

- **Fairness rule:** the enemy commander uses the same order, courier, and belief system as the player (its own `BeliefState`). Difficulty never grants truth except on Hard+ (`omniscientDelayMinutes` reduced, explicitly documented).
- **Operational planner:** influence maps (threat, control, and value from objectives) computed from the AI's belief state every 15 game-minutes; selects posture per division (attack, hold, or withdraw) by a utility function with weights in `ai_weights.json`.
- **Tactical executor:** converts postures into orders, schedules preparatory barrages, keeps a reserve ratio by difficulty.
- **Difficulty:** Staff College (slow replanning every 45 min, poor reserve use), Field Command (15 min, standard), General Staff (10 min, combined-arms timing, wire repair priority), plus "Fog Off" practice mode.
- **Determinism:** planner uses state-hash-derived RNG; replans at fixed game times.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.
- DS-P0.1 Hex math (axial coordinates, distance, line of sight with elevation) with tests.
- DS-P0.2 Spike: PencilKit overlay above a SpriteKit map with synchronized pan/zoom. Acceptance: strokes stay registered to map hexes across zoom 0.5×–4×.

```
GATE G0 — Setup: standard checks; annotation spike registered within 1 pt at all zooms · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- DS-P1.1 Map, terrain, forces, and officers (R-1 to R-4).
- DS-P1.2 Orders, couriers, wire network, and arrival (R-5 to R-8).
- DS-P1.3 Movement, combat, morale, and artillery (R-9 to R-11) with fixed-point tests.
- DS-P1.4 Interpretation and initiative (R-12, R-13).
- DS-P1.5 Reports, noise, and belief (R-14 to R-17).
- DS-P1.6 Objectives and scoring (R-18); headless sim of a small 2-division vs 2-division scenario.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-18 tagged tests; INV-1…INV-5 over 300 seeded battles; DSCore coverage ≥ 90%
  [ ] Headless 2-hour battle ≤ 2 s CPU on Mac; checkpoint hashes stable
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- DS-P2.1 Staff map showing belief only: report markers with age shading and timestamps; tap a marker to read the source dispatch.
- DS-P2.2 Order composer: tap an officer card → choose order type → tap/drag on map to set objective or line → choose courier with a projected arrival time → send. Orders in transit appear on a "sent" rail with ETA.
- DS-P2.3 Dispatch board: incoming dispatch stack with unread state; swipe to file.
- DS-P2.4 Finger annotation layer (Pencil polish in P7) with eraser and clear.
- DS-P2.5 One scenario ("The Mill at Vauchelles", fictional): 1 enemy division (Field Command AI simplified) vs the player's 2 divisions.
- DS-P2.6 After-action replay of truth vs belief side by side.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes the slice scenario at 16× with scripted orders on iPad and Mac
  [ ] INV-1 checked live in debug builds (assertion if belief leaks truth)
  [ ] After-action replay reproduces final hash
Sign-off: REVIEW: GROK (is latency interesting, not frustrating?) + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- DS-P3.1 All order types and unit types; supply and ammunition; engineers and wire repair.
- DS-P3.2 Voices (5) and templates; officer roster generation.
- DS-P3.3 Three scenarios including a guided tutorial (8 steps: read a dispatch, send an order, choose a courier, barrage, reserve, wire cut, initiative, victory).
- DS-P3.4 Officer dossier screen (traits revealed gradually through play: hidden until observed behavior, a pillar-supporting choice recorded as an ADR).

```
GATE G3 — Content and Systems: G3 counts; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- DS-P4.1 Influence maps, operational planner, tactical executor, and three difficulties.
- DS-P4.2 `Tools/sim --ai hard:hard` per scenario; balance report.

```
GATE G4 — AI
Checks:
  [ ] 300 AI-vs-AI battles per scenario: 0 crashes, 0 illegal orders, INV-1 holds for AI belief
  [ ] General Staff beats Staff College ≥ 75% as attacker and defender
  [ ] Planner step p95 ≤ 50 ms on Mac
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- DS-P5.1 Procedural front generator (terrain, objectives, OOBs, officer rosters) with constraints validated by sims.
- DS-P5.2 Six handmade scenarios; a five-operation campaign with carried-over casualties and officer fates.
- DS-P5.3 Ironman (autosave only, no reload) and scenario editor (JSON-backed, in-app basic placement).
- DS-P5.4 Stats and 25 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] 200 generated fronts each pass a 2-sided AI sim with balance 30–70%
  [ ] Campaign completes in an accelerated UI test
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- DS-P6.1 Final staff-map rendering (contours, hatching, hand-lettered labels), typewriter dispatch slips, and carbon textures.
- DS-P6.2 Score and battlefield ambience tied to reported intensity (not truth).

```
GATE G6 — Aesthetics: snapshots approved; ambience uses belief-only intensity (test) · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- DS-P7.1 Pencil annotations with pressure, hover preview of order paths, squeeze for the order palette; double-tap toggles eraser.
- DS-P7.2 Multi-window: dispatch board in a separate window on Mac and iPad Stage Manager.
- DS-P7.3 Game Center achievements and leaderboards (campaign score, Ironman wins); iCloud saves including annotation drawings.
- DS-P7.4 Mac menus and extensive keyboard shortcuts (N new order, space pause, 1–4 speeds, Tab cycles dispatches).

```
GATE G7 — Platform: annotations sync via iCloud iPad ↔ Mac; multi-window works · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- DS-P8.1 VoiceOver reading of dispatches and order composer; Dynamic Type for dispatch text.
- DS-P8.2 Friendly/enemy distinguished by symbol shape and hatching as well as color.
- DS-P8.3 Perf at 16× with 120 battalions.

```
GATE G8 — Polish: 60 fps at 16× on iPad (A16), 120 fps on iPad Pro idle pan; cold start < 2.0 s · Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks; DS-P9.1 recruit wargame-experienced testers (Mahler approves any external group).

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: truth/belief separation (INV-1), wire-network graph updates, and interpretation formulas.
- First pickups: GROK — officer voice writing and scenario design; CLAUDE — multi-window architecture and PencilKit sync.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Latency feels like lag, not strategy | Medium | High | Clear ETAs, anticipatory tools (timed orders), and tutorial framing | GROK |
| Historical sensitivity | Low | Medium | Fictional sectors and officers; respectful tone | MAHLER |
| Sim complexity breaks determinism | Medium | High | Fixed-point, checkpoint hash tests | GLM |
| Niche audience size | High | Medium | Premium price, Mac emphasis, wargame community outreach | MAHLER |

## 11. Out of Scope

Multiplayer; tactical-level control of battalions; aircraft combat; 3D terrain; other wars or eras in v1.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3–4 |
| P1 | GLM | 14–20 |
| P2 | GLM | 12–16 |
| P3 | GLM | 12–16 |
| P4 | GLM | 12–18 |
| P5 | GLM | 14–20 |
| P6 | GROK + CLAUDE | 12–18 |
| P7 | CLAUDE | 8–12 |
| P8 | CLAUDE | 6–9 |
| P9 | GROK + CLAUDE | 12–18 |
| P10 | CLAUDE + GROK | 3–5 |
| **Total** | | **108–156** |

## 13. Open Questions for Mahler

1. Fictional or real place names? Default: fictional, historically plausible.
2. Should players also command at brigade level? Default: no; division orders only.
