# 10 — Signal & Noise Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 10 · `signal-and-noise` |
| Code prefix | `SN` (packages `SNCore`, `SNContent`, `SNAI`, `SNRender`, `SNAudio`, `SNPlatform`, `SNMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Asymmetric hidden-movement duel |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 20–40 minutes |
| Renderer | SpriteKit (2D screen-print city map) |
| Players | Solo vs AI (either side); local two-device play (iPad board plus iPhone private hand via MultipeerConnectivity); pass-and-play; async online via GameKit turn-based |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** A hidden-movement spy duel in a 1960s city, played with one person on the iPad and one on an iPhone, or against a cunning AI.
- **Summary:** The Network moves three hidden agents across a city graph to complete dead drops. Counterintelligence moves visible watchers, places wiretaps and roadblocks, and tails suspects, deducing where the agents might be from forced reveals and traces. The Network wins with five completed drops; Counterintelligence wins by arresting two agents or running out the clock.
- **Pillars:**
  1. **Asymmetric, equal depth.** Both sides must be equally interesting to play.
  2. **Deduction you can see.** Counterintelligence always has a clear view of possible agent locations (with an optional assist).
  3. **Private information stays private.** Device separation or hand-off screens guarantee secrecy.
  4. **Graphic cool.** Swiss modernist screen-print style; every element is a clean shape.
- **Aesthetic spec:**
  - Palette (two-color print plus paper): paper `#F1EDE4`, signal orange `#E8622C`, noise teal `#1F7A7A`, overprint dark `#2B2A29`, halftone gray `#9A968E`.
  - Visuals: city as a graph of avenues on a grid with district blocks in halftone; agents as orange dots (only on the Network's view), watchers as teal squares; reveals as stamped circles with turn numbers.
  - Typography: grotesque sans (open-license, chosen in P6), large numerals.
  - Audio: cool jazz trio stems (brushes, upright bass, vibraphone), reel-to-reel hiss, phone rings for wiretap hits, typewriter for case notes.
  - Haptics: a subtle buzz on the private device when an agent is near a watcher.
- **Inspirations:** Root's well-digitized asymmetric factions, Twilight Struggle's iPad interface, and classic hidden-movement board games.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Information model:** a single `GameState` (truth) plus derived per-side `View`s; Render receives only a `View`, never `GameState`, to make leaks impossible by construction.
- **Two-device local play:** MultipeerConnectivity session; the iPad is the authoritative host for public state, while hidden Network moves are committed from the iPhone as hashed commitments and revealed only to the host's Core when required (P7). In P2–P5, pass-and-play with hand-off screens.
- **Deduction:** exact possible-location sets per agent (bitsets over ≤ 128 nodes) maintained by Core for the Counterintelligence view.
- ADRs: ADR-0003 (truth vs per-side views), ADR-0004 (bitset deduction), ADR-0005 (MultipeerConnectivity for local two-device play).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/SNCore/Sources/SNCore/
  City/ Node.swift, Edge.swift (street, metro, tram), District.swift, CityGraph.swift, Bitset128.swift
  Pieces/ Agent.swift, Watcher.swift, Tools.swift (network: disguise, safehouse, decoy, dead letter; CI: wiretap, roadblock, sweep, informant)
  Turn/ TurnStructure.swift, Movement.swift, Drops.swift, Reveals.swift, Traces.swift, Arrests.swift, Victory.swift
  Views/ NetworkView.swift, CounterIntelView.swift, PublicView.swift, Deduction.swift
  Reducer.swift, Commitment.swift (hash commitments), Replay.swift
Packages/SNContent/Sources/SNContent/ CityCatalog.swift, MissionDeck.swift, RoleCatalog.swift, CityGenerator.swift, Validation.swift
Packages/SNAI/Sources/SNAI/ CounterIntelAI.swift (deduction + coverage planning), NetworkAI.swift (ISMCTS), Difficulty.swift
Packages/SNRender/Sources/SNRender/ CityScene.swift, PieceNodes.swift, PossibilityHeat.swift, CaseBoard.swift, HandoffScreen.swift
Packages/SNAudio/Sources/SNAudio/ JazzStems.swift, SFX.swift
Packages/SNPlatform/Sources/SNPlatform/ PeerSession.swift (MultipeerConnectivity), TurnBasedService.swift, GameCenterService.swift, CloudSave.swift
Packages/SNMeta/Sources/SNMeta/ Ranks.swift, Stats.swift, Achievements.swift
Resources/Content/ cities/*.json, missions.json, roles.json, tools.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**City and Setup**
- R-1 A city is a graph of 80–128 nodes in 6–9 districts; edges are street (default), metro (connects distant stations; usable by agents only with a metro token), and tram (one-way loops).
- R-2 Nine drop sites are marked; the Network's mission deck selects which five are active (hidden from CI until a drop completes there or a sweep reveals it).
- R-3 Network starts with 3 agents secretly placed on any of 6 start nodes (one per district edge); CI starts with 4 watchers on public nodes at the city center and 3 wiretaps, 2 roadblocks, 2 sweeps, and 1 informant.
- R-4 The game lasts 24 rounds. Each round: Network moves (all agents), then CI acts.

**Network Turn**
- R-5 Each agent moves 1 street edge, or 2 edges with a "hurry" (which leaves a trace on the intermediate node), or rides metro (costs a metro token; leaves a trace at both stations), or stays.
- R-6 Drop: an agent that starts and ends its move on an active drop site completes the drop at the end of the Network turn; the drop is public (site revealed, agent not revealed unless a watcher is adjacent).
- R-7 Tools (each single-use unless stated): Disguise (agent ignores the next arrest attempt), Safehouse (designate a node; agents there are removed from possibility sets for 2 rounds unless wiretapped), Decoy (create a false trace at any node within 3), and Dead Letter (complete a drop from an adjacent node).
- R-8 Reveal rounds: on rounds 3, 8, 13, and 18, all agents' true nodes are revealed publicly at the end of the Network turn.

**Counterintelligence Turn**
- R-9 Each watcher moves up to 2 street edges (watchers cannot use metro unless at a station with the informant's tip that round).
- R-10 Arrest: a watcher that moves onto an agent's node arrests it (unless Disguised); arrested agents are removed.
- R-11 Detection: an agent adjacent to a watcher at the end of the CI turn generates a "sighting" (the node is public, the agent identity is not).
- R-12 Wiretap: placed on a district; any agent action in that district that uses a tool, metro, or hurry produces a public "trace" at the exact node.
- R-13 Roadblock: placed on an edge for 3 rounds; agents cannot traverse it.
- R-14 Sweep: target a district; reveals whether any agent is in it (yes/no) and which drop sites in it are active.
- R-15 Informant: once per game, reveals the district of one random agent.

**Deduction and Victory**
- R-16 CI's possibility set per agent is the set of nodes consistent with all public information (moves allowed, reveals, sightings, traces, sweeps, and roadblocks); Core maintains it exactly; the UI can show it (assist on) or let players deduce (assist off).
- R-17 Network wins on the fifth completed drop. CI wins on the second arrest, or at the end of round 24 if the Network has fewer than five drops.
- R-18 If all three agents are arrested before 5 drops, CI wins immediately (covered by R-17).

**Invariants**
- INV-1 `CounterIntelView` never contains true agent positions except at reveals and arrests (property test: views are functions of public events only).
- INV-2 Every true agent position is contained in CI's possibility set for that agent (deduction soundness).
- INV-3 No agent occupies a node with a watcher after the CI turn (it would be arrested).
- INV-4 Tool counts never negative.
- INV-5 Replay determinism.

## 5. Data Schemas and Content Tables

```swift
struct CityDef: Codable { let id: String; let nodes: [NodeDef]; let edges: [EdgeDef]; let districts: [DistrictDef]; let dropSites: [Int]; let networkStarts: [Int]; let watcherStarts: [Int] }
enum NetworkAction: Codable { case move(agent: Int, path: [Int]), metro(agent: Int, to: Int), useTool(ToolID, args: ToolArgs), endTurn }
enum CIAction: Codable { case moveWatcher(Int, path: [Int]), wiretap(district: Int), roadblock(edge: Int), sweep(district: Int), informant, endTurn }
struct Commitment: Codable { let round: Int; let digest: String } // SHA-256 of serialized hidden actions + salt (CryptoKit used in SNPlatform only; Core receives the digest as data)
```

Content counts — G3: 2 cities (Vienna-inspired "Danube City" and Lisbon-inspired "Tagus City", fictionalized), 12 mission cards, 8 tools, tutorial for each side (6 steps each). G5: 5 cities (adds procedural generator), 24 mission cards, agent roles (Courier: moves 2 without trace once per game; Sleeper: starts hidden from first reveal; Forger: extra decoy) and watcher roles (Hound: moves 3; Analyst: extra sweep; Liaison: metro access), ranked AI ladder.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `rounds` | 24 | 18–30 |
| `revealRounds` | 3, 8, 13, 18 | |
| `dropsToWin` | 5 | 4–6 |
| `arrestsToWin` | 2 | 2–3 |
| `watcherMove` | 2 | 1–3 |
| `wiretaps/roadblocks/sweeps` | 3/2/2 | |

Targets (AI vs AI Hard, 2,000 games per city): Network win rate 45–55%; median game ends round 18–24; ≥ 70% of Network wins use at least one tool; average CI possibility-set size at reveal rounds 6–20 nodes per agent.

## 7. AI Approach

- **Counterintelligence AI:** uses exact possibility sets (R-16); assigns watchers to maximize expected coverage of high-probability nodes and active-drop candidates (probabilities by uniform-over-paths counting with dynamic programming); places wiretaps in districts with the most probable traffic; Hard simulates likely Network intentions toward drop sites.
- **Network AI:** Information Set Monte Carlo Tree Search over agent move bundles with determinized CI responses (CI modeled by the Medium CI policy); heuristic rollouts favor drops away from watcher coverage; tool use by value thresholds.
- **Difficulty:** Rookie, Operative, and Spymaster (more iterations, better models, and tool timing).
- **Budget:** p95 ≤ 1.5 s per turn on iPad (A16); deterministic for a fixed iteration count.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- SN-P0.1 `Bitset128` with tests.

```
GATE G0 — Setup: standard checks · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- SN-P1.1 City graph, setup, and missions (R-1 to R-4).
- SN-P1.2 Network movement, drops, and tools (R-5 to R-8).
- SN-P1.3 CI actions (R-9 to R-15).
- SN-P1.4 Views and exact deduction (R-16, INV-1, INV-2) with ≥ 50 crafted deduction tests.
- SN-P1.5 Victory (R-17, R-18).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-18 tagged tests; INV-1…INV-5 over 5,000 random games; SNCore coverage ≥ 90%
  [ ] Deduction update ≤ 1 ms per event on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- SN-P2.1 City map; drag a piece along streets to move (path snaps to graph edges); tap tools from a tray.
- SN-P2.2 Possibility heat overlay for CI (assist on), case board panel with the event history.
- SN-P2.3 Hand-off screen for pass-and-play (blank screen with "Pass to Network/CI" and tap-to-continue).
- SN-P2.4 Play as CI vs Rookie Network AI on Danube City; play as Network vs Rookie CI.
- SN-P2.5 Mac: click and drag, keyboard 1–4 to select pieces.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes a game as each side on iPad and Mac
  [ ] Render receives only View types (compile-time: SNRender has no access to GameState; test via module boundaries)
  [ ] Save/resume identical hash
Sign-off: GLM-SELF
```

### P3 Content and Systems
- SN-P3.1 All tools, roadblocks, and informant; second city.
- SN-P3.2 Tutorials for both sides (6 steps each).
- SN-P3.3 Assist toggle (off: CI marks suspicions manually on the case board).

```
GATE G3 — Content and Systems: counts; content-lint 0 errors; both tutorials pass UI tests · Sign-off: GLM-SELF
```

### P4 AI Opponents
- SN-P4.1 CI AI and Network ISMCTS with three difficulties; balance report.

```
GATE G4 — AI
Checks:
  [ ] 2,000 AI-vs-AI games per city: 0 illegal actions; INV-1 holds for AI inputs (AI receives only its View)
  [ ] Spymaster beats Rookie ≥ 75% on both sides
  [ ] Network win rate 45–55% at Hard vs Hard or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- SN-P5.1 City generator (validated for connectivity, district balance, and drop-site spacing); 5 cities.
- SN-P5.2 Roles for agents and watchers; 24 mission cards.
- SN-P5.3 AI ladder (10 opponents per side), stats, and 24 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] 300 generated cities each pass AI balance within 35–65%
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- SN-P6.1 Screen-print rendering with misregistration offset, halftone districts, and stamped reveals.
- SN-P6.2 Jazz stems layered by tension (CI possibility size, drops completed).

```
GATE G6 — Aesthetics: snapshots approved · Sign-off: GLM-SELF
```

### P7 Platform Features
- SN-P7.1 Two-device local play: iPad board plus iPhone Network hand using MultipeerConnectivity, with commitment/reveal so the host never displays hidden info; reconnection handling.
- SN-P7.2 GameKit turn-based async with commitments (hidden moves encrypted to the mover; the opponent's device receives only public events and digests; at reveal rounds the mover's device publishes the reveal payload, verified against digests).
- SN-P7.3 Pencil: mark suspicions on the case board and map; hover highlights reachable nodes.
- SN-P7.4 Game Center achievements and ladder leaderboard; iCloud saves; Mac menus.

```
GATE G7 — Platform
Checks:
  [ ] Two-device game completes with Wi-Fi interruption and reconnection
  [ ] Async game between sandbox accounts; tamper test (altered reveal) is rejected
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- SN-P8.1 Watchers and agents distinguished by shape; reveals and traces by stamp shape.
- SN-P8.2 VoiceOver navigation by district and node with possibility counts.

```
GATE G8 — Polish: perf budgets; VoiceOver plays a CI game · Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: GLM-SELF
GATE G10 — Release: assets approved · Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- Fragile areas: view separation (INV-1), deduction soundness (INV-2), and commitment protocol.
- Priorities for P6–P10: side balance and tool design; two-device networking and async protocol.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Hidden info leaks in async | Medium | High | Commitments; views by construction; tamper tests | GLM |
| One side boring | Medium | High | Equal-depth tools; sims plus playtests per side | GLM |
| Deduction assist removes challenge | Medium | Medium | Assist toggle and ranked mode with assist off | GLM |

## 11. Out of Scope

More than 2 players; voice chat; real cities' exact maps; narrative campaign.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 8–12 |
| P2 | GLM | 8–12 |
| P3 | GLM | 6–9 |
| P4 | GLM | 10–14 |
| P5 | GLM | 8–12 |
| P6 | GLM | 8–12 |
| P7 | GLM | 10–15 |
| P8 | GLM | 4–6 |
| P9 | GLM | 8–12 |
| P10 | GLM | 2–4 |
| **Total** | | **74–110** |

## 13. Open Questions

1. Era-specific (1960s Cold War) or timeless? Default: 1960s with fictional agencies.
2. Is two-device local play a v1 must-have? Default: yes; it is the signature feature.
