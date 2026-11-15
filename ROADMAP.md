# Roadmap

Geist is a program of **twenty-five original iOS games** built in one repository on one shared Swift engine. Each game lives in its own folder under `games/`, has its own roadmap, status, checks, and version tags, and ships on its own. This file is the **program roadmap**: it says how the whole program runs, in what order, to what standard, and how work moves from one game to the next without stopping.

Read this file and `STATUS.md` first, every time. `STATUS.md` says exactly where the program stands; this file says what to do next. Each game's own `games/NN-<slug>/ROADMAP.md` says what that game is.

Priorities, in order, when they conflict: **a game that works and is fun, then stability and data safety, then privacy and accessibility, then launch polish, then extra content.** A finished, launch-ready small game beats an unfinished large one.

## How the Program Runs

The program moves through four phases. Phases P0 and P1 happen once; P2 repeats for each game; P3 closes the program.

| Phase | What happens | Ends when |
| --- | --- | --- |
| P0: Program Review | Review this roadmap, the game roadmaps that exist, and the queue | The P0 **Done when** line is met |
| P1: Shared Foundation | Build the engine package, common modules, the project generator, CI, and the checks | The P1 **Done when** line is met |
| P2: Game Pipeline (×25) | Take the next game through stages G0 to G6, close it out, and start the next | All twenty-five games are launch-ready or parked with a recorded reason |
| P3: Program Launch Readiness | Final regression run, store materials review, and program close-out | The P3 **Done when** line is met |

