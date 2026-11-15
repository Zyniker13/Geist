# Status

This file is the single place to resume the program from. Keep every field below current after every meaningful step (see "Resuming After a Restart" in `ROADMAP.md`).

- **Current phase:** P0 (Program Review): not started
- **Current game:** none yet
- **Stage:** none
- **Last done:** twenty-five game roadmaps placed at `games/NN-<slug>/ROADMAP.md`
- **Next step:** P0 pass 1 (achievability and order): read `ROADMAP.md`, `AGENTS.md`, `docs/game-roadmap-template.md`, and every game roadmap under `games/`, then revise
- **Blocked on:** nothing

## Game Queue

Numbers are fixed once given; **Order** is the build order (see "Build Order" in `ROADMAP.md`). Fill one row per game roadmap as it arrives. **State** is one of: Waiting for Roadmap, Queued, G0 to G6, Launch-Ready, or Parked.

| No. | Folder | Working Name | Order | State | Latest Tag | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | `01-cartographers-gambit` | Cartographer's Gambit | — | Queued | — | |
| 02 | `02-orrery` | Orrery | — | Queued | — | |
| 03 | `03-fugue` | Fugue | — | Queued | — | |
| 04 | `04-night-market` | Night Market | — | Queued | — | |
| 05 | `05-dispatch` | Dispatch | — | Queued | — | |
| 06 | `06-palimpsest` | Palimpsest | — | Queued | — | |
| 07 | `07-meridian` | Meridian | — | Queued | — | |
| 08 | `08-hollow-crown` | Hollow Crown | — | Queued | — | |
| 09 | `09-saltmarsh-concord` | Saltmarsh Concord | — | Queued | — | |
| 10 | `10-signal-and-noise` | Signal & Noise | — | Queued | — | |
| 11 | `11-lanternfall` | Lanternfall | — | Queued | — | |
| 12 | `12-murmuration` | Murmuration | — | Queued | — | |
| 13 | `13-terrace` | Terrace | — | Queued | — | |
| 14 | `14-beacon-coast` | Beacon Coast | — | Queued | — | |
| 15 | `15-paper-admirals` | Paper Admirals | — | Queued | — | |
| 16 | `16-clockwork-menagerie` | Clockwork Menagerie | — | Queued | — | |
| 17 | `17-lesser-gods-of-the-vale` | Lesser Gods of the Vale | — | Queued | — | |
| 18 | `18-caravanserai` | Caravanserai | — | Queued | — | |
| 19 | `19-atrium` | Atrium | — | Queued | — | |
| 20 | `20-pack-and-herd` | Pack & Herd | — | Queued | — | |
| 21 | `21-sundial` | Sundial | — | Queued | — | |
| 22 | `22-rootbound` | Rootbound | — | Queued | — | |
| 23 | `23-last-depot` | Last Depot | — | Queued | — | |
| 24 | `24-the-loom-court` | The Loom Court | — | Queued | — | |
| 25 | `25-gilded-ledger` | Gilded Ledger | — | Queued | — | |

**Totals:** 0 launch-ready, 0 parked, 0 in progress, 25 queued. Build order is still unset (P0).

## Program Review Passes (P0)

At most three. Stop at the first pass that makes no material change.

| Pass | Lens | Changes | Still Open |
| --- | --- | --- | --- |

## Foundation (P1)

Engine version: none yet. Record each P1 item as it is done: engine modules, `scripts/new-game.sh`, `scripts/check.sh`, CI path filters, and the `engine/v0.1.0` tag.

## Program Checkpoints

One row after every five games finished or parked.

| Checkpoint | Date | Finished | Parked | Remaining | Regressions Fixed | Notes |
| --- | --- | --- | --- | --- | --- | --- |

## Parked

Games or items that could not progress, each with the reason, what was tried, and what would unblock it. Revisit at every checkpoint.

- none

## Needs the Maintainer

Steps only the maintainer can do, grouped by game, each with the stage that needs it and exactly what to do. Adding an item never stops work.

### Program

- **G6 (every game):** set the real bundle identifier prefix and development team in the shared settings file, in place of the placeholders.

## Log

One line per meaningful step, newest last: date, phase or game and stage, what was done, and the commit.

- Program roadmap and status written; P0 not started.
- Decision: the whole repository is all rights reserved and stays public for reference only (`LICENSE`); third-party assets and dependencies must be permissively licensed with attribution recorded, and nothing copyleft.
- 2026-11-15, P0: placed the twenty-five game roadmaps at `games/NN-<slug>/ROADMAP.md` and listed them in the queue. Build order not set.
