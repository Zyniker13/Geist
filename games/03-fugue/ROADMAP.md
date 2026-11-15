# 03 — Fugue Roadmap

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 03 · `fugue` |
| Code prefix | `FG` (packages `FGCore`, `FGContent`, `FGAI`, `FGRender`, `FGAudio`, `FGPlatform`, `FGMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Roguelite deckbuilder |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 30–60 minute runs; 3–5 minute encounters |
| Renderer | SpriteKit (2D score and cards) |
| Players | Solo |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** A roguelite deckbuilder where your cards are musical voices, and battles are won by writing counterpoint that actually sounds good.
- **Summary:** Each encounter is a sequence of measures with four voice lanes (Soprano, Alto, Tenor, and Bass). You play phrase cards into lanes; consonant intervals build Harmony (damage), dissonance builds Tension, and Tension that resolves correctly multiplies Harmony. Enemies are Themes that invade lanes and must be answered. Between encounters you traverse a branching map of three Movements, drafting phrases, gaining Marginalia (relics), and modulating keys. Every run produces a piece of music you can export.
- **Pillars:**
  1. **The rules are music theory, simplified honestly.** If the game rewards it, it should sound good; if it sounds bad, it should cost you.
  2. **Every run is a composition.** The soundtrack is the player's play, rendered live.
  3. **Escalation through synergy.** Decks transform across a run like Slay the Spire's engines.
  4. **No theory knowledge required.** Visual interval colors and previews teach theory by doing.
- **Aesthetic spec:**
  - Palette: paper `#F4EEDF`, engraving ink `#1E1B18`, gold leaf `#C9A43A`, consonance blue `#3E6FB0`, tension crimson `#B23A3A`, resolved gold `#E0B84A`, staff gray `#8A857C`.
  - Visuals: engraved five-line staves per lane; cards look like manuscript fragments with a small notation incipit; gold-leaf ornaments bloom on resolutions.
  - Typography: an engraved-style serif (open-license, chosen in P6) for titles; tabular figures for numbers.
  - Audio: sampled string quartet (CC0/permissive library, e.g. VSCO 2 Community Edition; license recorded in an ADR) rendered via `AVAudioUnitSampler`; room reverb; the measure being resolved plays in real time.
  - Haptics: a soft tap per beat during resolution, a swell on resolved dissonance.
- **Inspirations:** Balatro's score-chasing calibration, Slay the Spire's escalation and readable enemy intents, and Against the Storm's run-as-avatar thinking.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, plus:
- **Music engine:** `FGCore` produces a symbolic score (`[NoteEvent]` with integer pitch and beat). `FGAudio` schedules notes with `AVAudioUnitSampler` per voice at sample-accurate times; export uses AVAudioEngine offline manual rendering to `.m4a` and writes Standard MIDI Files (`.mid`) directly from the symbolic score.
- **Pitch model:** integer MIDI pitch; keys and modes as interval tables. Rules never touch audio.
- ADRs: ADR-0003 (symbolic score in Core, audio only in FGAudio), ADR-0004 (sample library and license), ADR-0005 (8 beats per measure, eighth-note grid).

## 3. Repository Structure (Game-Specific Additions)

```
Packages/FGCore/Sources/FGCore/
  Music/ Pitch.swift, Key.swift, Mode.swift, Interval.swift, Voice.swift (ranges), Phrase.swift, Measure.swift, ScoreBuilder.swift
  Combat/ EncounterState.swift, Theme.swift, Intent.swift, Resolution.swift (beat-by-beat), Harmony.swift, Tension.swift, VoiceLeading.swift (parallels, resolution by step), Answer.swift (inversion, augmentation, retrograde)
  Run/ RunState.swift, MapGraph.swift, Nodes.swift, Deck.swift, Marginalia.swift, Modulation.swift, Ascension.swift
  Reducer.swift, Replay.swift
Packages/FGContent/Sources/FGContent/ PhraseCatalog.swift, ThemeCatalog.swift, MarginaliaCatalog.swift, EventCatalog.swift, ComposerCatalog.swift, Validation.swift (checks every phrase fits its voice range in every mode)
Packages/FGAI/Sources/FGAI/ ThemeScripts.swift (enemy behavior), GreedyAutoplayer.swift, BeamAutoplayer.swift, RunSimulator.swift
Packages/FGRender/Sources/FGRender/ ScoreScene.swift, LaneNode.swift, CardNode.swift, HandNode.swift, IntervalOverlay.swift, MapScene.swift, ShopScene.swift
Packages/FGAudio/Sources/FGAudio/ QuartetSampler.swift, Scheduler.swift, Exporter.swift (m4a + MIDI), Ambience.swift
Packages/FGMeta/Sources/FGMeta/ DailySubject.swift, Unlocks.swift, Compendium.swift, RunHistory.swift
Resources/Content/ phrases.json, themes.json, marginalia.json, events.json, composers.json, map.json, balance.json, ascension.json, tutorial.json
```

## 4. Core Rules Specification

**Music Model**
- R-1 Pitch is a MIDI integer. A key is a tonic pitch class (0–11) plus a mode (Ionian, Dorian, Phrygian, Lydian, Mixolydian, Aeolian, and Harmonic Minor). Phrases store notes as `(scaleDegree: Int, octaveOffset: Int, startBeat: Int, durationBeats: Int)` and are realized into pitches by the current key.
- R-2 Voice ranges (MIDI): Soprano 60–81, Alto 55–74, Tenor 48–69, Bass 40–62. Realized notes outside the range are transposed by octave into range; if impossible, the card is unplayable in that lane.
- R-3 A measure has 8 beats (eighth notes). A note sounds in beats `[start, start + duration)`.

**Encounter Turn (One Measure)**
- R-4 Start of measure: draw to 5 cards; Breath (energy) resets to 3 (+ modifiers).
- R-5 The enemy Theme reveals its intent for this measure (R-14).
- R-6 Play phase: play a card by paying its Breath cost and placing it in a lane at a start beat; it may not overlap notes already in that lane this measure. Lanes occupied by an invading Theme motif cannot receive notes on those beats.
- R-7 End the play phase → Resolution (R-8 to R-12) → enemy action → discard hand (unless Retain) → next measure.

**Resolution (Beat by Beat, Beats 0–7)**
- R-8 For each beat, collect sounding pitches across lanes (including Theme motif notes). For each pair, interval class `ic = |p1 − p2| mod 12`.
- R-9 Consonance scoring per pair: `ic` 0 (unison/octave) = +1 Harmony; 7 (perfect fifth) = +3; 3, 4, 8, and 9 (thirds and sixths) = +2; 5 (fourth) = +2 if neither pitch is the lowest sounding pitch, else counts as dissonant. Dissonant `ic` (1, 2, 6, 10, 11, and the bass fourth) = +1 Tension each.
- R-10 Parallel perfects: if the same pair of voices moves from `ic` 7 to `ic` 7, or from 0 to 0, on consecutive note onsets with both voices moving in the same direction, −3 Harmony (shown as a red bracket).
- R-11 Resolution: a dissonant pair at beat `b` is resolved if at the next onset one of its voices moves by step (1 or 2 semitones) and the pair becomes consonant. Each resolved dissonance converts 1 Tension into 1 Resolution point. Unresolved Tension at measure end persists into the next measure (max 10) and deals 1 Composure damage to the player per 3 points at measure end.
- R-12 Damage: `damage = Harmony × (100 + 25 × Resolution) / 100` (integer division), dealt to the Theme's Resolve. Modifiers from cards and Marginalia apply in the order: flat Harmony bonuses → multiplier bonuses → final multipliers.

**Themes (Enemies)**
- R-13 A Theme has Resolve (HP), a motif (a short phrase), an intent script, and keywords.
- R-14 Intent types: `invade(lane, motif)` (occupies beats in a lane next measure), `discord(n)` (adds n Tension to the player), `crescendo(n)` (deals n Composure damage at enemy action unless answered), `fortissimo` (doubles next crescendo), `canon` (copies the player's highest-Harmony phrase into an enemy lane next measure).
- R-15 Answering: a played phrase that is the Theme motif's inversion, augmentation, or retrograde (cards carry `answer` tags that are realized against the current motif) cancels that measure's `crescendo` and deals bonus Harmony equal to the motif length.
- R-16 The player loses the run when Composure reaches 0. The encounter is won when Resolve reaches 0.

**Run Structure**
- R-17 A run has 3 Movements; each Movement is a generated DAG map of 15 rows with nodes: Encounter, Elite, Cadence (rest: heal 30% Composure or upgrade a card), Luthier (shop), Patron (event), Modulation (change key/mode with listed trade-offs), and the Movement's Boss at the top.
- R-18 Rewards: after Encounters choose 1 of 3 phrases (or skip); Elites also grant a Marginalia; Bosses grant a rare phrase choice and a Marginalia choice.
- R-19 Composers set the starting deck (10 cards), starting Marginalia, and a unique rule: Baroque (imitation: a phrase that repeats another lane's rhythm at a fifth gains +2 Harmony per note), Romantic (Tension cap 15 and Resolution worth 35% instead of 25%), Minimalist (each repeat of the same card in a measure adds +1 Harmony per note, stacking), and Jazz (ic 10 and 11 count as consonant +1 when the Bass plays scale degree 1 or 5; swing removes parallel penalties on off-beats).
- R-20 Ascension (Tempo markings) 1–10 add cumulative modifiers listed in `ascension.json`.

**Invariants**
- INV-1 Breath never negative; hand size ≤ 10; deck + hand + discard + exhaust counts are conserved within an encounter.
- INV-2 No lane has overlapping notes in a measure.
- INV-3 Every realized pitch lies within its voice range.
- INV-4 Resolution is a pure function of the measure's notes and the carried Tension (tested by recomputation).
- INV-5 Replay determinism for full runs.

## 5. Data Schemas and Content Tables

```swift
struct PhraseCard: Codable, Hashable { let id: String; let cost: Int; let rarity: Rarity; let composer: String?; let notes: [NoteSpec]; let tags: [Tag]; let effects: [Effect]; let upgraded: PhraseUpgrade? }
struct NoteSpec: Codable, Hashable { let degree: Int; let octave: Int; let start: Int; let duration: Int }
enum Effect: Codable { case harmonyFlat(Int), harmonyPerNote(Int), multiplierPct(Int), draw(Int), breath(Int), retain, exhaust, tensionAdd(Int), tensionClear(Int), answer(AnswerKind), transposeLane(Int), heal(Int) }
struct ThemeDef: Codable { let id: String; let tier: Tier; let resolve: Int; let motif: [NoteSpec]; let script: [IntentStep]; let keywords: [String] }
```

Sample `phrases.json` row:
```json
{ "id": "rising_third", "cost": 1, "rarity": "common", "composer": null,
  "notes": [ {"degree": 1, "octave": 0, "start": 0, "duration": 2}, {"degree": 3, "octave": 0, "start": 2, "duration": 2} ],
  "tags": ["stepwise"], "effects": [ {"harmonyPerNote": 1} ], "upgraded": { "effects": [ {"harmonyPerNote": 2} ] } }
```

Content counts — G3: Baroque composer complete, 80 phrases, 20 themes (12 normal, 6 elite, 2 bosses), 15 Marginalia, 10 Patron events, 1 Movement map preset. G5: 4 composers, 200 phrases, 45 themes (30 normal, 12 elite, 3 bosses), 40 Marginalia, 25 events, 3 Movements, 10 ascension levels, 7 modes.

## 6. Balancing Parameters

| Name | Default | Range |
| --- | --- | --- |
| `startComposure` | 70 | 50–90 |
| `breathPerMeasure` | 3 | 3–4 |
| `handSize` | 5 | 4–6 |
| `fifthHarmony` | 3 | 2–4 |
| `thirdSixthHarmony` | 2 | 1–3 |
| `parallelPenalty` | 3 | 2–5 |
| `resolutionPct` | 25 | 15–40 |
| `tensionCap` | 10 | 8–15 |
| `tensionDamageDivisor` | 3 | 2–4 |
| `act1ResolveRange` | 30–60 | |
| `goldPerEncounter` | 15–25 | |

Targets (Beam autoplayer, 2,000 seeded runs per composer, Ascension 0): full-run win 40–55%; Movement 1 survival ≥ 85%; Greedy autoplayer win 8–20%; no common phrase picked > 25% of the time when offered; average encounter 4–7 measures.

## 7. AI Approach

There is no symmetric opponent. P4 builds:
- **Theme scripts:** deterministic intent cycles with seeded branching (e.g. if the player resolved ≥ 2 dissonances last measure, play `canon`). Tested per Theme.
- **Greedy autoplayer:** for each measure, enumerate all card-lane-beat placements up to 3 cards (pruned to top 200 by single-card Harmony), evaluate with full Resolution, pick the max damage minus Composure loss.
- **Beam autoplayer:** beam width 32 over placements, with lookahead of one enemy action; reward pick by a learned-free heuristic (card value table updated by sims in `Tools/sim tune`).
- **Run simulator:** plays full runs headless for balance; outputs pick rates, win rates, and death causes to `docs/BALANCE.md`.
- **Daily subject:** seed `hash("FG-daily-" + yyyyMMdd UTC)` fixes composer, key, map, rewards, and a daily motif shared by all bosses; score = Harmony total × act multiplier.

## 8. Phases, Tasks, and Gates

### P0 Setup
- Standard tasks S0.1–S0.7.
- FG-P0.1 Audio spike: schedule a 4-voice, 8-beat measure via `AVAudioUnitSampler` with a placeholder General MIDI sound bank; measure scheduling jitter. Acceptance: onset jitter < 2 ms (logged).

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks
  [ ] Audio spike plays a measure on iPad simulator and Mac
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype
- Standard tasks S1.1–S1.4.
- FG-P1.1 Music model (R-1 to R-3) with key/mode realization tests for all 7 modes.
- FG-P1.2 Resolution (R-8 to R-12) with ≥ 60 table tests built from textbook examples (correct suspensions, parallel fifths, and bass fourths).
- FG-P1.3 Themes, intents, and answers (R-13 to R-16).
- FG-P1.4 Deck flow (draw, discard, exhaust, and retain).
- FG-P1.5 Run map generation (R-17) with constraints: no Elite in rows 1–4; at least 2 Cadences per Movement; a Luthier in rows 6–10.

```
GATE G1 — Rules Engine
Checks:
  [ ] R-1…R-20 tagged tests pass (R-19/R-20 may be stubs flagged as TODO with tests for Baroque only)
  [ ] INV-1…INV-5 over 2,000 seeds; FGCore coverage ≥ 90%
  [ ] make sim N=1000 random-play runs: 0 crashes; hashes stable
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice
- Standard tasks S2.1–S2.5.
- FG-P2.1 `ScoreScene`: four lanes as staves, beat grid, Theme motif shown in its lane, intent icon above.
- FG-P2.2 Drag a card from the hand into a lane; it snaps to the earliest legal beat under the finger; a live overlay colors each beat's intervals (blue consonant, crimson dissonant, gold when it would resolve) and shows projected damage before you release.
- FG-P2.3 Resolution playback: a cursor sweeps the beats while the quartet plays; Harmony and Tension counters animate.
- FG-P2.4 One Movement with 8 Encounters, 1 Elite, 1 Boss, the Baroque starter deck, 30 phrases, and 8 Themes.
- FG-P2.5 Mac: drag with mouse; number keys 1–4 pick lanes; space resolves.

```
GATE G2 — Vertical Slice
Checks:
  [ ] UI test plays a full Movement to the Boss result on iPad and Mac with scripted placements
  [ ] Projected damage shown before release equals actual resolved damage (test over 500 random placements)
  [ ] Audio plays without dropouts during resolution (no buffer underruns logged)
Sign-off: GLM-SELF
```

### P3 Content and Systems
- FG-P3.1 Author 80 phrases, 20 Themes, 15 Marginalia, and 10 Patron events to G3 counts; content-lint checks ranges and IDs.
- FG-P3.2 Luthier shop (buy, remove card, upgrade), Cadence node, Modulation node.
- FG-P3.3 Full map UI with node icons and path preview.
- FG-P3.4 Tutorial: 7 steps (place, consonance, dissonance, resolve, parallels, answer, map).
- FG-P3.5 Compendium screen of seen cards and Themes, each with a "listen" button.

```
GATE G3 — Content and Systems
Checks:
  [ ] G3 content counts present; content-lint 0 errors
  [ ] Each Effect case has ≥ 2 tests
  [ ] Tutorial UI test passes
Sign-off: GLM-SELF
```

### P4 AI Opponents
- FG-P4.1 Theme scripts for all Themes with branching tests.
- FG-P4.2 Greedy and Beam autoplayers; `Tools/sim runs --bot beam N=2000`.
- FG-P4.3 Balance report and one tuning pass to targets in §6.

```
GATE G4 — AI and Balance Tooling
Checks:
  [ ] Autoplayers never attempt illegal plays in 2,000 runs
  [ ] Beam win rate within 40–55% (Baroque, A0) or tuning ADR
  [ ] Pick-rate report generated
Sign-off: GLM-SELF
```

### P5 Meta and Replayability
- FG-P5.1 Add Romantic, Minimalist, and Jazz composers; reach G5 content counts.
- FG-P5.2 Ascension 1–10; unlock flow (composers unlock by first win or by Movement 2 reaches).
- FG-P5.3 Daily subject mode with local leaderboard.
- FG-P5.4 Run export: MIDI always; m4a via offline rendering; a "score sheet" image of highlights.
- FG-P5.5 Run history and stats; 30 achievements defined.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] All 4 composers pass 2,000-run sims within 35–60% Beam win at A0
  [ ] Exported MIDI re-imports into the test harness and matches the symbolic score note for note
  [ ] Daily seed identical across devices for 30 dates
  [ ] Coverage thresholds; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass
- FG-P6.1 Final engraved staves, card frames, and gold-leaf shader for resolutions.
- FG-P6.2 Final sample library, reverb, and per-composer instrument tweaks (harpsichord continuo for Baroque, piano for Romantic, marimba for Minimalist, upright bass and brushes for Jazz).
- FG-P6.3 Ambient between-node music generated from the player's best phrases.

```
GATE G6 — Aesthetics
Checks:
  [ ] Peak ≤ −1 dBFS; no audible clicks at note boundaries (offline render analysis)
  [ ] Snapshot set approved
Sign-off: GLM-SELF
```

### P7 Platform Features
- FG-P7.1 Game Center: Daily leaderboard, highest ascension per composer, 30 achievements, daily challenge.
- FG-P7.2 iCloud run and profile sync (mid-run saves at node boundaries and measure boundaries).
- FG-P7.3 Pencil: draw an ornament (trill, mordent, or turn) on a note via gesture recognition for cards with the `ornament` tag; hover previews intervals.
- FG-P7.4 Share sheet for exported audio and MIDI; Mac menus and shortcuts.

```
GATE G7 — Platform
Checks:
  [ ] iCloud round-trip mid-run iPad ↔ Mac
  [ ] Export shares on iPad and Mac
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance
- FG-P8.1 Interval colors paired with shapes (circle consonant, triangle dissonant, star resolved).
- FG-P8.2 VoiceOver reads projected results ("Beat 3: fifth, consonant"); a "theory hints" toggle.
- FG-P8.3 Hearing accessibility: every audio cue has a visual counterpart; subtitles for Patron events.

```
GATE G8 — Polish
Checks:
  [ ] Perf budgets; cold start < 2.0 s; audio latency < 20 ms on iPad (A16)
  [ ] VoiceOver completes the tutorial
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight / P10 Release Prep
- Standard P9 and P10 tasks. FG-P9.1 Two balance passes using opt-in run-summary exports.

```
GATE G9 — Beta: crash-free ≥ 99.5%; no S1/S2 · Sign-off: GLM-SELF
GATE G10 — Release: assets approved; CI green · Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- Fragile areas: interval rules in `Resolution.swift` are the heart of the game; any change requires updating textbook tests; audio scheduling thread safety.
- Priorities for P6–P10: card design pass and composer identity; audio engine robustness and export.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Theory feels like homework | Medium | High | Visual overlays, projected damage, no jargon in core UI | GLM |
| Optimal play sounds bad | Medium | High | Rules tuned so high Harmony requires voice-leading; listening tests at G2 | GLM |
| Sample library licensing | Low | High | CC0 library only; ADR with license text | GLM |
| Combinatorial placement slows autoplayers | Medium | Medium | Pruning and beam search; run sims on Mac | GLM |

## 11. Out of Scope

Free composition sandbox; multiplayer; user-imported samples; notation editing beyond ornaments; non-Western tuning systems (consider later).

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 | GLM | 3 |
| P1 | GLM | 10–14 |
| P2 | GLM | 12–16 |
| P3 | GLM | 14–20 |
| P4 | GLM | 8–12 |
| P5 | GLM | 14–20 |
| P6 | GLM | 15–20 |
| P7 | GLM | 6–9 |
| P8 | GLM | 6–9 |
| P9 | GLM | 10–15 |
| P10 | GLM | 3–5 |
| **Total** | | **101–143** |

## 13. Open Questions

1. Should real music-theory terms appear in the UI? Default: plain-language labels with theory terms in a toggleable glossary.
2. Include 12-tone or modal-jazz composers later? Default: post-launch.
