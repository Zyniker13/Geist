# Status

This file is the single place to resume the program from. Keep every field below current after every meaningful step (see "Resuming After a Restart" in `ROADMAP.md`). Per-game detail (gate evidence and sign-offs) lives in each game's `docs/STATUS.md`.

- **Current game:** none yet
- **Phase:** none
- **Last done:** program and game roadmaps updated: the build agent owns P0–P10 of every game and never stops
- **Next step:** environment check (see below), then Night Market (`games/04-night-market/`) P0: read `games/_shared/_CONVENTIONS.md` and `games/04-night-market/ROADMAP.md` in full, then task S0.1 on branch `night-market/phase/P0-setup`
- **Blocked on:** nothing

## Environment Check

Do this once, before the first game's P0, and record the output here:

- `xcodebuild -version` must report Xcode 27.2 (`_CONVENTIONS.md` §2).
- `xcrun simctl list runtimes` must show an available iOS simulator runtime of version 26 or later.
- `xcrun simctl list devices available` must include the simulators named in "Environment" in `ROADMAP.md`.
- `swift --version`, `brew --version`, `xcodegen --version`, `swiftlint version`, and `swift-format --version`; install missing tools with `brew install`.
- `gh auth status`: if it fails, file maintainer items with the fallback in "Issues for the Maintainer" in `ROADMAP.md`.

If Xcode 27.2 or an iOS 26-or-later runtime is missing and cannot be installed without an administrator, file it as a `program` maintainer item; no game can build until it is fixed.

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

**Totals:** 0 done, 0 in progress, 25 not started.

## Needs the Maintainer

Fallback only: used when `gh` is not authenticated (see "Issues for the Maintainer" in `ROADMAP.md`). Otherwise every item is a GitHub issue labeled `needs-maintainer`. Format: `[needs-maintainer] [<slug> or program] [blocked or question, if any] Title — what is needed, why, what was done locally, and what happens next.` The maintainer answers by adding an indented line under the item.

- none

## Log

One line per meaningful step, newest last: date, phase or game and stage, what was done, and the commit.

- Program roadmap and status written.
- Decision: the whole repository is all rights reserved and stays public for reference only (`LICENSE`); third-party assets and dependencies must be permissively licensed with attribution recorded, and nothing copyleft.
- 2026-11-15: placed the twenty-five game roadmaps at `games/NN-<slug>/ROADMAP.md` and listed them in the queue. Build order not set.
- 2026-11-15: reconciled the program files with the game roadmap set (`games/_shared/`); build order set in `ROADMAP.md`, Night Market first; superseded program docs removed.
- 2026-11-15: the build agent now owns every phase, P0–P10, of every game, with self-checked gates, local substitutes for owner-only steps, and maintainer items filed as GitHub issues (fallback: Needs the Maintainer). Toolchain set to Xcode 27.2 with 26.0 deployment targets.
