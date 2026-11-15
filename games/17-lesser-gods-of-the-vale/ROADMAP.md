# 17 — Lesser Gods of the Vale Roadmap

> You are a minor hearth god competing with rival deities for a valley's faith, and you never command a single villager directly.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 in full before starting. This roadmap only adds what is specific to Lesser Gods of the Vale.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 17 · `lesser-gods-of-the-vale` |
| Code prefix | `LGV` (packages `LGVCore`, `LGVContent`, `LGVAI`, `LGVRender`, `LGVAudio`, `LGVPlatform`, `LGVMeta`) |
| Bundle ID (placeholder) | `com.zyniker.lesser-gods-of-the-vale` |
| Subgenre | Indirect 4X (influence without control), season-based turns |
| Difficulty tier | Intermediate |
| Scope | Small team |
| Session length | 30–45 min (12 seasons over 3 years) |
| Renderer | SpriteKit (2D) with a painterly gouache shader (`SKShader` paper grain and pigment bleed); no Metal compute |
| Players | Solo vs 1–3 AI rival gods; local pass-and-play hot-seat for 2–4 humans |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v1.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** You are a minor hearth god competing with rival deities for a valley's faith, and you never command a single villager directly.

**Summary:** A valley holds three to five villages and forty to seventy named villagers, each with a personality, needs, and a faith value toward every god. Each season the gods spend Belief on miracles: rain on a field, a blessed harvest, an omen in the sky, a dream sent to one villager, or a wolf frightened away. Villagers then live the season by simple rules: they work, eat, gossip, build shrines, and argue. What matters is not what a god does but what villagers *believe* the god did: a miracle is credited to whichever god the witnesses think sent it, and stories spread through the village's social web. Miracles can backfire: rain can flood the low fields, and a bounty can make the greedy hoard. After three years, the god with the most believers wins.

**Pillars:**

1. **Influence, never control.** No action targets a villager's behavior directly; only circumstances, signs, and dreams. If any action reads as "make villager X do Y," it fails review.
2. **Credit is contested.** Most seasons, at least one miracle should be credited to the wrong god or disputed (target: 20–35% of miracles in sims).
3. **Stories you retell.** The season log produces at least one memorable, specific line per season ("Old Bertil swears the storm god spared his barn").
4. **Readable faith.** At a glance the player sees which villages lean to which god (color washes) and which villagers are wavering.
5. **Consequences ripple.** A miracle's side effects show up within 1–2 seasons, visibly.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Gouache earth pigments: ochre `#C8913A`, terre verte `#6E8B5A`, burnt sienna `#9C4A2A`, madder `#B5413C`, lapis `#2F4D8A`, chalk `#F1EAD9`, umber shadow `#3B2A1E`. God colors: hearth (you) `#E2A23B`, harvest `#7FA650`, storm `#4E6FA8`, trickster `#9A5AA8`, ancestor `#A8A39A` |
| Shapes | Folk-art flat shapes with visible brush edges, villagers as small stylized figures with one distinguishing prop each, hex tiles hidden under painted terrain (grid shown only when targeting) |
| Typography | Hand-lettered display (default: New York Medium Italic for titles), SF Pro for UI |
| Motion | Gentle cut-paper parallax; miracles animate as painted overlays (rain as brush streaks, omens drawn across the sky) |
| Music | Hummed village voices, wooden flute, and frame drum; seasonal variations (four themes) |
| SFX | Wind through grain, bells for shrine completion, murmuring crowds, thunder, wolves at distance |
| Haptics | Soft swell when a miracle lands; tick per villager converted (batched); low rumble for storm miracles |

**Inspirations:** Polytopia's tribe variety, Six Ages' clan storytelling, and the indirect-control lineage of god games.

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **Renderer:** SpriteKit with a gouache post shader (paper grain, edge darkening). Tiles are hexes internally; the map renders painted region shapes generated from the hex layout.
- **Simulation:** season-step simulation (no real-time). Each season runs the villager simulation in 12 sub-steps (weeks) with integer math.
- **Omen drawing:** Pencil or finger strokes are classified into one of six omen shapes by a $1 Unistroke Recognizer implemented in `LGVPlatform/OmenRecognizer` (deterministic, template-based). Core receives only the resulting `OmenShape` enum. A radial menu is the non-drawing fallback.
- **Story log:** template-based text generation from events (`LGVContent/StoryTemplates`), localized through String Catalogs with plural rules.

