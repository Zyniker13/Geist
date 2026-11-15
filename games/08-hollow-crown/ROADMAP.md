# 08 — Hollow Crown Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 08 · `hollow-crown` |
| Code prefix | `HC` (packages `HCCore`, `HCContent`, `HCAI`, `HCRender`, `HCAudio`, `HCPlatform`, `HCMeta`) |
| Bundle ID (placeholder) | `com.zyniker.hollow-crown` |
| Subgenre | Dynastic card-driven strategy |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 45–60 minutes |
| Renderer | SpriteKit (2D manuscript page, cards, and family tree) |
| Players | Solo vs AI houses |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** Play one dynasty across seven generations in under an hour, where heirs inherit your mistakes along with your lands.
- **Summary:** Each generation is one ruler's reign, played as a few seasons of card play. You arrange marriages, educate heirs, wage wars, build works, and manage a scheming council while three rival houses pursue their own ambitions. At each death, traits, debts, feuds, and lands pass to the heir under your succession law. After seven generations, your dynasty's Legacy is scored against three secret goals drawn at the start.
- **Pillars:**
  1. **Long shadows.** Choices echo across generations; the game makes those echoes visible.
  2. **A family, not a nation.** Every card touches people with names, traits, and relationships.
  3. **An hour for a dynasty.** Seven generations always fit in one sitting.
  4. **Illuminated clarity.** The manuscript look never hides numbers the player needs.
- **Aesthetic spec:**
  - Palette: parchment `#F2E6CC`, lapis `#26619C`, vermilion `#D14B2E`, verdigris `#4E8C74`, gold leaf `#C8A240`, iron-gall ink `#2B211A`, mourning violet `#5B3C6E`.
  - Visuals: an illuminated manuscript spread; the family tree grows as marginalia vines with portraits in roundels; cards as manuscript leaves with historiated initials; generations turn like pages.
  - Audio: plainchant, lute, and recorder; quill writing for chronicle entries; a tolling bell at each death.
  - Haptics: a page-turn ripple between generations; a firm press when a card is sealed.
- **Inspirations:** Six Ages on iPad, Through the Ages' civilization-in-cards, and Against the Storm's rule of ending runs before stability turns to boredom.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Renderer:** SpriteKit `ChronicleScene` (page, cards, and realm map) and a SwiftUI overlay for dense text panels (council, character sheets) for accessibility and Dynamic Type.
- **Turn-based** with deterministic event draws; names generated from seeded syllable tables.
- ADRs: ADR-0003 (SwiftUI panels over SpriteKit page), ADR-0004 (character model and genetics as integer trait inheritance), ADR-0005 (fixed 7 generations).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/HCCore/Sources/HCCore/
  People/ Person.swift, Traits.swift, Skills.swift, Genetics.swift, Education.swift, Health.swift, Relations.swift, Names.swift
  Realm/ House.swift, Province.swift, Holdings.swift, Treasury.swift, Council.swift, SuccessionLaw.swift
  Cards/ Card.swift, Deck.swift, Effects.swift, Conditions.swift
  Turn/ Season.swift, Reign.swift, Events.swift, Wars.swift, Intrigue.swift, Marriage.swift, Death.swift, Succession.swift
  Legacy/ LegacyGoal.swift, Scoring.swift, Chronicle.swift
  Reducer.swift, Replay.swift