Work never waits for a person. Anything only the maintainer can do goes on the **Needs the Maintainer** list in `STATUS.md` (see [Needs the Maintainer](#needs-the-maintainer)), and work continues on everything else.

## Repository Layout

```
ROADMAP.md                 this file: the program roadmap
STATUS.md                  program status: the single place to resume from
AGENTS.md                  rules for anyone (human or agent) changing the repository
docs/
  game-roadmap-template.md the contract every game roadmap meets
  decisions/               program-wide decision records (NNNN-title.md)
  handoffs/                one close-out note per finished or parked game
Engine/                    the shared Swift package (GeistKit), from P1
  Package.swift
  Sources/<Module>/
  Tests/<Module>Tests/
games/
  NN-<slug>/               one folder per game, NN = 01 to 25
    ROADMAP.md             the game's own roadmap (see the contract below)
    STATUS.md              the game's stage, last done, next step, and log
    project.yml            XcodeGen spec; no .xcodeproj is committed
    Sources/  Tests/  UITests/  Resources/
    ASSETS.md              provenance of every asset in the game
    store/                 store text, keywords, age-rating answers, and screenshot plans
    scripts/check.sh       the game's own check (lint, build, and test)
scripts/
  check.sh                 global check: engine, every game, or one game by number
  new-game.sh              scaffolds games/NN-<slug>/ from the template (P1)
.github/workflows/         CI with path filters per game (P1)
```

`NN` is the game's two-digit number in the queue (01 to 25), and `<slug>` is a short lowercase, hyphenated working name taken from its roadmap. Numbers never change once given, even if the build order changes; the queue order lives in `STATUS.md`.

## The Game Roadmap Contract

Each game's roadmap is written separately and placed at `games/NN-<slug>/ROADMAP.md`. If a roadmap arrives somewhere else (for example a single file under `roadmaps/` or `games/`), move it into its own folder with `git mv`, keeping its text, and add it to the queue in `STATUS.md`. The full template is `docs/game-roadmap-template.md`. A game roadmap meets the contract when it has all of these sections:

1. **Pitch.** One paragraph: what the game is and why it is fun.
2. **Core Loop.** What the player does, second to second and session to session.
3. **Controls and Platforms.** Touch controls, device targets (iPhone, iPad, and optionally Mac), and orientation.
4. **Content Scope for v1.0.0.** The levels, modes, items, or other content that ship at launch, with numbers.
5. **Look and Sound.** Art style, palette, and audio direction, using only assets that can be shipped cleanly (see [Assets and Licensing](#assets-and-licensing)).
6. **Engine Needs.** Which shared modules it uses, and anything it needs that the engine does not yet have.
7. **Monetization.** Paid, free, or in-app purchases, and exactly what each purchase unlocks. "None" is a valid answer.
8. **Game-Specific Risks.** What is hardest to get right.
9. **Milestones.** Ordered milestones mapped onto stages G2 to G5, each with a **Done when** line that a command or a recorded manual step can check.
10. **Done when (v1.0.0).** The game-level definition of done, on top of the [Per-Game Launch Gate](#g6-launch-ready-gate).

### Filling Gaps

The program never stalls on a thin or missing roadmap.

- **A section is missing or vague:** fill it during G0 with the smallest choice that fits the pitch, mark the filled text with "(filled in G0)", and record anything significant as a decision in the game's `docs/decisions/`.
- **The roadmap conflicts with this file:** this file wins on process, quality, privacy, and licensing; the game roadmap wins on design. Record the resolution.
- **The roadmap is missing entirely when its turn comes:** skip to the next game in the queue that has one, and note it in `STATUS.md`. If none of the remaining games has a roadmap, spend the time on [Program Work Between Games](#program-work-between-games), then check again.
- **The roadmap changes after work starts:** pull it, compare, and fold the change in at the next stage boundary. A change to a game that is already launch-ready reopens it at the stage the change affects.

## P0: Program Review

Before the foundation is built, review the plan, so the whole program is achievable and each game can end launch-ready rather than as a demo.

- Read this file, `AGENTS.md`, `STATUS.md`, `docs/game-roadmap-template.md`, and every game roadmap that exists. Then revise this file and the template directly: fix contradictions, sharpen any **Done when** line that cannot be checked, and list every engine capability the existing game roadmaps need.
- At most **three passes**, each with one main lens: (1) **achievability and order** (can each phase and stage be done and checked with the tools in [Fixed Choices](#fixed-choices), and does each have what it needs from earlier work?), (2) **engine coverage** (does the P1 module list cover what the games need, and is anything in it unneeded?), and (3) **launch readiness** (walk the [Per-Game Launch Gate](#g6-launch-ready-gate) as if submitting tomorrow). Stop early when a pass makes no material change.
- Log each pass in `STATUS.md` (pass, lens, changes, still open). Record real decisions in `docs/decisions/`.
- Set the build queue in `STATUS.md` using the [Build Order](#build-order) rules.

**Done when:** at most three passes are logged, decisions 0001 to 0004 exist (see [Decisions to Record](#decisions-to-record)), the queue table in `STATUS.md` lists every game roadmap present with a build order, and every maintainer step known so far is on the **Needs the Maintainer** list.

## P1: Shared Foundation

Build what every game shares, once, before the first game. Keep it small: build a module only when at least one queued game needs it, and grow the engine as games need more (see [Growing the Engine](#growing-the-engine)).

### Engine Package

`Engine/` is one Swift package (working name `GeistKit`; final name recorded in decision 0002) with these modules as the starting point:

| Module | Purpose |
| --- | --- |
| `GeistCore` | Game loop helpers, fixed-step timing, seeded random numbers, state machines, and a scene-flow coordinator |
| `GeistUI` | SwiftUI shell: main menu, pause, settings, credits, and onboarding screens, themable per game |
| `GeistSprite` | SpriteKit helpers: scene base classes, camera, tile maps, particles, and input mapping from touch and game controllers |
| `GeistAudio` | Music and sound effects on AVAudioEngine, with volume buses, ducking, and mute that follows the system silent switch |
| `GeistHaptics` | Core Haptics patterns with a simple fallback and a settings toggle |
| `GeistSave` | Versioned, atomic save files with migrations, corruption recovery, and tests from every earlier save version |
| `GeistSettings` | Shared settings model (audio, haptics, accessibility, language, and controls) stored with the save system |
| `GeistAccess` | Accessibility support: Dynamic Type for menus, VoiceOver labels, Reduce Motion, color-blind-safe palettes, and hold-to-tap alternatives |
| `GeistLocal` | String Catalog helpers, pseudo-localization for tests, and locale-aware number and time formatting |
| `GeistCenter` | Game Center leaderboards and achievements behind an interface that works fully offline and in tests without an account |
| `GeistStore` | StoreKit 2 purchases and restore, tested with local StoreKit configuration files; only for games whose roadmap calls for purchases |
| `GeistTestKit` | Test helpers: deterministic clocks and random numbers, headless scene stepping, and save fixtures |

The engine builds and tests with `swift test` on macOS. Logic that does not need Apple frameworks goes in modules that also build on Linux, so most tests run anywhere.

### Project Generator and Scaffolding

- Every game's Xcode project is generated by XcodeGen from `games/NN-<slug>/project.yml`. No `.xcodeproj` is committed. The XcodeGen version is pinned in CI and in `scripts/check.sh`.
- `scripts/new-game.sh NN slug` creates a game folder from a template: `project.yml`, an app target with the engine as a local package, a test target, a UI-test target, `STATUS.md`, `ASSETS.md`, `store/`, and `scripts/check.sh`. A scaffolded game builds, launches to its menu, and passes its tests on the first run.
- Bundle identifiers and the development team come from one shared settings file with obvious placeholder values. The real values are a maintainer step.

### Checks and CI

- `games/NN-<slug>/scripts/check.sh` runs that game's format check, build, unit tests, and UI smoke test on the iPhone simulator. It runs what CI runs for that game.
- `scripts/check.sh` runs the engine tests and then every game's check; `scripts/check.sh engine` runs only the engine, and `scripts/check.sh NN` runs only game NN.
- CI on GitHub Actions, with read-only permissions and every action pinned to a full commit SHA:
  - a change under `Engine/` runs the engine tests **and every game that has reached G2**, because an engine change can break any of them;
  - a change under `games/NN-<slug>/` runs only that game;
  - a change to `scripts/`, `.github/`, or the shared settings runs everything;
  - a weekly scheduled run and every program checkpoint run everything.
- Format and lint with `swift-format`, with one shared configuration.

**Done when:** `scripts/check.sh` passes locally and in CI; `scripts/new-game.sh 99 sample` produces a game that builds, launches to its menu on the iPhone simulator, and passes its tests (then the sample is deleted); the path filters are shown to work by one engine-only change and one game-only change; and the engine is tagged `engine/v0.1.0`.

## P2: The Game Pipeline

Each game goes through stages G0 to G6 in order. A stage is done only when its **Done when** line is met and shown with real output from the game's `scripts/check.sh` (and, where a stage says so, simulator screenshots kept in the game's `docs/`). Record each stage change in the game's `STATUS.md` and in the program `STATUS.md`.

### G0: Plan Review

Read the game's roadmap against the [contract](#the-game-roadmap-contract), fill gaps, and check the game's milestones fit stages G2 to G5. At most **three passes**, and stop at the first pass that makes no material change. Write no game code in G0.

**Done when:** the roadmap meets the contract, its passes are logged in the game's `STATUS.md`, and any engine work it needs is listed in the game's `STATUS.md`.

### G1: Scaffold

Run `scripts/new-game.sh`, set the game's name, orientation, and device targets, and add any engine work G0 listed (see [Growing the Engine](#growing-the-engine)).

**Done when:** the game builds, launches to its menu on the iPhone simulator, passes `scripts/check.sh NN`, and CI is green for it.

### G2: Core Loop

Build the smallest version of the core loop that can be played start to finish, with placeholder art. Play it in the simulator, look at screenshots, and improve it until it is fun in its simplest form.

**Done when:** one complete session can be played from the menu to a result screen, a UI test plays it automatically, the game logic has unit tests with deterministic random numbers, and a screenshot of the core loop is kept in the game's `docs/`.

### G3: Content

Build the v1.0.0 content scope from the roadmap: levels, modes, progression, and difficulty. Content that is data (levels, waves, and tables) is validated by tests.

**Done when:** all the content in the roadmap's v1.0.0 scope exists and is reachable, a test checks every level or content item loads and can be completed or reached, and progression is saved and restored across app restarts by a test.

### G4: Polish

Final art, sound, music, haptics, transitions, juice, onboarding, settings, accessibility, and localization for the languages the roadmap names (English at minimum). Replace every placeholder.

**Done when:** no placeholder assets remain (checked by a script against `ASSETS.md`), every asset has recorded provenance, menus work with VoiceOver and the largest Dynamic Type size, Reduce Motion is honored, a pseudo-localized run shows no clipped or hard-coded text, and the frame rate holds at the game's target on the slowest supported simulator.

### G5: Quality Assurance

Test as a player would and as a hostile tester would.

**Done when:** the full test suite and a UI test of every main flow pass; a soak test plays the game for at least thirty simulated minutes with no crash, leak, or unbounded memory growth; saves survive a kill at any point and every earlier save version migrates; interruptions (calls, backgrounding, and audio route changes) are handled; and every known bug is fixed or listed in the game's `STATUS.md` with a reason it does not block launch.

### G6: Launch-Ready Gate

A game is launch-ready when everything below is true and shown:

- **Builds:** a Release build archives without errors from the tagged commit; nothing in the build depends on a debug flag.
- **Store materials** in `games/NN-<slug>/store/`: name, subtitle, description, keywords, promotional text, support text, age-rating questionnaire answers, export-compliance answer, and App Review notes. Text is original and free of claims the game cannot back up.
- **Screenshots:** generated by UI tests for every required device size, kept as files, and regenerated by a documented command.
- **App icon** in every required size and variant, generated from a checked-in source.
- **Privacy:** no analytics, advertising, or tracking SDKs; a privacy manifest; the target App Store privacy label is "Data Not Collected," or the exact label is written down if Game Center or purchases need more.
- **Purchases (if any):** every product is listed with its price tier, tested with a local StoreKit configuration file, and restore works.
- **Accessibility and localization** as in G4.
- **Licenses:** every asset and dependency is listed with its license; an in-app credits and licenses screen exists.
- **Maintainer steps** for this game (App Store Connect record, bundle identifier, signing, Game Center setup, purchase products, and pricing) are on the **Needs the Maintainer** list, worded so they can be done in one sitting.

**Done when:** every item above is checked in the game's `STATUS.md`, CI is green on the tagged commit, and the game is tagged (see [Transition Protocol](#transition-protocol)).

## Transition Protocol

This is how one game closes and the next one starts, with no human input.

### Closing a Game

1. Run `scripts/check.sh` (the full global check, not just the game). Fix anything red, in the game or in a game it broke, before going on.
2. Tag the launch-ready commit `<slug>/v1.0.0` and push the tag. Before launch-ready, a game may be tagged `<slug>/v0.B.0` at the end of a stage.
3. Write `docs/handoffs/NN-<slug>.md`: what shipped, what was cut and why, known issues, the maintainer steps for this game, engine changes it made, and lessons for the next game.
4. Update the game's `STATUS.md` (stage: G6 done) and the program `STATUS.md`: mark the game launch-ready in the queue, add its maintainer steps to **Needs the Maintainer**, write a log line, and set **Next step** to the first step of the next game.
5. Commit, push, and check CI once it has had time to run.

### Starting the Next Game

1. `git pull` to pick up any new or changed game roadmaps, and add any new ones to the queue.
2. If the number of finished or parked games is now a multiple of five, run a [Program Checkpoint](#program-checkpoints) first.
3. Pick the next game with the [Build Order](#build-order) rules, set it as the current game in `STATUS.md`, and begin its G0 in the same session.

### When Blocked

Never stall. When a step cannot be done:

- **It needs the maintainer** (an account, signing, a store setting, a paid service, or a legal page): add it to **Needs the Maintainer** with the game and stage, build everything that does not depend on it (with an offline or test stand-in where the platform allows), and go on.
- **It is a hard technical problem:** try at least three distinct approaches, recording each in the game's `STATUS.md`. If all three fail, cut or simplify the feature with a decision record, or park the item and continue with the rest of the game.
- **The whole game cannot progress:** park the game. Write its handoff note with the reason and what would unblock it, mark it **Parked** in the queue, and start the next game. Parked games are revisited at every program checkpoint and in P3.
- **CI is red:** fixing it comes before anything else, including starting a new game.

## Build Order

- The first game built is the **pilot**: the simplest game in the queue that exercises the most common engine modules (menu, settings, save, audio, and haptics). It proves the pipeline and the engine; expect to change the engine while building it.
- After the pilot, follow the order the game roadmaps give, if they give one. Otherwise, order by: (1) games that reuse engine modules already built, before games that need new ones; (2) lower risk before higher risk; (3) the game's number.
- A game whose roadmap is missing when its turn comes is skipped, not waited for.
- Record the order and any later change to it in `STATUS.md`, with a one-line reason.

## Growing the Engine

- Add an engine module or capability only when the current game needs it, and only if a second game is likely to use it; otherwise keep it in the game.
- Every engine change keeps every game that has reached G2 green. CI enforces this; run the global check before pushing an engine change.
- Engine changes are additive where possible. A breaking change updates every affected game in the same pull request or commit series.
- Tag the engine `engine/vA.B.C` when a game that needed new engine work closes out: B for new capability, C for fixes.

## Program Checkpoints

After every five games are finished or parked (5, 10, 15, 20, and 25), stop starting new work for one review, and keep it short:

- Run the full global check and the full CI run. Fix every regression in finished games first.
- Retry each parked game's blocker once; unpark any that can now move.
- Review the queue and the engine: reorder the remaining games if the engine now makes some cheaper, and cut engine code no game uses.
- Re-read the **Needs the Maintainer** list and merge or reword items so it stays short and doable in one sitting.
- Log the checkpoint in `STATUS.md`, with the number of games finished, parked, and remaining.

A checkpoint does not reopen finished games' designs, and it does not restart plan review.

## Momentum Rules

- **Always take the next concrete step.** At the end of every step, `STATUS.md` names the next one, and the next session starts there.
- **Plan review is capped.** Three passes for the program in P0, and three per game in G0. After that, plans change only when building shows they are wrong, with a decision record, and never as a new review round.
- **Small, green steps.** Commit and push after every meaningful step with CI green. Large changes go on a short-lived branch that is merged once green.
- **Cut before you stall.** When a feature threatens the schedule of a game, simplify it to the smallest version that meets the roadmap's intent, record the cut, and move on. Cut features go in the game's "After v1.0.0" list.
- **Finished games stay finished.** Changes to a launch-ready game are limited to fixing regressions, engine updates it needs to stay green, and maintainer-requested changes.

## Resuming After a Restart

`STATUS.md` must always be enough to continue exactly where the work stopped, with no memory of earlier sessions. To resume:

1. `git pull`, then read `STATUS.md` (program), then the current game's `STATUS.md` and `ROADMAP.md`, then this file's section for the current stage.
2. Run `scripts/check.sh NN` for the current game (or `scripts/check.sh engine` during P1) to confirm the tree is green.
3. Continue from **Next step**. If the working tree has uncommitted changes, decide from `STATUS.md` whether they are the step in progress; finish and commit them, or set them aside with `git stash` and note it.

Keep **Current phase**, **Current game**, **Stage**, **Last done**, **Next step**, and **Blocked on** in `STATUS.md` up to date after every step, not only at the end of a session.

## Needs the Maintainer

Only the maintainer can create the App Store Connect records, choose bundle identifiers, sign builds, set up Game Center and in-app purchase products, set prices, choose the license for original art, sound, and music, and publish legal pages. These are batched into one list in `STATUS.md`, grouped by game, each with the stage that needs it and exactly what to do. Adding an item never stops work. The list is reviewed at every program checkpoint so it stays short.

## Fixed Choices

These are the starting choices. P0 may change one, but only with a decision record.

- **Platforms:** iPhone first, iPad supported with a layout that suits it, and Mac only where a game roadmap asks for it. Minimum iOS version is set in P0 (decision 0001) and shared by every game.
- **Language and frameworks:** Swift 6, SwiftUI for menus and screens, and SpriteKit for 2D play. Metal or SceneKit only where a game roadmap needs them, with a decision record. No third-party game engines.
- **Dependencies:** Apple SDKs only, unless a decision record names a well-known, maintained Swift package and why it is needed.
- **Projects:** XcodeGen, pinned. No committed `.xcodeproj` files.
- **No tracking:** no analytics, advertising, or third-party tracking SDKs in any game.
- **License:** code is MIT OR Apache-2.0 (`LICENSE-MIT` and `LICENSE-APACHE`). The license for original art, sound, and music is a maintainer choice; until it is made, keep every asset's provenance in `ASSETS.md` so any license can be applied later.
- **Offline first:** every game is fully playable offline. Game Center and purchases are optional extras that fail gracefully.
- **Versioning:** `vA.B.C`, where A is a major release or rewrite, B a feature release, and C a fix or small change. Tags carry a prefix: `<slug>/vA.B.C` for a game, `engine/vA.B.C` for the engine, and `program/vA.B.C` for program milestones. Each game reaches `<slug>/v1.0.0` at launch-ready.

## Assets and Licensing

- Every art, sound, music, and font asset is original to this project, procedurally generated by code in this repository, or under CC0 or another license that allows commercial use with no attribution conflict. Fonts are system fonts or fonts with a license that allows embedding in apps.
- Each game's `ASSETS.md` lists every asset with its source, license, and how it was made. An asset without a record is a placeholder and fails G4.
- No asset, name, character, or mechanic copied from an existing commercial game. Game names are checked against the App Store before G6, and a name conflict is a maintainer item.

## Program Work Between Games

When no game can move (all remaining games are blocked, parked, or missing roadmaps), work on, in order: fixing regressions; engine tests and documentation; tooling that will speed up the next games (scaffolding, screenshot generation, and asset pipelines); and the store materials of launch-ready games. Then check again for new roadmaps.

## P3: Program Launch Readiness

When every game is launch-ready or parked:

- Retry every parked game one last time.
- Run the full global check and the full CI run on `main`.
- Review every game's store materials together for consistency, and check that no two games share a name, an icon, or screenshots.
- Make the **Needs the Maintainer** list final, grouped by game, ordered so the maintainer can work down it.
- Write `docs/handoffs/program.md`: games finished, games parked and why, engine version, and the order recommended for submission.

**Done when:** every game is either tagged `<slug>/v1.0.0` with its G6 checklist complete or parked with a handoff note, the full global check and CI pass on `main`, `docs/handoffs/program.md` exists, and `main` is tagged `program/v1.0.0`.

## Decisions to Record

Program-wide decisions go in `docs/decisions/` (Context, Decision, Consequences), numbered in order. P0 writes at least these:

- **0001:** minimum iOS version and device targets.
- **0002:** engine name, module list, and the rules for what belongs in the engine.
- **0003:** asset policy: sources allowed, provenance format, and how procedural assets are generated.
- **0004:** CI layout: path filters, what runs on an engine change, and the scheduled full run.

Game-specific decisions go in the game's own `docs/decisions/`.
