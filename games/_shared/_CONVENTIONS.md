# Shared Conventions for All Strategy Game Roadmaps

Version 1.0 · 2026-11-15 · Applies to every game roadmap at `../NN-<slug>/ROADMAP.md`.

Every roadmap references this file. When a roadmap and this file disagree, **the roadmap wins for game-specific facts** (rules, content, modules) and **this file wins for process, stack, standards, and gates**. The build agent must read this file in full before starting P0 of any game.

---

## 1. Roles and Sign-Off Codes

| Code | Who | Responsibility |
| --- | --- | --- |
| `GLM` | Autonomous GLM coding agent | Initial build, P0 through P5. Self-checks gates marked `GLM-SELF`. |
| `CLAUDE` | Claude agent | Architecture and code-quality review, refactors, platform integration, accessibility. Leads P7 and P8. |
| `GROK` | Grok agent | Design, balance, content, and AI-opponent review. Leads P5 tuning, P6 direction support, and P9 balance. |
| `MAHLER` | Human owner | Feel, taste, and go/no-go. Only Mahler approves anything external: App Store Connect records, TestFlight external groups, App Store submission, pricing, spending money, or posting publicly. |

Gate sign-off notation used in every roadmap:

- `GLM-SELF` — GLM runs the checks itself, records results in `docs/STATUS.md`, and continues if all pass.
- `REVIEW: CLAUDE` / `REVIEW: GROK` — the named agent must review and write a signed entry in `docs/STATUS.md`.
- `REVIEW: MAHLER` — the human must play the build and approve.
- `🛑 GLM STOP` — GLM must stop all work, write `docs/HANDOFF.md` for the current state, and wait. It must not start the next phase.

### 1.1 Where GLM Stops (Same for Every Game)

1. **G2 (Vertical Slice)** is a `🛑 GLM STOP`. GLM resumes P3 only after `REVIEW: GROK` and `REVIEW: MAHLER` are recorded as PASS in `docs/STATUS.md`.
2. **G5 (Meta and Replayability)** is the **final GLM handoff**: `🛑 GLM STOP`. P6 through P10 belong to Claude and Grok, with Mahler approval.
3. GLM must also stop immediately (and write `docs/HANDOFF.md`) when:
   - a gate check fails three consecutive fix attempts;
   - any task would require an Apple Developer account action, signing certificates, App Store Connect, payment, or a third-party account;
   - a design ambiguity would change a rule in `docs/RULES.md` (log it in `docs/OPEN_QUESTIONS.md` instead of guessing, unless the roadmap lists a default);
   - a dependency outside the allow-list (§4.4) seems necessary.

---

## 2. Fixed Technology Stack (Do Not Re-Decide)