Packages/HCContent/Sources/HCContent/ CardCatalog.swift, EventCatalog.swift, TraitCatalog.swift, HouseCatalog.swift, LegacyCatalog.swift, NameTables.swift, Validation.swift
Packages/HCAI/Sources/HCAI/ RivalHouseAI.swift, CouncilAI.swift, Utility.swift, Difficulty.swift, Autoplayer.swift
Packages/HCRender/Sources/HCRender/ ChronicleScene.swift, FamilyTreeNode.swift, CardHand.swift, RealmMap.swift, PageTurn.swift, Panels/ (SwiftUI: CharacterSheet, CouncilView, ChronicleLog)
Packages/HCAudio/Sources/HCAudio/ Music.swift, SFX.swift
Packages/HCMeta/Sources/HCMeta/ Dynasties.swift (gallery), Unlocks.swift, Achievements.swift
Resources/Content/ cards.json, events.json, traits.json, houses.json, legacy.json, names/*.json, balance.json, tutorial.json
```

## 4. Core Rules Specification

**Setup**
- R-1 The realm has 12 provinces split among the player's house and 3 rival houses (by `houses.json` setup); each house has a ruler, spouse, 0–3 children, and a council of 4 seats (Chancellor, Marshal, Steward, and Spymaster).
- R-2 Three Legacy goals are drawn from `legacy.json` (one each from Glory, Faith, and Stewardship pools), shown to the player; rivals have hidden goals.
- R-3 Realm resources per house: Treasury (gold), Prestige, Piety, Levies (military), and Stability (0–100).

**People**
- R-4 Person: age, sex, skills (Martial, Diplomacy, Stewardship, Intrigue, and Learning, 0–20), up to 4 traits, health (0–100), fertility, and opinions (−100 to +100) of other people.
- R-5 Genetics: a child's congenital traits (e.g. Strong, Clever, Sickly, Comely) inherit with probabilities in `traits.json` from parents; skills start at `(parentAvg / 4) + seeded 0–3`.
- R-6 Education: each child under 16 has a tutor assignment (a council member or hired tutor); each season, the child's focus skill grows by `tutorSkill / 5` (min 1) and may gain a personality trait from the tutor (probability by tutor traits).
- R-7 Health and death: each season, each person rolls death chance from age, health, traits, and events; a ruler's death ends the reign.

**Reign and Seasons**
- R-8 A reign lasts until the ruler dies or abdicates, with a minimum of 2 and a maximum of 8 seasons (a ruler reaching season 8 abdicates to the heir, with a Prestige bonus); the expected reign length is tuned so 7 generations take 45–60 minutes.
- R-9 Each season: (1) Income, (2) Draw to 5 cards, (3) an Event (drawn from the event deck filtered by conditions), (4) the player plays up to `actions = 2 + floor(rulerStewardship / 10)` cards, (5) rivals act (AI), (6) Wars, intrigue, and opinions resolve, (7) Aging, health, and births, (8) Death checks.
- R-10 Cards have costs (gold, prestige, piety, or levies), conditions, targets (people, provinces, or houses), and effects. Card types: Marriage, Education, Works (build in a province), War (declare, raise levies, campaign), Intrigue (plot, expose, assassinate), Faith, Court (feasts, appointments), and Law (change succession or taxes).

**Marriage, Wars, and Intrigue**
- R-11 Marriage requires both parties unmarried, of age (16+), and acceptance (AI utility for rivals based on prestige difference, opinion, and alliances); creates an alliance between houses while both spouses live.
- R-12 Wars are fought by campaigns: each season at war compares `levies × (1 + marshal Martial / 20)` with terrain modifiers; war score accumulates; at ±100 war score the winner takes the contested province; Stability falls each war season.
- R-13 Intrigue plots have secrecy and power; each season a plot can be discovered (target Spymaster Intrigue vs plotter); discovered plots create feuds (opinion −50 house-wide, inherited for 2 generations).

**Succession**
- R-14 At the ruler's death, the heir is chosen by succession law: Primogeniture (eldest child), Ultimogeniture, Elective (council votes using opinion), or Designated (ruler chooses; costs prestige).
- R-15 Inheritance: the heir inherits provinces, treasury (including debt, which can be negative), feuds, alliances (only those via living spouses), and the realm's Stability minus a succession penalty (larger if the heir is a minor, less than 16, triggering a regency where the Chancellor plays cards with a −1 action penalty).
- R-16 No eligible heir ends the dynasty (game over: Legacy scored with a heavy penalty).

**Legacy and End**
- R-17 After 7 generations (7 reigns), the game ends. Legacy = sum of goal scores (each goal 0–100 per its formula) + Prestige/10 + provinces × 5 + Chronicle deeds (great works, crusades, renowned scholars) − debts/50.
- R-18 The Chronicle records notable events per generation for the end screen and the dynasty gallery.

**Invariants**
- INV-1 Every living person has exactly one house; children have two parents recorded (or one, if foundling events apply).
- INV-2 Province ownership sums to 12; no province has two owners.
- INV-3 Actions per season never exceed the computed limit.
- INV-4 A game always ends by generation 7 or dynasty extinction (max seasons = 7 × 8).
- INV-5 Replay determinism.

## 5. Data Schemas and Content Tables

```swift
struct Person: Codable, Hashable { let id: Int; var name: NameRef; var house: HouseID; var birthSeason: Int; var sex: Sex; var skills: Skills; var traits: [TraitID]; var health: Int; var spouse: Int?; var parents: [Int]; var children: [Int]; var opinions: [Int: Int]; var tutor: Int?; var alive: Bool }
struct CardDef: Codable { let id: String; let type: CardType; let cost: Cost; let conditions: [Condition]; let target: TargetSpec; let effects: [Effect]; let text: String; let rarity: Rarity }
```

Sample `cards.json` row:
```json
{ "id": "grand_tourney", "type": "court", "cost": { "gold": 60 }, "conditions": [ { "stabilityAtLeast": 30 } ], "target": "none",
  "effects": [ { "prestige": 15 }, { "opinionAllCourt": 10 }, { "chance": 10, "effect": { "injureRandomKnight": true } } ],
  "text": "Hold a grand tourney. Nobles flock to your court.", "rarity": "uncommon" }
```

Content counts — G3: 90 cards, 50 events, 30 traits, 4 starting scenarios (one per house layout), 15 Legacy goals, name tables for 2 cultures. G5: 150 cards, 100 events, 40 traits, 12 starting houses across 3 cultures, 30 Legacy goals, dynasty gallery, and 3 difficulty levels.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `baseActions` | 2 | 2–3 |
| `seasonDeathBaseByAge` | table | |
| `reignMinMax` | 2/8 | |
| `successionPenaltyMinor` | 20 | 10–30 |
| `warScoreToWin` | 100 | 60–150 |
| `plotDiscoveryBase` | 15% | 5–30% |
| `feudGenerations` | 2 | 1–3 |
| `educationGrowthDivisor` | 5 | 3–8 |

Targets (Autoplayer vs Normal rivals, 2,000 games): median total seasons 26–34 (≈ 45–60 minutes at 100 seconds per season for humans); dynasty extinction ≤ 8% of games; average Legacy goal completion 45–65%; no card played in > 40% of opportunities by the Autoplayer.

## 7. AI Approach

- **Rival houses:** utility AI choosing among card plays and diplomacy with weights from personality (Ambitious, Pious, Cunning, Martial, and Mercantile) and hidden Legacy goals; evaluates one season ahead by simulating its own card effects.
- **Council AI:** council members with low opinion of the ruler may refuse appointments or start plots; implemented as event conditions plus a small utility model.
- **Autoplayer (balance proxy):** greedy one-season lookahead toward the player's Legacy goals; used only in sims.
- **Difficulty:** Gentle (rivals aggressive only when provoked), Normal, and Merciless (rivals coordinate against the leader, plots more frequent).
- **Budget:** all rivals' season ≤ 300 ms on iPad (A16).

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)
- Standard tasks S0.1–S0.7.

```
GATE G0 — Setup: standard checks · Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)
- Standard tasks S1.1–S1.4.
- HC-P1.1 People, genetics, education, and health (R-4 to R-7).
- HC-P1.2 Reign and season structure, cards, and effects interpreter (R-8 to R-10).
- HC-P1.3 Marriage, wars, and intrigue (R-11 to R-13).
- HC-P1.4 Succession and inheritance including regencies (R-14 to R-16).
- HC-P1.5 Legacy scoring and chronicle (R-17, R-18).

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-18 tagged tests; INV-1…INV-5 over 2,000 random-play games; HCCore coverage ≥ 90%
  [ ] Headless full game ≤ 200 ms CPU on Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)
- Standard tasks S2.1–S2.5.
- HC-P2.1 Manuscript page layout: family tree (marginalia), realm map (12 provinces), hand of cards, and resource bar.
- HC-P2.2 Drag a card onto a person, province, or house to target it; invalid targets dim during drag; an effect preview shows expected changes before release.
- HC-P2.3 Season flow with event card presentation and choices.
- HC-P2.4 Death and succession sequence with page turn.
- HC-P2.5 One scenario, 40 cards, 25 events, simple rivals, and full 7-generation play.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test completes 7 generations with scripted plays on iPad and Mac
  [ ] Effect previews equal actual effects for deterministic cards (test over all cards)
  [ ] Save/resume identical hash
Sign-off: REVIEW: GROK (do generations feel connected?) + REVIEW: MAHLER
🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)
- HC-P3.1 G3 card, event, trait, and goal counts; content-lint checks every effect key and condition.
- HC-P3.2 Council panel, character sheets, and opinion web (SwiftUI panels).
- HC-P3.3 Wars UI (campaign tracker), intrigue UI (plots with secrecy meters).
- HC-P3.4 Tutorial: an abridged 2-generation guided game (10 steps).

```
GATE G3 — Content and Systems: counts; content-lint 0 errors; tutorial UI test · Sign-off: GLM-SELF; REVIEW: CLAUDE async
```

### P4 AI Opponents (Owner: GLM)
- HC-P4.1 Rival house AI and council AI with personalities and difficulties.
- HC-P4.2 Autoplayer and balance report.

```
GATE G4 — AI
Checks:
  [ ] 2,000 games: 0 illegal plays; rivals' season p95 ≤ 300 ms (Mac measured)
  [ ] Merciless reduces Autoplayer Legacy by ≥ 20% vs Gentle
  [ ] Targets in §6 met or tuning ADR
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)
- HC-P5.1 12 starting houses, 3 cultures with name tables, G5 content counts.
- HC-P5.2 Dynasty gallery: each finished game saved as an illuminated family tree with the Chronicle.
- HC-P5.3 Unlocks (houses and Legacy pools unlock by achievements) and 25 achievements.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] G5 counts pass content-lint and sims
  [ ] Gallery renders 50 saved dynasties without memory > 400 MB
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: REVIEW: CLAUDE + GROK + MAHLER
🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)
- HC-P6.1 Illumination art: borders, historiated initials, roundel portraits (procedural portrait composer from layered parts by traits).
- HC-P6.2 Music and SFX.

```
GATE G6 — Aesthetics: snapshots approved; portraits reflect traits (test) · Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)
- HC-P7.1 Pencil: inscribe heir names by handwriting (Scribble into the name field) and annotate the chronicle margins; hover to preview card effects.
- HC-P7.2 Game Center achievements and a "highest Legacy" leaderboard per house; iCloud saves.
- HC-P7.3 Mac menus and shortcuts; resizable window with a two-page spread at wide sizes.

```
GATE G7 — Platform: iCloud round-trip; Scribble works in name fields · Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)
- HC-P8.1 VoiceOver for cards, tree navigation by relationship, and panels; Dynamic Type for all text panels.
- HC-P8.2 Card text legibility on iPhone (minimum 13 pt equivalent).

```
GATE G8 — Polish: perf budgets; VoiceOver completes a generation · Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard tasks.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: REVIEW: MAHLER
GATE G10 — Release: assets approved · Sign-off: REVIEW: MAHLER (Mahler submits)
```

## 9. Handoff to Grok and Claude

- Fragile areas: effects interpreter, succession edge cases (no heirs, regencies), and opinion propagation.
- First pickups: GROK — card and event writing, Legacy goals, and house flavor; CLAUDE — panel architecture and portrait composer.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Feels like a lite Crusader Kings | Medium | Medium | Fixed 7 generations, card play, and Legacy goals as distinct identity | GROK |
| Text-heavy UI on iPhone | High | Medium | iPad-first; iPhone gets condensed card faces | CLAUDE |
| Run length drifts beyond an hour | Medium | Medium | Sim-tuned death and reign limits | GLM |

## 11. Out of Scope

Real-time play; multiplayer; detailed tactical battles; open-ended sandbox beyond 7 generations; romance subplots.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 2 |
| P1 | GLM | 10–14 |
| P2 | GLM | 10–14 |
| P3 | GLM | 14–20 |
| P4 | GLM | 8–12 |
| P5 | GLM | 10–14 |
| P6 | GROK + CLAUDE | 15–22 |
| P7 | CLAUDE | 5–8 |
| P8 | CLAUDE | 6–9 |
| P9 | GROK + CLAUDE | 8–12 |
| P10 | CLAUDE + GROK | 3–4 |
| **Total** | | **91–131** |

## 13. Open Questions for Mahler

1. Setting: generic medieval Europe, or a fictional realm? Default: fictional realm with European flavor plus two other cultures in G5.
2. Should faith systems reference real religions? Default: no; fictional faiths.