ADRs to create in P0:

- ADR-0003 Season sub-step simulation model.
- ADR-0004 Faith as integer 0–100 per villager per god.
- ADR-0005 Omen recognition outside Core.
- ADR-0006 Story templates with deterministic selection.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── LGVCore/Sources/LGVCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Hex.swift
│   ├── Valley/       Valley.swift, Tile.swift (field, forest, river, hill, marsh, village), Weather.swift, Soil.swift
│   ├── People/       Villager.swift, Trait.swift, Needs.swift, Household.swift, SocialGraph.swift, Village.swift
│   ├── Faith/        Faith.swift, Attribution.swift, Witnessing.swift, Story.swift, StorySpread.swift, Shrine.swift
│   ├── Gods/         God.swift, Domain.swift, Belief.swift, Miracle.swift, MiracleEffect.swift, Backfire.swift
│   ├── Season/       SeasonRunner.swift, WeekStep.swift, Harvest.swift, Events.swift (wolves, fever, festival, quarrel)
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift
├── LGVContent/       GodDef.swift, MiracleDef.swift, TraitDef.swift, ValleyTemplate.swift, NameTables.swift, StoryTemplates.swift
├── LGVAI/            RivalGod.swift, MiracleCandidates.swift, Determinizer.swift, RolloutSim.swift, Evaluator.swift, ValleyGenerator.swift
├── LGVRender/        ValleyScene.swift, VillagerNode.swift, FaithWash.swift, MiracleFX/*.swift, SkyCanvas.swift, Shaders/gouache.fsh
├── LGVAudio/         SeasonMusic.swift, Ambience.swift
├── LGVPlatform/      OmenRecognizer.swift ($1), PencilAdapter.swift, GameCenterService.swift, CloudSaveService.swift
└── LGVMeta/          Pantheon.swift (unlocks), Chronicle.swift (saved story logs), DailyValley.swift, Stats.swift
Resources/Content/    gods.json, miracles.json, traits.json, events.json, valleys/*.json, names/*.json, stories.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5.

### 4.1 Setup

- **R-1 Valley.** A hex map (default 14×10) of tiles: `field`, `forest`, `river`, `hill`, `marsh`, and `village`. Each field has soil moisture `0…10` and fertility `0…10`; low tiles (elevation 0) flood.
- **R-2 Villages and villagers.** 3–5 villages; each has 8–16 villagers grouped in households of 2–5. Each villager has: name, age band (child, adult, elder), 2 traits, needs (`food`, `safety`, `meaning`, each 0–10), and faith `f[g]` 0–100 for each god *g* in play.
- **R-3 Gods.** 2–4 gods: the player's god plus rivals. Each has a domain (hearth, harvest, storm, trickster, ancestor), a starting shrine in one village (different for each god), and starting Belief 10.
- **R-4 Starting faith.** Every villager starts with faith 20 in the god whose shrine is in their village and 5 in all others, ±5 from the setup RNG.
- **R-5 Calendar.** The game lasts 12 seasons (spring, summer, autumn, winter × 3 years). Each season is one turn.

### 4.2 Turn Structure

- **R-6 Phases per season.** (1) **Income:** each god gains Belief = `ceil(Σ devotion / 10)` where a villager's devotion to *g* is `f[g]` if *g* is their **patron** (highest faith, ≥ 30; ties: none), else 0; plus 1 per shrine. (2) **Invocation:** gods secretly choose miracles (simultaneous; hot-seat uses a hand-over screen). (3) **Resolution:** miracles resolve in the order of R-15. (4) **The season:** 12 weekly sub-steps of villager life (R-20). (5) **Reckoning:** stories spread, faith decays, and end-of-season events. (6) **Victory check** (R-35).
- **R-7 Belief cap.** Belief carries over, capped at `balance.belief.cap` (default 40).

### 4.3 Miracles

- **R-8 Miracle definition.** A miracle has a cost, a target type (`tile`, `area` radius 1–2, `village`, `villager`, or `sky`), a domain, a visible **sign** (what witnesses see), effects, and backfire rules (`miracles.json`).
- **R-9 Domain affinity.** Miracles in the god's own domain cost −1 (min 1). Off-domain miracles cost +1 and have a 15% higher backfire chance.
- **R-10 Limit.** Each god may invoke at most 3 miracles per season and at most one targeting any single villager.
- **R-11 Core miracle set (v1.0 minimum).** `rain` (area: +3 moisture), `sun` (area: −2 moisture, +1 fertility next harvest), `bless_harvest` (field: harvest ×1.5), `omen` (sky: a shape in the sky over a village; see R-13), `dream` (villager: +meaning, and plants a **vision** that the villager may retell), `calm_wolves` (area: removes a wolf threat), `heal` (villager: cures fever), `ward` (village: +safety for the season), `storm` (storm domain; area: damage plus awe), `misdirect` (trickster; see R-18), `ancestral_voice` (ancestor; elder villager: +meaning to their household).
- **R-12 Signs.** Each miracle carries a sign: `none` (unseen), `subtle` (only villagers with trait `perceptive` or within the target area notice), `visible` (everyone in the village or area), or `spectacular` (everyone in the valley).
- **R-13 Omens.** An omen's shape is one of `circle`, `spiral`, `crescent`, `cross`, `line`, or `zigzag`. Each god has two **favored shapes** (from `gods.json`). Witnesses attribute an omen to the god whose favored shapes include it; an omen in an unfavored shape is attributed by the general rule (R-16). An omen grants +meaning and makes the next miracle in that village within 2 seasons count its sign as one level stronger.
- **R-14 Effects are real.** Miracle effects change simulation values (moisture, harvest, threats, needs) regardless of attribution.
- **R-15 Resolution order.** Miracles resolve by (a) target type order `sky, area, tile, village, villager`; (b) within type, the god with the least total believers first (catch-up tie-break); (c) then god ID. Effects on the same value are additive.

### 4.4 Attribution and Witnessing

- **R-16 Attribution.** For each miracle with a sign stronger than `none`, every witness *v* assigns credit to a god by weight: `w[g] = f_v[g] + 20 × [g has a shrine in v's village] + 15 × [miracle domain is g's domain] + 25 × [g's favored omen seen in v's village within 2 seasons] + 10 × [g invoked this miracle and v has trait pious]`. Credit goes to the highest weight; ties go to the god with the shrine; further ties to "the old powers" (no god).
- **R-17 Faith from credit.** A witness who credits a god with a **beneficial** miracle gains `+benefit × trait multiplier` faith in that god (benefit from `miracles.json`, default 6). A harmful effect (including backfire) credited to a god costs that much faith instead, unless the witness has trait `fearful`, in which case harm also increases faith (awe) by half.
- **R-18 Misdirect (trickster).** Misdirect targets an enemy miracle invoked this season in a chosen village (the trickster guesses the village); if any enemy miracle resolves there, witnesses add +40 weight to the trickster in R-16. If none resolves there, the Belief is spent with no effect.
- **R-19 Disputed credit.** If the top two weights differ by ≤ 5, the miracle is **disputed**: each credited god gets half the faith change, and the event creates a `quarrel` story (R-26).

### 4.5 Villager Life (Weekly Sub-Steps)

- **R-20 Week step order.** For each village in ID order, for each villager in ID order: (1) choose a task by needs: `work` (fields), `gather` (forest), `guard`, `worship` (at their patron's shrine if any), `gossip`, or `rest`; (2) apply task effects; (3) needs decay (food −1 every 3 weeks, safety −1 every 4 weeks unless warded, meaning −1 every 4 weeks).
- **R-21 Task choice.** Deterministic utility: each task has a score from needs, traits, and season (e.g., `work` high in spring and autumn), plus a seeded jitter of 0–2 from the season RNG. Highest score wins; ties by task enum order.
- **R-22 Harvest.** At the end of summer and autumn, each worked field yields `fertility × moistureFactor × workers` food (moisture 4–7 optimal, factor 1.0; 2–3 or 8 factor 0.6; ≤ 1 or ≥ 9 factor 0.2). Food is shared by household, then village.
- **R-23 Shrines.** Villagers whose patron is *g* and who choose `worship` add 1 shrine progress for *g* in their village. At 20 progress a shrine is built (one per god per village). A shrine gives +1 Belief per season to its god (R-6) and +20 attribution weight (R-16).
- **R-24 Faith drift.** Each week, a villager who worships gains +1 faith in their patron. In Reckoning, all faith above 20 decays by 2 per season (devotion must be renewed).
- **R-25 Traits.** Traits from `traits.json` modify task scores, faith gains, gossip spread, and backfire reactions. Minimum set: `pious`, `skeptical` (faith gains ×0.5, losses ×1.0), `fearful`, `greedy` (hoards surplus food; reduces village food sharing), `curious` (gossips more; retells visions), `perceptive` (sees subtle signs), `stubborn` (faith changes capped at ±3 per event), `kindly` (shares food; +safety to household).

### 4.6 Stories

- **R-26 Story creation.** Every credited miracle, disputed miracle, vision (from `dream`), backfire, and notable event creates a **story** object: `(kind, god, subject villager, village, strength 1–5, season)`.
- **R-27 Spread.** In Reckoning, each story spreads along the social graph: every villager linked to a teller has `strength × 10%` chance (from the season RNG; `curious` tellers ×1.5) to hear it; a hearer gains half the faith change the original witness received (credited god), and becomes a teller next season with strength −1.
- **R-28 Social graph.** Household members are fully linked; each villager has 2–4 friends in their village and a 20% chance of one friend in a neighboring village (setup RNG). Marriages and quarrels add and remove links.
- **R-29 Story log.** Every story with strength ≥ 3 produces a log line from `stories.json` templates selected by `(kind, trait of subject, season)` using the season RNG.

### 4.7 Backfire and Events

- **R-30 Backfire.** Each miracle has `backfireChance` (base from table, modified by R-9 and by state, e.g., `rain` on a tile with moisture ≥ 7 has +40% chance of flooding low tiles within radius 1). Backfire effects are real (R-14) and attributed by R-16 like any miracle.
- **R-31 Valley events.** In Reckoning, the season RNG may trigger events from `events.json` weighted by state: `wolves` (safety threat; −safety in a village until calmed), `fever` (villagers sick; needs heal or rest), `festival` (if food surplus; +meaning, stories spread ×1.5), `quarrel` (social links break), `wedding` (links form), `pilgrim` (a stranger arrives with faith in a random god), `drought` (if 2 consecutive dry seasons).
- **R-32 Death and birth.** Elders may die in winter (chance from food and fever); children become adults after 2 years; new children are born to households with surplus food (inherit parents' patron at faith 15). Villager counts stay within 30–90 by soft caps in `balance.json`.

### 4.8 Victory

- **R-33 Believer.** A villager is a believer of *g* if *g* is their patron (R-6).
- **R-34 Score.** At game end, score = believers × 3 + shrines × 4 + stories with strength ≥ 3 about *g* still active × 1.
- **R-35 Victory.** After season 12, the highest score wins; ties: more believers, then more shrines, then shared victory. **Early Ascension:** at the end of any season after season 6, a god with a shrine in every village and ≥ 60% of all villagers as believers wins immediately.

### 4.9 Edge Cases

- **R-36** A miracle targeting a villager who dies the same season still resolves its non-villager effects; stories about them persist.
- **R-37** If a god has no believers and no shrines for 3 consecutive seasons, it **fades** (eliminated); its shrines become abandoned (no weight bonus).
- **R-38** Two `rain` and `sun` miracles on overlapping areas net their moisture changes before backfire checks.
- **R-39** Misdirect on the trickster's own miracle has no effect.

### 4.10 Invariants

- **INV-1** All faith values are within 0…100; all needs within 0…10.
- **INV-2** Belief ≥ 0 and ≤ cap for every god after Income.
- **INV-3** Every villager has at most one patron.
- **INV-4** Miracles never change a villager's chosen task directly (static check: miracle effects table has no `task` field; plus a runtime assertion).
- **INV-5** Replays are byte-identical across platforms.
- **INV-6** The sum of believers across gods ≤ villager count.
- **INV-7** Story spread never increases strength.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var season: Int; public var phase: Phase; public var rng: SeededRNG
    public var valley: Valley; public var villagers: [VillagerID: Villager]
    public var villages: [VillageID: Village]; public var social: SocialGraph
    public var gods: [GodID: God]; public var shrines: [ShrineKey: Shrine]
    public var stories: [Story]; public var pendingInvocations: [GodID: [Invocation]]
    public var log: [LogEntry]
}
public struct Villager: Codable, Equatable, Hashable, Sendable {
    public var id: VillagerID; public var name: NameKey; public var village: VillageID; public var household: HouseholdID
    public var age: AgeBand; public var traits: [TraitID]; public var needs: Needs
    public var faith: [GodID: Int]; public var sick: Bool; public var task: Task?
}
public struct Invocation: Codable, Equatable, Hashable, Sendable {
    public var miracle: MiracleID; public var target: Target; public var omen: OmenShape?
    public var misdirectVillage: VillageID?
}
public enum Action: Codable, Equatable, Sendable {
    case invoke(GodID, [Invocation]); case endInvocation(GodID); case advance   // runs resolution, season, reckoning
}
public enum Event: Codable, Equatable, Sendable {
    case miracleResolved(MiracleID, by: GodID, target: Target, backfired: Bool)
    case credited(MiracleID, witness: VillagerID, to: GodID?, disputed: Bool)
    case faithChanged(VillagerID, GodID, delta: Int), patronChanged(VillagerID, from: GodID?, to: GodID?)
    case shrineBuilt(GodID, VillageID), storyCreated(StoryID), storySpread(StoryID, to: VillagerID)
    case valleyEvent(EventID, VillageID), born(VillagerID), died(VillagerID), godFaded(GodID), gameEnded(Result)
}
```

### 5.2 Content Tables

**`gods.json`** — G3: 5 gods.

```json
{ "id": "storm", "domain": "storm", "color": "#4E6FA8", "favoredOmens": ["zigzag", "line"],
  "uniqueMiracles": ["storm"], "aiPersonality": "awe_seeker", "nameKey": "god_storm" }
```

**`miracles.json`** — G3: 11 (R-11); G5: 18 (adds `bountiful_fish`, `lost_child_found`, `bless_marriage`, `wildfire`, `bridge_of_mist`, `echo`, `sleep`).

```json
{ "id": "rain", "cost": 3, "domain": "storm", "target": "area", "radius": 1, "sign": "visible",
  "effects": [{ "moisture": 3 }], "benefit": 6, "backfire": { "base": 5,
  "conditions": [{ "if": "moisture>=7", "add": 40, "effect": "flood_low_tiles" }] } }
```

**`traits.json`** — G3: 8; G5: 14.

```json
{ "id": "skeptical", "faithGainMul": 50, "faithLossMul": 100, "taskBias": { "worship": -2 }, "gossipMul": 100 }
```

**`events.json`** — G3: 7; G5: 12.

**`valleys/*.json`** — G3: 3 handcrafted; G5: 6 handcrafted + procedural generator.

```json
{ "id": "willow_bend", "size": [14, 10], "tiles": "base64", "elevation": "base64",
  "villages": [{ "id": "v1", "hex": [3, 4], "size": 12 }], "riverPath": [[0,6],[1,6],[2,5]] }
```

**`names/*.json`** — three cultures of folk names (invented, not real-world specific), ≥ 200 names each.

**`stories.json`** — G3: 80 templates; G5: 200.

```json
{ "kind": "credited_benefit", "trait": "stubborn", "season": "any",
  "textKey": "story_stubborn_credit_1", "en": "{villager} grumbles, but even {they} admits {god} saved the {crop}." }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `belief.cap` | 40 | 30–60 | balance.json |
| `belief.perShrine` | 1 | 1–2 | balance.json |
| `faith.patronThreshold` | 30 | 25–40 | balance.json |
| `faith.decayAbove20` | 2 | 1–3 | balance.json |
| `attribution.shrineWeight` | 20 | 10–30 | balance.json |
| `attribution.domainWeight` | 15 | 5–25 | balance.json |
| `attribution.omenWeight` | 25 | 15–35 | balance.json |
| `attribution.disputeMargin` | 5 | 3–10 | balance.json |
| `shrine.progressNeeded` | 20 | 15–30 | balance.json |
| `story.spreadPerStrength` | 10% | 5–15% | balance.json |
| `miracle.perSeasonLimit` | 3 | 2–4 | balance.json |
| `ascension.believerShare` | 60% | 50–75% | balance.json |

**Target metrics (sims, ≥ 1,000 games per configuration):**

| Metric | Target |
| --- | --- |
| Win rate per god, equal AI, 4-god games | 20–30% each |
| Misattributed or disputed miracles | 20–35% |
| Early Ascension rate | 5–15% of games |
| Backfire rate (all miracles) | 8–15% |
| Games where the season-6 leader loses | 25–40% (comebacks exist) |
| Hard AI vs medium AI head-to-head (2-god) | 65–75% |

## 7. AI Approach

| Tier | Algorithm | Budget (iPad A16, p95) |
| --- | --- | --- |
| `novice` | Utility: picks the miracle with the highest immediate expected faith gain per Belief in its strongest village, with no backfire awareness | 50 ms |
| `adept` | Generates 40 candidate invocation sets (3 miracles max), evaluates each with 4 **determinized rollouts** of the current season only (unknown rival invocations sampled from the novice policy) | 800 ms |
| `elder` | Same as adept with 96 candidates, 8 rollouts each, and a 2-season horizon using a fast **reduced simulator** (`RolloutSim`: households aggregated, stories approximated by expected spread) | 1,500 ms |

**Evaluation:** projected score (R-34) delta vs the best rival, Belief efficiency, shrine progress, wavering villagers (faith within 10 of patron threshold) converted, and backfire risk.

**Personalities** (from `gods.json`): `awe_seeker` (storm, prefers spectacular signs), `provider` (harvest, prefers fields), `schemer` (trickster, prefers misdirect on the leader's strongest village), `keeper` (ancestor, prefers elders and dreams), and `hearth` (balanced; used for player-god hints only).

**Determinism:** AI RNG streams `SplitMix64(seed ^ godID ^ season)`; rollouts copy state and use forked RNGs; the real season RNG is never advanced by AI.

**Valley generator:** river by downhill walk on a seeded heightmap, villages placed by Poisson-disk on flat tiles near water, fields assigned within radius 2 of villages, validated for at least 6 fields per village.

## 8. Phases, Tasks, and Gates

### P0 Setup (Owner: GLM)

Standard tasks S0.1–S0.7.

- **LGV-P0.1 Hex utilities and the valley loader.** Acceptance: round-trip tests.
- **LGV-P0.2 Name and template loaders** with String Catalog keys. Acceptance: missing-key lint fails the build.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-39 and INV-1…INV-7
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype (Owner: GLM)

Standard tasks S1.1–S1.4.

- **LGV-P1.1 Villager sim (R-20–R-25, R-32).** Acceptance: a valley with no gods stabilizes (no starvation spiral) over 12 seasons in ≥ 95% of 1,000 seeds; test fixtures for each trait's effect.
- **LGV-P1.2 Miracles and resolution order (R-8–R-15).**
- **LGV-P1.3 Attribution and credit (R-16–R-19).** Acceptance: table-driven tests of the weight formula with ≥ 30 cases including disputes and misdirect.
- **LGV-P1.4 Stories and spread (R-26–R-29).**
- **LGV-P1.5 Backfire and events (R-30, R-31).**
- **LGV-P1.6 Income, victory, ascension, and fading (R-6, R-7, R-33–R-37).**
- **LGV-P1.7 Sim CLI.** `Tools/sim --valley willow_bend --gods hearth,storm --ai novice,novice --games 1000` reports win rates, misattribution rate, backfires, and villager counts.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged and passing; INV-1…INV-7 over 1,000 seeds
  [ ] LGVCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms
  [ ] Full season simulation (70 villagers) ≤ 20 ms on CI Mac
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice (Owner: GLM)

Standard tasks S2.1–S2.5. Slice scope: one valley, player (hearth) vs one novice rival (harvest), 8 miracles, 6 traits, 40 story templates, 12 seasons.

- **LGV-P2.1 Valley scene.** Painted regions, villages with villager figures, faith washes per village (blended god colors), and a wavering marker (small flame) above villagers within 10 of switching.
- **LGV-P2.2 Miracle painting.** Pick a miracle from the shrine bar, then paint or tap the target; area miracles follow the finger as a soft brush with a radius preview; confirm with a "Invoke" seal (select-then-confirm). Mouse: click-drag, Return to confirm.
- **LGV-P2.3 Omen drawing (finger) with the $1 recognizer** and the radial fallback; recognition result shown as a clean glyph before confirming.
- **LGV-P2.4 Season playback.** 10–15 seconds of animated village life, then Reckoning cards: credit (who credited whom), new believers, and 2–3 story log lines.
- **LGV-P2.5 Villager inspector.** Press and hold a villager: traits, needs, faith bars, friends, and stories they carry.

Slice checks: Mahler can tell within one season which miracle was miscredited and why (pillar 2); the story log produces specific lines (pillar 3).

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays 12 seasons vs novice to the results screen on iPad and Mac
  [ ] Omen recognizer ≥ 90% accuracy on a 120-stroke test corpus (20 per shape, committed in Tests/Fixtures/omens)
  [ ] Save and resume mid-invocation to identical hash
  [ ] docs/media/slice.mp4 recorded
  [ ] REVIEW: GROK — does influence-without-control produce interesting decisions? Is attribution legible?
  [ ] REVIEW: MAHLER — fun enough to continue?
Sign-off: REVIEW: GROK + MAHLER · 🛑 GLM STOP
```

### P3 Content and Systems (Owner: GLM)

- **LGV-P3.1** 5 gods with domains, favored omens, and unique miracles; 18 miracles total.
- **LGV-P3.2** 14 traits, 12 events, births, deaths, weddings, and quarrels.
- **LGV-P3.3** 6 handcrafted valleys and the procedural generator.
- **LGV-P3.4** 200 story templates with plural- and pronoun-correct English (they/he/she chosen per villager from name tables).
- **LGV-P3.5** Tutorial: a 3-season "first year" with a gentle rival and four coached moments (rain on a dry field, an omen in your shape, a dream to a wavering villager, a backfire).
- **LGV-P3.6** Hot-seat for 2–4 humans with a hand-over screen.

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 5 gods, 18 miracles, 14 traits, 12 events, 6 valleys, 200 templates
  [ ] content-lint 0 errors; every template's placeholders resolve in a render test
  [ ] Tutorial UI test passes
  [ ] REVIEW: CLAUDE (async)
Sign-off: GLM-SELF + REVIEW: CLAUDE (async)
```

### P4 AI Opponents (Owner: GLM)

- **LGV-P4.1** Novice, adept, and elder tiers; personalities.
- **LGV-P4.2** `RolloutSim` reduced simulator with a fidelity test: its projected patron counts match the full sim within ±10% over 500 seasons.
- **LGV-P4.3** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] 500 games per tier per god pairing: 0 crashes, 0 illegal invocations
  [ ] p95 think time within §7 budgets (CI Mac scaled; real devices in P8)
  [ ] Win-rate targets in §6
Sign-off: GLM-SELF
```

### P5 Meta and Replayability (Owner: GLM)

- **LGV-P5.1 Pantheon unlocks.** Start with hearth and harvest; unlock storm, trickster, and ancestor by winning as other gods. All earnable.
- **LGV-P5.2 Chronicle.** Every finished game saves its story log as an illuminated "chronicle" page (text plus a few event vignettes); browse past chronicles.
- **LGV-P5.3 Daily Valley.** Date-derived seed: valley, gods, and rivals; one ranked attempt; score per R-34.
- **LGV-P5.4 Difficulty settings** (rival tier, Belief handicap) and custom game setup.
- **LGV-P5.5 Stats:** wins by god, best scores, most-retold story.

```
GATE G5 — Meta and Replayability (Final GLM Handoff)
Checks:
  [ ] Daily Valley deterministic for 60 dates across devices
  [ ] Chronicle renders for 100 sim games without layout overflow (snapshot sample)
  [ ] All standard tests and coverage thresholds pass
  [ ] docs/HANDOFF.md complete
  [ ] REVIEW: CLAUDE + GROK + MAHLER
Sign-off: REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP
```

### P6 Aesthetics and Audio Pass (Owner: GROK + CLAUDE)

- **LGV-P6.1** Final gouache art: terrain, villages, villager figures (12 base figures × props), god emblems.
- **LGV-P6.2** Miracle FX per miracle; omen sky painting animates the player's own stroke.
- **LGV-P6.3** Seasonal palette shifts and weather overlays.
- **LGV-P6.4** Music (4 seasonal themes, 5 god motifs) and ambience.
- **LGV-P6.5** Grok edits the 200 story templates for voice and variety.

```
GATE G6 — Aesthetics
Checks:
  [ ] Pillar 4 screenshot test: Grok identifies each village's leading god in 10/10 frames
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P7 Platform Features (Owner: CLAUDE)

- **LGV-P7.1 Pencil.** Draw omens with Pencil; hover over a tile previews a miracle's area and backfire risk; squeeze opens the miracle palette.
- **LGV-P7.2 Game Center.** Daily Valley leaderboard, 30 achievements, challenges.
- **LGV-P7.3 iCloud.** Saves and chronicles.
- **LGV-P7.4 Mac.** Number keys select miracles, Tab cycles villages, Return invokes, ⌘L opens the log.

```
GATE G7 — Platform
Checks:
  [ ] Pencil omen recognition ≥ 90% on corpus; finger and radial fallback both work
  [ ] Game Center sandbox round trip; iCloud resume across iPad and Mac
  [ ] REVIEW: GROK
Sign-off: REVIEW: GROK
```

### P8 Polish, Accessibility, and Performance (Owner: CLAUDE)

- **LGV-P8.1** Faith washes color-blind safe (each god also has a pattern texture: dots, stripes, waves, crosshatch, and solid).
- **LGV-P8.2** VoiceOver for villages and villagers; omen selection fully via radial menu.
- **LGV-P8.3** Dynamic Type for the log and chronicle.
- **LGV-P8.4** Perf on A16 iPad with 90 villagers.

```
GATE G8 — Polish
Checks:
  [ ] Budgets met on real devices; accessibility audit clean
  [ ] REVIEW: GROK + MAHLER
Sign-off: REVIEW: GROK + MAHLER
```

### P9 Beta and TestFlight (Owner: GROK + CLAUDE)

- **LGV-P9.1** Internal TestFlight (Mahler creates records).
- **LGV-P9.2** Opt-in export of game summaries (god, score, misattribution rate).
- **LGV-P9.3** Balance and story-template revisions.

```
GATE G9 — Beta
Checks:
  [ ] Crash-free ≥ 99.5%; no S1/S2 open
  [ ] ≥ 70% of testers can explain attribution after one game (survey Mahler approves)
  [ ] REVIEW: MAHLER
Sign-off: REVIEW: MAHLER
```

### P10 Release Prep (Owner: CLAUDE + GROK)

Standard P10 tasks; preview shows an omen drawn in the sky and a village turning color. Age rating draft should note mild fantasy themes; religious themes are folk and fictional (Grok reviews copy for respectful tone).

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; clean-install smoke
  [ ] Metadata, privacy, and age-rating drafts reviewed
  [ ] REVIEW: MAHLER (submits)
Sign-off: REVIEW: MAHLER
```

## 9. Handoff to Grok and Claude

- **Fragile areas:** attribution weights (R-16) dominate the feel; small changes swing misattribution rates heavily. The villager sim must not starve valleys (P1.1 stability test is a regression guard).
- **Content:** story templates are the voice of the game; Grok owns them after G5.
- **First tasks:** Grok — tune attribution weights and story spread toward pillar 2 targets; Claude — Pencil omen flow and the gouache shader performance.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Players feel powerless (no direct control) | Medium | High | Strong feedback in Reckoning cards; wavering markers; tutorial | GROK |
| Simulation opaque | Medium | High | Villager inspector, credit breakdown per miracle | GLM → CLAUDE |
| Story log repetitive | Medium | Medium | 200 templates, selection by trait and season, no repeats within 3 seasons | GROK |
| Religious sensitivity | Low | Medium | Fictional folk gods; no real-world religions; respectful tone review | GROK + MAHLER |
| AI too slow with rollouts | Medium | Medium | Reduced simulator; adaptive candidate counts | GLM |

## 11. Out of Scope

- Online multiplayer.
- Direct villager control or building placement by the player.
- Real-world religions, saints, or scriptures.
- 3D rendering.
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 12–16 |
| P2 Vertical Slice | GLM | 8–12 |
| P3 Content and Systems | GLM | 12–16 |
| P4 AI | GLM | 7–10 |
| P5 Meta | GLM | 4–6 |
| P6 Aesthetics and Audio | GROK + CLAUDE | 14–20 |
| P7 Platform | CLAUDE | 4–6 |
| P8 Polish | CLAUDE | 5–7 |
| P9 Beta | GROK + CLAUDE | 8–12 |
| P10 Release | CLAUDE + GROK | 2–4 |
| **Total** | | **78–112** |

## 13. Open Questions for Mahler

1. Is the folk-pantheon framing (fictional gods) acceptable given the user base? **Default:** yes, fictional and clearly mythic.
2. Should the player be able to choose any god from the start? **Default:** no; two to start, three unlockable.
3. Game length 12 seasons? **Default:** yes, with a "long" setting of 20 seasons.
4. Hot-seat in v1.0? **Default:** yes.
5. Price? **Default:** Mahler decides in P10.