| Concern | Decision | Rationale |
| --- | --- | --- |
| Language | Swift 6, strict concurrency `complete` | First-party, one language across iPad, iPhone, and Mac; strong typing suits deterministic rules. |
| Toolchain | Latest stable Xcode 26.x; record the exact version in `docs/DECISIONS.md` (ADR-0001) | Reproducible builds. |
| Deployment targets | iOS and iPadOS 26.0, macOS 26.0 | Unlocks Game Center challenges in the Apple Games app, current Pencil APIs, and Metal 4; acceptable reach by launch. |
| App shell and menus | SwiftUI multiplatform app (one app target per platform from one source set) | Native Mac menus, windows, and pointer behavior without Catalyst compromises. |
| 2D rendering (default) | SpriteKit hosted in SwiftUI via `SpriteView` | Mature, built in, enough for every 2D concept; supports custom `SKShader` for effects. |
| 3D rendering | RealityKit via `RealityView` (only where the roadmap says 3D) | Apple's maintained 3D path; SceneKit is not used. |
| Custom GPU work | Metal 4 via MetalKit `MTKView` (only where the roadmap says so, e.g. lighting, ink, or flocking compute) | Performance-critical effects. |
| Audio | AVAudioEngine (music, layered stems, procedural audio) plus `AVAudioPlayerNode` pools for SFX | Low latency and sample-accurate scheduling. |
| Haptics | Core Haptics with AHAP files in `Resources/Haptics/` | Rich, data-driven haptics. |
| Persistence | Codable JSON save files; `FileManager` in Application Support, mirrored to iCloud via `NSUbiquitousKeyValueStore` (small data) and CloudKit private database or iCloud Drive documents (save files) | Simple, debuggable, cross-device. |
| Online and social | GameKit: leaderboards, achievements, challenges, and turn-based matches where the roadmap says so | No custom servers in any roadmap. |
| Project generation | XcodeGen (`project.yml`); the `.xcodeproj` is generated and git-ignored | Agents must never hand-edit `project.pbxproj`. |
| Packages | Swift Package Manager local packages under `Packages/` | Pure-Swift cores are testable on the command line with `swift test`. |
| Tests | Swift Testing (`import Testing`) for packages; XCTest/XCUITest for UI tests; `swift-snapshot-testing` for rendering snapshots | Modern, parallel, parameterized tests. |
| Lint and format | SwiftLint (config in repo) and `swift-format` | Consistent style for three different agents. |
| CI | GitHub Actions, `macos-26` runner (or latest available macOS runner); see §6 | Every gate is checkable by CI. |
| Monetization (default) | Premium, one price, universal purchase across iPhone, iPad, and Mac; no ads, no consumables | Matches the research; keeps Apple Arcade pitches possible. Pricing is a `MAHLER` decision. |

Universal purchase: iOS and macOS apps share **one bundle identifier** `com.zyniker.<slug>` (placeholder; Mahler confirms the reverse-DNS prefix) and are added as platforms of one App Store Connect record. GLM never creates that record.

---

## 3. Repository Layout (Every Game)

> **This repository:** all twenty-five games share one repository, so `<slug>/` below is the game's folder, `games/NN-<slug>/`. "Repository Adaptations" in the root `ROADMAP.md` maps the CI file, branches, tags, and merging, and "Program Loop" there says how a stop applies to one game at a time.

```
<slug>/
├── project.yml                  # XcodeGen spec (iOS app, macOS app, UI test targets)
├── Makefile                     # make bootstrap | gen | build | test | lint | snapshot | perf | coverage
├── .swiftlint.yml
├── .swift-format
├── .github/workflows/ci.yml
├── App/
│   ├── Shared/                  # SwiftUI scenes, navigation, settings, shared views
│   ├── iOS/                     # iOS-only entry, Info.plist, entitlements
│   └── macOS/                   # macOS-only entry, menus/commands, Info.plist, entitlements
├── Packages/
│   ├── <Prefix>Core/            # Pure Swift rules engine. NO import of SwiftUI/SpriteKit/UIKit/AppKit/GameKit.
│   ├── <Prefix>Content/         # Content tables (JSON) + typed loaders + validation
│   ├── <Prefix>AI/              # Opponents, solvers, and bots. Depends only on Core and Content.
│   ├── <Prefix>Render/          # SpriteKit/RealityKit/Metal scenes and nodes. Reads Core state, never mutates it directly.
│   ├── <Prefix>Audio/           # AVAudioEngine graph, music system, SFX
│   ├── <Prefix>Platform/        # GameKit, iCloud, Pencil, haptics adapters behind protocols
│   └── <Prefix>Meta/            # Progression, unlocks, daily seeds, stats
├── Resources/
│   ├── Content/                 # *.json tables (source of truth for balance)
│   ├── Art/                     # Asset catalogs, atlases
│   ├── Audio/                   # Stems and SFX (CAF/m4a)
│   ├── Haptics/                 # *.ahap
│   └── Localization/            # String Catalogs (*.xcstrings)
├── Tools/
│   ├── sim/                     # Headless CLI: run N seeded games, AI vs AI, balance reports
│   └── content-lint/            # Validates all JSON against schemas
├── Tests/
│   ├── UITests/                 # XCUITest smoke flows
│   └── Snapshots/               # Reference images
└── docs/
    ├── RULES.md                 # Authoritative rules spec (copied from roadmap §4, then maintained)
    ├── ARCHITECTURE.md
    ├── DECISIONS.md             # ADR log (ADR-0001 …)
    ├── STATUS.md                # Phase/gate tracker with sign-offs
    ├── KNOWN_ISSUES.md
    ├── TODO_MAP.md
    ├── COVERAGE.md
    ├── OPEN_QUESTIONS.md
    ├── PERF.md
    └── HANDOFF.md
```

