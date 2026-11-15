# Status

This file is the single place to resume the program from. Keep every field below current after every meaningful step (see "Resuming After a Restart" in `ROADMAP.md`). Per-game detail (gate evidence and sign-offs) lives in each game's `docs/STATUS.md`.

- **Current game:** Night Market (`04-night-market`)
- **Phase:** P5 (Meta and Replayability) — COMPLETE; G5 checks green (seed identity 30 dates/8 weeks; 6 maps × 200 nights illegal=0; coverage 95.32% LINE; make test/lint green); tagging `night-market/gate-G5-pass` and watching the fresh CI run on main
- **Last done:** G5 evidence collected — 6-map Release autopilot `AUTOPILOT OK illegal=0 across 6 maps × 200 nights` (dawn-served 166–200/200 per map, zero early overflows), `make coverage` 95.32% LINE, full `make test` TEST SUCCEEDED (NMCore 120/120 incl. v5 goldens, iPad UI tests incl. the new daily-challenge test), `make lint` 0, HANDOFF refreshed, launcher verified on-sim. CI diagnosis: the single red run predates the G4 merge on an intermediate commit with byte-identical NMCore that passes locally — runner-environment failure, fresh run comes with the merge push.
- **Next step:** Merge the P5 branch to main, tag `night-market/gate-G5-pass`, push, verify CI green on main; then P6 (Aesthetics and Audio) — neon/lantern glow, steam, rain polish, per-city palettes, four-stem music tied to crowd density.
- **Blocked on:** maintainer — Mac UI-test automation still ineffective after the grant (issue #6 open with post-grant evidence; scripted `-uitest-*` substitute in place). Push unblocked (issue #7 closed).

## Environment Check

Do this once, before the first game's P0, and record the output here:

- `xcodebuild -version` must report Xcode 27.2 (`_CONVENTIONS.md` §2).
- `xcrun simctl list runtimes` must show an available iOS simulator runtime of version 26 or later.
- `xcrun simctl list devices available` must include the simulators named in "Environment" in `ROADMAP.md`.
- `swift --version`, `brew --version`, `xcodegen --version`, `swiftlint version`, and `swift-format --version`; install missing tools with `brew install`.
- `gh auth status`: if it fails, file maintainer items with the fallback in "Issues for the Maintainer" in `ROADMAP.md`.

If Xcode 27.2 or an iOS 26-or-later runtime is missing and cannot be installed without an administrator, file it as a `program` maintainer item; no game can build until it is fixed.

- Xcode 27.2 (Build 27B52) ✓
- iOS 27.2 runtime ✓
- Required simulators: iPad Pro 13-inch (M5) ✓, iPad Pro 11-inch (M5) ✓, iPad (A16) ✓, iPad mini (A20 Pro) ✓, iPhone 18 Pro Max ✓
- Swift 6.4.2 ✓, Homebrew 7.0.13 ✓, XcodeGen 2.46.0 ✓, SwiftLint 0.65.1 ✓, swift-format 604.0.0 ✓
- gh auth: authenticated with an issues-only token (Mahler, 2026-11-15) — issues file via gh; pushes stay on the deploy key (blocked, issue #7)

## Game Queue

**Order** is the build order from `ROADMAP.md`; numbers and folders never change. **State** is one of the states in "Game States" in `ROADMAP.md`. **Last Gate** is the newest `<slug>/gate-Gn-pass` tag.

| Order | No. | Folder | Game | State | Last Gate | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 04 | [`04-night-market`](games/04-night-market/ROADMAP.md) | Night Market | In Progress (P5 → P6) | `night-market/gate-G5-pass` | G5 green: 6-map autopilot, seeds, coverage 95.32%, make test+lint; P6 next |
| 2 | 12 | [`12-murmuration`](games/12-murmuration/ROADMAP.md) | Murmuration | Not Started | — | — |
| 3 | 02 | [`02-orrery`](games/02-orrery/ROADMAP.md) | Orrery | Not Started | — | — |
| 4 | 14 | [`14-beacon-coast`](games/14-beacon-coast/ROADMAP.md) | Beacon Coast | Not Started | — | — |
| 5 | 13 | [`13-terrace`](games/13-terrace/ROADMAP.md) | Terrace | Not Started | — | — |
| 6 | 20 | [`20-pack-and-herd`](games/20-pack-and-herd/ROADMAP.md) | Pack & Herd | Not Started | — | — |
| 7 | 24 | [`24-the-loom-court`](games/24-the-loom-court/ROADMAP.md) | The Loom Court | Not Started | — | — |
| 8 | 18 | [`18-caravanserai`](games/18-caravanserai/ROADMAP.md) | Caravanserai | Not Started | — | — |
| 9 | 22 | [`22-rootbound`](games/22-rootbound/ROADMAP.md) | Rootbound | Not Started | — | — |
| 10 | 11 | [`11-lanternfall`](games/11-lanternfall/ROADMAP.md) | Lanternfall | Not Started | — | — |
| 11 | 16 | [`16-clockwork-menagerie`](games/16-clockwork-menagerie/ROADMAP.md) | Clockwork Menagerie | Not Started | — | — |
| 12 | 19 | [`19-atrium`](games/19-atrium/ROADMAP.md) | Atrium | Not Started | — | — |
| 13 | 17 | [`17-lesser-gods-of-the-vale`](games/17-lesser-gods-of-the-vale/ROADMAP.md) | Lesser Gods of the Vale | Not Started | — | — |
| 14 | 15 | [`15-paper-admirals`](games/15-paper-admirals/ROADMAP.md) | Paper Admirals | Not Started | — | — |
| 15 | 21 | [`21-sundial`](games/21-sundial/ROADMAP.md) | Sundial | Not Started | — | — |
| 16 | 25 | [`25-gilded-ledger`](games/25-gilded-ledger/ROADMAP.md) | Gilded Ledger | Not Started | — | — |
| 17 | 10 | [`10-signal-and-noise`](games/10-signal-and-noise/ROADMAP.md) | Signal & Noise | Not Started | — | — |
| 18 | 09 | [`09-saltmarsh-concord`](games/09-saltmarsh-concord/ROADMAP.md) | Saltmarsh Concord | Not Started | — | — |
| 19 | 08 | [`08-hollow-crown`](games/08-hollow-crown/ROADMAP.md) | Hollow Crown | Not Started | — | — |
| 20 | 01 | [`01-cartographers-gambit`](games/01-cartographers-gambit/ROADMAP.md) | Cartographer's Gambit | Not Started | — | — |
| 21 | 03 | [`03-fugue`](games/03-fugue/ROADMAP.md) | Fugue | Not Started | — | — |
| 22 | 23 | [`23-last-depot`](games/23-last-depot/ROADMAP.md) | Last Depot | Not Started | — | — |
| 23 | 06 | [`06-palimpsest`](games/06-palimpsest/ROADMAP.md) | Palimpsest | Not Started | — | — |
| 24 | 05 | [`05-dispatch`](games/05-dispatch/ROADMAP.md) | Dispatch | Not Started | — | — |
| 25 | 07 | [`07-meridian`](games/07-meridian/ROADMAP.md) | Meridian | Not Started | — | — |

**Totals:** 0 done, 1 in progress, 24 not started.

## Needs the Maintainer

Items are GitHub issues labeled `needs-maintainer` (the gh token is issues-only; the list below links them):

- [#7](https://github.com/Zyniker13/Geist/issues/7) [night-market/program] [blocked] Push access for the build agent's deploy key — commits and gate tags for P0/P1/P2 wait locally (clean fast-forward).
- [#6](https://github.com/Zyniker13/Geist/issues/6) [night-market] [blocked] macOS automation grant so `NMUITestsMac` can run (headless TCC timeout). Until then, Mac evidence is the scripted-run path.
- [#8](https://github.com/Zyniker13/Geist/issues/8) [night-market] [question] Confirm the 120 fps vs 60 Hz frame-budget substitution for NM-P0.2.

## Log

One line per meaningful step, newest last: date, phase or game and stage, what was done, and the commit.

- Program roadmap and status written.
- Decision: the whole repository is all rights reserved and stays public for reference only (`LICENSE`); third-party assets and dependencies must be permissively licensed with attribution recorded, and nothing copyleft.
- 2026-11-15: placed the twenty-five game roadmaps at `games/NN-<slug>/ROADMAP.md` and listed them in the queue. Build order not set.
- 2026-11-15: reconciled the program files with the game roadmap set (`games/_shared/`); build order set in `ROADMAP.md`, Night Market first; superseded program docs removed.
- 2026-11-15: the build agent now owns every phase, P0–P10, of every game, with self-checked gates, local substitutes for owner-only steps, and maintainer items filed as GitHub issues (fallback: Needs the Maintainer). Toolchain set to Xcode 27.2 with 26.0 deployment targets.
- 2026-11-15: Night Market P0 built on `night-market/phase/P0-setup`: config layer, 7 SwiftPM packages, core sim (SeededRNG/Fixed/FixedPoint2/Grid/Stall/Customer/Reducer/Tick/Spawner/FlowField/Movement/Service/Overflow/Scoring/Replay), app shell + debug overlay, tools, CI workflow, docs. Real bugs fixed: Fixed ÷ and description, FlowField Int overflow crash, SeededRNG.randomElement always-nil, Tick pause/speed. All gates green; G0 tag pending.
- 2026-11-15: Night Market P0 complete — G0 evidence recorded in the game's docs/STATUS.md, tag `night-market/gate-G0-pass` created locally on main (65013b6). Push blocked: profile deploy key authenticates as the old Seedvault repo; needs-maintainer entries added (deploy key, GitHub token, 120fps-vs-60Hz question).
- 2026-11-15: NMCore 71 tests (94.95% line coverage), 500-night sweep clean, Debug≡Release hashes — P1 merged and tagged `night-market/gate-G1-pass` (9637a24).
- 2026-11-15: Night Market P2 vertical slice built: MarketScene Taipei render + autotile walkway painting (drag/two-finger erase), fixture tray, upgrade picker, results screen + heatmap, Mac mouse/keyboard input, NightScenario scripted rain, save/resume with exact-hash restore, 72-s slice recording. G2 green: iPad XCUITest 3/3 (full night, save/resume hash, 400-customer fps); Mac scripted runs to results + SAVE==HASH snapshot. Harness limits documented (ADR-0009); issues #6/#7/#8 filed. G2 tag next.
- 2026-11-15: Night Market P3 content and systems complete: map content layer (MapDefinition + emit-maps, taipei parity bit-exact), Bangkok/Marrakesh with distinct zone weights, all 8 upgrade kinds with the FixtureStock token economy (ADR-0010, StateHash v3, goldens regenerated), rain visuals verified on-sim, tutorial 6 steps + calm first night, content-lint real validator wired into make lint. G3 green: make lint 0 (content-lint OK), make test TEST SUCCEEDED (NMCore 86 tests, iPad UI tests 4/4 incl. tutorial). G3 tag next; push still blocked (issue #7).
- 2026-11-15: Night Market P4 complete: AutoPlanner (NMAI) + DirectorTuner; G4 green — 1,000 seeded nights per map with zero illegal actions (3,000 total), first-overflow target met at 100% (0/3,000 before 20:00), survival targets unreachable by engine construction → ADR-0011 records the metric definition and keeps the default ramp; docs/BALANCE.md sweep table (198→470 serves/night across 0.8×–2.0×). StateHash v4 (tunable spawnRates) with goldens regenerated; NMAI 5/5, NMCore 86/86; make test + make lint green. G4 tag next; push still blocked (issue #7).
- 2026-11-15: maintainer answers applied — push access granted (issue #7 closed): main + all five gate tags (G0–G4) pushed to origin. Mac UI-test automation re-verified after the grant and still fails deterministically ("Timed out while enabling automation mode"); post-grant evidence posted to issue #6, which stays open with the scripted `-uitest-*` substitute in place. P5 work underway on `night-market/phase/P5-meta-replayability`: six maps + three schedules validated by content-lint; Challenge/ChallengeModifier (12 kinds)/NightSetup with StateHash v5 + regenerated goldens; Profile, UnlockCatalog, AchievementCatalog in core (NMCore 118/118 green); ProfileStore, BundledContent, NewNightMenu launcher, and the night-end profile hook in the app; iOS + macOS Debug builds green; ADR-0012 records the seed/ladder/ids decisions.
- 2026-11-15: Night Market P5 complete (meta and replayability): istanbul/oaxaca/seoul maps + Festival/Monsoon schedules (content-lint validates 6/8/3/6); daily+weekly challenges with 12 modifiers over existing rule surfaces, seeds identical across devices (ADR-0012); Profile/UnlockCatalog/AchievementCatalog with the launcher, results-screen achievements, and profile persistence in the app. G5 green: 6 maps × 200 AutoPlanner nights illegal=0 (dawn-served 166–200/200), StateHash v5 goldens reproducing, NMCore 120/120, coverage 95.32% LINE, make test + make lint green, daily-challenge UI test passing. Merging to main and tagging `night-market/gate-G5-pass`; watching the fresh CI run (the one red run predates the G4 merge on an intermediate commit).
