# Status

This file is the single place to resume the program from. Keep every field below current after every meaningful step (see "Resuming After a Restart" in `ROADMAP.md`). Per-game detail (gate evidence and sign-offs) lives in each game's `docs/STATUS.md`.

- **Current game:** none yet
- **Phase:** none
- **Last done:** program roadmap reconciled with the game roadmap set
- **Next step:** environment check (see below), then Night Market (`games/04-night-market/`) P0: read `games/_shared/_CONVENTIONS.md` and `games/04-night-market/ROADMAP.md` in full, then task S0.1 on branch `night-market/phase/P0-setup`
- **Blocked on:** nothing

## Environment Check

Do this once, before the first game's P0, and record the output here: `xcodebuild -version` (must be Xcode 26.x, `_CONVENTIONS.md` §2), `xcrun simctl list runtimes` and `xcrun simctl list devicetypes` (an iOS 26 runtime plus the simulators the snapshot and UI tests need: a 13-inch iPad Pro, an 11-inch iPad, and a 6.9-inch iPhone; `_CONVENTIONS.md` §5 and §6), `swift --version`, and `brew --version`. Install missing command-line tools with `brew install`. If Xcode 26 or the iOS 26 simulator runtime is missing and cannot be installed without an administrator, add it to **Needs the Maintainer**; no game can start until it is fixed.

- not yet run

## Game Queue

**Order** is the build order from `ROADMAP.md`; numbers and folders never change. **State** is one of the states in "Game States" in `ROADMAP.md`. **Last Gate** is the newest `<slug>/gate-Gn-pass` tag.

| Order | No. | Folder | Game | State | Last Gate | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 04 | [`04-night-market`](games/04-night-market/ROADMAP.md) | Night Market | Not Started | — | — |
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

**Totals:** 0 handed off at G5, 0 waiting on others, 0 in progress, 25 not started.

## Waiting on Others

Each game that cannot move, with exactly what it waits for (for example "G2: REVIEW: GROK and REVIEW: MAHLER in `games/04-night-market/docs/STATUS.md`"). The build agent never writes these reviews.

- none

## Needs the Maintainer

Decisions or steps only the maintainer can do. Adding an item never stops other games.

- **Bundle identifier prefix:** every roadmap uses the placeholder `com.zyniker.<slug>` (`_CONVENTIONS.md` §2). Confirm or replace it before P7. The build agent keeps the placeholder.
- **Reviews:** every game stops at G2 for `REVIEW: GROK` and `REVIEW: MAHLER`, and at G5 for `REVIEW: CLAUDE`, `REVIEW: GROK`, and `REVIEW: MAHLER`. Games resume only when those entries are recorded in the game's `docs/STATUS.md`.
- **Open questions:** each roadmap's §13 lists questions with defaults. The build agent uses the defaults; answer any you want changed in the game's `docs/OPEN_QUESTIONS.md`.

## Log

One line per meaningful step, newest last: date, phase or game and stage, what was done, and the commit.

- Program roadmap and status written.
- Decision: the whole repository is all rights reserved and stays public for reference only (`LICENSE`); third-party assets and dependencies must be permissively licensed with attribution recorded, and nothing copyleft.
- 2026-11-15: placed the twenty-five game roadmaps at `games/NN-<slug>/ROADMAP.md` and listed them in the queue. Build order not set.
- 2026-11-15: reconciled the program files with the game roadmap set (`games/_shared/`). The build agent does P0–P5 of each game, honors every stop per game, and moves to the next game; build order set in `ROADMAP.md`, Night Market first. Superseded program docs (the old template, shared engine, stages G0–G6, and launch gate) removed.