Each roadmap defines `<Prefix>` (two to four letters, e.g. `CG` for Cartographer's Gambit) and may add game-specific modules **inside** these packages; it never adds new top-level packages unless the roadmap says so.

### 3.1 Dependency Direction (Enforced)

`Core` ← `Content` ← `AI` ← `Meta` ← `Render`/`Audio`/`Platform` ← `App`. `Core` depends on nothing but the Swift standard library and Foundation (`Foundation` only for `Codable`/`Data`; no `Date()` reads, no `UUID()` generation inside rules). A CI script (`Tools/check-imports.sh`) fails the build if `Core`, `Content`, or `AI` import any UI or platform framework.

---

## 4. Coding Standards

### 4.1 Naming
- Types `UpperCamelCase`; functions and properties `lowerCamelCase`; files named after their primary type.
- Rules types are nouns (`Board`, `Move`, `GameState`); rule functions are verbs (`apply(_:)`, `legalMoves(for:)`).
- Content IDs are `snake_case` strings, stable forever once shipped (`nib_fine_point`).
- Test names describe behavior: `@Test("River blocks supply for both factions")`.

### 4.2 Deterministic Rules Engine (Non-Negotiable)
1. `GameState` is a value type (`struct`, `Codable`, `Equatable`, `Hashable`, `Sendable`).
2. All state changes go through one pure reducer: `func apply(_ action: Action, to state: GameState, rng: inout SeededRNG) throws(RuleError) -> (GameState, [Event])`.
3. Randomness uses only `SeededRNG` (Xoshiro256** seeded through SplitMix64), stored in the state or passed explicitly. `SystemRandomNumberGenerator`, `Int.random(in:)` without an explicit generator, `Date()`, and `UUID()` are banned in `Core`, `Content`, and `AI` (SwiftLint custom rule).
4. Rules math uses `Int` or the shared fixed-point type `Fixed` (Q32.32 in `Int64`). `Float`/`Double` are banned in `Core` except in debug-only formatting. Real-time simulations step at a fixed tick (default 30 ticks/second) with integer or fixed-point math, so a replay of the same seed and inputs yields byte-identical state on every device.
5. Every game supports `Replay { seed, contentVersion, actions: [TimedAction] }` and a test that replays it to a known final-state hash.
6. Rendering and audio subscribe to `[Event]` emitted by the reducer; they never infer rules.

### 4.3 General
- No force unwraps outside tests; no `fatalError` in shipping paths except unreachable `switch` defaults with a message.
- Public APIs of packages carry `///` doc comments.
- Functions longer than 60 lines or types longer than 400 lines need a justification comment or a split.
- Every user-facing string goes through String Catalogs; ship English (US) first.
- Accessibility identifiers on every interactive control (`"board.cell.3.4"`), used by UI tests.

### 4.4 Dependency Allow-List
Only: `pointfreeco/swift-snapshot-testing` (tests only), `apple/swift-collections`, `apple/swift-algorithms`, `apple/swift-numerics` (Render/Audio only), XcodeGen, SwiftLint, and swift-format as tools. Anything else requires an ADR and `REVIEW: CLAUDE`.

---

## 5. Testing Requirements

| Layer | Requirement | Gate threshold |
| --- | --- | --- |
| Core (rules) | Unit tests for every rule in `docs/RULES.md` (one or more tests per numbered rule ID, tagged with that ID) | ≥ 90% line coverage |
| Core determinism | Golden replay tests: 20 seeded replays per game with stored final-state hashes; property tests (≥ 1,000 random seeds) for invariants listed in the roadmap | 100% pass |
| Content | `content-lint` validates every JSON file against its schema; referential integrity (no dangling IDs) | 0 errors |
| AI | Unit tests for evaluation functions; headless AI-vs-AI soak (≥ 500 games per difficulty) with no crashes, no illegal moves, and the time budget respected | 0 illegal moves; p95 think time within budget |
| Render | Snapshot tests of key scenes at iPad 13", iPad 11", iPhone 6.9", and Mac 1440×900 in light/dark where relevant | No unreviewed diffs |
| UI | XCUITest smoke: launch → tutorial → play first match/run to completion with scripted inputs → results screen | Pass on iPad and Mac |
| Performance | XCTest `measure` and Instruments signposts; see §7 | Meets §7 |
| Overall | Line coverage across packages | ≥ 60% (Core ≥ 90%, AI ≥ 75%, Meta ≥ 75%) |

Coverage is generated with `xcrun xccov` / `swift test --enable-code-coverage` and summarized into `docs/COVERAGE.md` by `make coverage`.

---

## 6. CI Expectations

> **This repository:** the workflow is `.github/workflows/<slug>.yml` at the repository root, branches are `<slug>/phase/Pn-short-name`, tags are `<slug>/gate-Gn-pass`, and the build agent merges with a normal push after local checks and branch CI pass; see "Repository Adaptations" in the root `ROADMAP.md`.

`.github/workflows/ci.yml` runs on every push and pull request:
1. `make bootstrap` (install XcodeGen, SwiftLint, and swift-format via Homebrew, cached).
2. `make lint` — SwiftLint `--strict` and swift-format lint; zero warnings.
3. `Tools/check-imports.sh` — dependency direction (§3.1).
4. `make content-lint`.
5. `swift test --parallel --enable-code-coverage` for each package in `Packages/`.
6. `make gen && xcodebuild build` for the iOS (iPad simulator) and macOS schemes, warnings as errors.
7. `xcodebuild test` for snapshot and UI tests on one iPad simulator (latest iPad Pro 13") and macOS.
8. `make sim N=200` — headless seeded AI-vs-AI smoke; fails on any crash, illegal move, or determinism mismatch.
9. Upload coverage summary and sim report as artifacts.

Branching: `main` is always green. GLM works on `phase/Pn-short-name` branches, merges to `main` via PR only when the phase's tests pass, and tags `gate-Gn-pass` when a gate passes. Commits use Conventional Commits (`feat(core): add river supply rule R-12`).

---

## 7. Performance and Quality Budgets (Default; Roadmaps May Tighten)

| Metric | Target | Device class |
| --- | --- | --- |
| Frame rate (gameplay) | 120 fps sustained on ProMotion, p99 frame time ≤ 8.3 ms | iPad Pro (M4 or newer) |
| Frame rate floor | 60 fps sustained, p99 ≤ 16.7 ms | iPad (A16) and iPad mini (A17 Pro) |
| Mac | 120 fps on ProMotion displays, 60 fps on others | Any Apple silicon Mac |
| Cold start to interactive main menu | < 2.0 s | iPad (A16) |
| Resume a saved game | < 1.0 s | iPad (A16) |
| Memory (resident) | < 1.0 GB (2D games), < 1.5 GB (3D games) | iPad (A16) |
| App download size | < 300 MB (2D), < 600 MB (3D) | — |
| AI think time | Per roadmap; default p95 < 1.5 s on iPad (A16) | — |
| Thermal | No `serious` thermal state within 30 minutes of play | iPad (A16) |
| Crash-free sessions (beta) | ≥ 99.5% | TestFlight |

Measure with Instruments (Time Profiler, Game Performance template, and Metal System Trace) and record results in `docs/PERF.md` with device, OS, build, and date.

---

## 8. The Shared Phase and Gate Model

Every roadmap uses these eleven phases. Standard tasks (`S` prefix) apply to every game; roadmaps add game-specific tasks with the game prefix (e.g. `CG-P1.3`).

| Phase | Name | Owner | Gate | Sign-off |
| --- | --- | --- | --- | --- |
| P0 | Setup | GLM | G0 | GLM-SELF |
| P1 | Rules Engine Prototype | GLM | G1 | GLM-SELF |
| P2 | Core Loop Vertical Slice | GLM | G2 | REVIEW: GROK + MAHLER · 🛑 GLM STOP |
| P3 | Content and Systems | GLM | G3 | GLM-SELF + REVIEW: CLAUDE (async, non-blocking) |
| P4 | AI Opponents | GLM | G4 | GLM-SELF |
| P5 | Meta and Replayability | GLM | G5 | REVIEW: CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP |
| P6 | Aesthetics and Audio Pass | GROK + CLAUDE | G6 | REVIEW: MAHLER |
| P7 | Platform Features (Pencil, Game Center, iCloud, Mac) | CLAUDE | G7 | REVIEW: GROK |
| P8 | Polish, Accessibility, and Performance | CLAUDE | G8 | REVIEW: GROK + MAHLER |
| P9 | Beta and TestFlight | GROK + CLAUDE | G9 | REVIEW: MAHLER |
| P10 | Release Prep | CLAUDE + GROK | G10 | REVIEW: MAHLER (only Mahler submits) |

GLM may build **placeholder** art, audio, and Pencil/Game Center stubs earlier when a slice needs them, but the P6/P7 owners replace them.

### 8.1 Standard Tasks

**P0 Setup**
- S0.1 Create the repo layout in §3 with `project.yml`, `Makefile`, lint configs, and empty packages that compile.
- S0.2 Implement `SeededRNG` (Xoshiro256**/SplitMix64) and `Fixed` (Q32.32) in `<Prefix>Core/Foundation/` with tests (known-answer vectors).
- S0.3 Add `Tools/check-imports.sh`, SwiftLint custom rules for banned APIs (§4.2), and `content-lint` skeleton.
- S0.4 Add CI workflow (§6); it must be green on an empty app that launches to a placeholder menu on iPad and Mac.
- S0.5 Create all `docs/` files with headings; copy roadmap §4 into `docs/RULES.md` with rule IDs intact; write ADR-0001 (toolchain) and ADR-0002 (stack per §2).
- S0.6 Add `Replay` type and a golden-replay test harness (initially with a trivial state).
- S0.7 Add an in-app debug overlay (FPS, tick, seed, state hash) toggled by a three-finger double tap on iPad and ⌘⇧D on Mac.

**G0 checks (GLM-SELF):** CI green; `make test` passes; app launches on iPad simulator and macOS; banned-API lint triggers on a deliberate violation in a test fixture; docs skeleton present.

**P1 Rules Engine Prototype**
- S1.1 Implement the full `GameState`, `Action`, `Event`, and reducer for the rules in roadmap §4 (no UI).
- S1.2 One or more tests per rule ID; property tests for the roadmap's invariants.
- S1.3 Headless CLI `Tools/sim` that plays random-legal-move games from a seed and prints a summary and final hash.
- S1.4 Ten golden replays committed.

**G1 checks (GLM-SELF):** every rule ID has a passing test; Core coverage ≥ 90%; `make sim N=1000` completes with 0 crashes, 0 illegal states, and identical hashes on two runs; no banned APIs.

**P2 Core Loop Vertical Slice**
- S2.1 One playable mode on iPad and Mac with placeholder art in the intended palette, the primary touch interaction from the roadmap, and a mouse equivalent.
- S2.2 Basic HUD, pause, restart, and results screen.
- S2.3 One basic opponent or challenge source (simple heuristic AI or scripted scenario).
- S2.4 Save and resume mid-game (local only).
- S2.5 Build a 60-second screen recording via XCUITest + `simctl io recordVideo`, saved to `docs/media/slice.mp4`.

**G2 checks:** XCUITest plays a full match/run to the results screen on iPad and Mac; 60 fps on iPad simulator debug overlay (real-device perf comes later); the roadmap's slice-specific checks. Then `🛑 GLM STOP` for `REVIEW: GROK` (does the core decision space feel interesting?) and `REVIEW: MAHLER` (is it fun enough to continue?). Possible outcomes: PASS, PASS WITH CHANGES (listed in `docs/STATUS.md`), or PIVOT (roadmap revised before P3).

**P3 Content and Systems** — roadmap-specific content to the counts in §5 of each roadmap; all content in JSON; `content-lint` clean; tutorial flow scripted.

**P4 AI Opponents** — difficulty tiers per roadmap §7; time budgets enforced; AI-vs-AI soak; win-rate bands recorded in `docs/BALANCE.md`.

**P5 Meta and Replayability** — run structure, unlocks, daily seed (date-derived, UTC, deterministic), statistics, and local leaderboards ready to bind to Game Center in P7.

**G5 checks:** roadmap-specific; plus all standard tests, coverage thresholds in §5, a complete `docs/HANDOFF.md` (§9), and `🛑 GLM FINAL STOP`.

**P6 Aesthetics and Audio Pass** — final art direction, shaders, animation, music, SFX, and haptics per roadmap §1 aesthetic spec.

**P7 Platform Features** — Pencil (hover preview, squeeze palette, pressure where specified, always with a finger fallback), Game Center (auth, leaderboards, achievements, challenges, turn-based where specified), iCloud save sync with conflict resolution, Mac menus/keyboard shortcuts/window resizing, controller support where specified.

**P8 Polish, Accessibility, and Performance** — VoiceOver labels, Dynamic Type in menus, Reduce Motion, color-blind-safe palettes (verify with simulated deuteranopia/protanopia/tritanopia), adjustable text size, left-handed layout, haptics toggle, and performance budgets in §7 on real devices.

**P9 Beta and TestFlight** — internal TestFlight first, then an external group only after `MAHLER` approves; crash and feedback triage; balance passes driven by telemetry-free in-game opt-in stats export.

**P10 Release Prep** — App Store metadata drafts, screenshots for all sizes, app preview video, privacy nutrition label (target: Data Not Collected), age rating questionnaire draft, accessibility nutrition labels, press kit. Mahler submits.

---

## 9. Handoff Package (What GLM Leaves Behind at Every 🛑 STOP)

`docs/HANDOFF.md` must contain, in this order:
1. **State summary** — phase, last passed gate, branch, commit SHA, and tag.
2. **How to build and run** — exact commands from a clean clone.
3. **Architecture** — link to `docs/ARCHITECTURE.md` (module diagram, data flow from input → Action → reducer → Events → render/audio, threading model, save format).
4. **Decision log** — link to `docs/DECISIONS.md`; every deviation from the roadmap is an ADR.
5. **Known issues** — `docs/KNOWN_ISSUES.md`, each with severity (S1 crash/data loss, S2 wrong rule, S3 visual/UX, S4 minor), reproduction steps, and a suspected cause.
6. **TODO map** — `docs/TODO_MAP.md`, generated by `make todo` from `// TODO(<ID>):` comments, grouped by package; every TODO carries a task ID.
7. **Test coverage report** — `docs/COVERAGE.md` per package with uncovered critical functions listed.
8. **Balance snapshot** — `docs/BALANCE.md` with sim results (win rates by faction/difficulty, average game length, and outliers).
9. **Open questions** — `docs/OPEN_QUESTIONS.md` with the default GLM chose (if any) and why.
10. **Gate evidence** — check-by-check pass/fail table with command output excerpts and media links.

---

## 10. Effort Units

Estimates in roadmaps use **engineer-days (ed)**: one focused experienced Swift engineer day. Agent wall-clock varies; treat ed as relative sizing. Each roadmap gives a per-phase range and a total.

---

## 11. Writing Style for Docs

Title Case headings, American English, and the serial (Oxford) comma in every list of three or more.
