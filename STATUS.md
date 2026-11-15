# Status

This file is the single place to resume the program from. Keep every field below current after every meaningful step (see "Resuming After a Restart" in `ROADMAP.md`).

- **Current phase:** P0 (Program Review): not started
- **Current game:** none yet
- **Stage:** none
- **Last done:** program roadmap and status file written
- **Next step:** P0 pass 1 (achievability and order): read `ROADMAP.md`, `AGENTS.md`, `docs/game-roadmap-template.md`, and every game roadmap under `games/`, then revise
- **Blocked on:** nothing

## Game Queue

Numbers are fixed once given; **Order** is the build order (see "Build Order" in `ROADMAP.md`). Fill one row per game roadmap as it arrives. **State** is one of: Waiting for Roadmap, Queued, G0 to G6, Launch-Ready, or Parked.

| No. | Folder | Working Name | Order | State | Latest Tag | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | — | — | — | Waiting for Roadmap | — | |
| 02 | — | — | — | Waiting for Roadmap | — | |
| 03 | — | — | — | Waiting for Roadmap | — | |
| 04 | — | — | — | Waiting for Roadmap | — | |
| 05 | — | — | — | Waiting for Roadmap | — | |
| 06 | — | — | — | Waiting for Roadmap | — | |
| 07 | — | — | — | Waiting for Roadmap | — | |
| 08 | — | — | — | Waiting for Roadmap | — | |
| 09 | — | — | — | Waiting for Roadmap | — | |
| 10 | — | — | — | Waiting for Roadmap | — | |
| 11 | — | — | — | Waiting for Roadmap | — | |
| 12 | — | — | — | Waiting for Roadmap | — | |
| 13 | — | — | — | Waiting for Roadmap | — | |
| 14 | — | — | — | Waiting for Roadmap | — | |
| 15 | — | — | — | Waiting for Roadmap | — | |
| 16 | — | — | — | Waiting for Roadmap | — | |
| 17 | — | — | — | Waiting for Roadmap | — | |
| 18 | — | — | — | Waiting for Roadmap | — | |
| 19 | — | — | — | Waiting for Roadmap | — | |
| 20 | — | — | — | Waiting for Roadmap | — | |
| 21 | — | — | — | Waiting for Roadmap | — | |
| 22 | — | — | — | Waiting for Roadmap | — | |
| 23 | — | — | — | Waiting for Roadmap | — | |
| 24 | — | — | — | Waiting for Roadmap | — | |
| 25 | — | — | — | Waiting for Roadmap | — | |

**Totals:** 0 launch-ready, 0 parked, 0 in progress, 25 remaining.

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

- **P0/P1:** choose the license for original art, sound, and music (code is MIT OR Apache-2.0).
- **G6 (every game):** set the real bundle identifier prefix and development team in the shared settings file, in place of the placeholders.

## Log

One line per meaningful step, newest last: date, phase or game and stage, what was done, and the commit.

- Program roadmap and status written; P0 not started.
