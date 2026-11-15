# Program Roadmap

Geist holds **twenty-five iPad-first strategy games** (iOS, iPadOS, and macOS), each specified by its own roadmap in `games/NN-<slug>/ROADMAP.md`. This file says how the build agent works through all twenty-five, one after another, with as little outside input as possible: the build order, how a game's work maps onto this one repository, what to do at every stop, and how to move to the next game. It does not restate the games or the shared process; those live in the game roadmap set.

Read this file and `STATUS.md` first, every time. `AGENTS.md` lists which file is the source of truth for each thing.

## Precedence

The game roadmap set controls. The set is `games/_shared/_CONVENTIONS.md`, `games/_shared/_TEMPLATE.md`, and each `games/NN-<slug>/ROADMAP.md`.

- `games/_shared/_CONVENTIONS.md` governs process, stack, standards, phases P0–P10, gates G0–G10, sign-offs, stops, testing, CI content, and budgets.
- A game's `ROADMAP.md` governs that game's design, rules, content, and modules, and overrides the conventions only where it says so explicitly.
- This file adds only what the set does not cover: the order of the twenty-five games, the [Repository Adaptations](#repository-adaptations) needed because all twenty-five share one repository, and the [Program Loop](#program-loop) that moves from one game to the next. Where this file seems to contradict the set on anything else, the set wins.

## Roles in This Program

The set names four sign-off codes (`_CONVENTIONS.md` §1). In this program:

- **The build agent** is the role coded `GLM` in the set. It does phases **P0 through P5** of every game, runs every `GLM-SELF` gate, and honors every `🛑 GLM STOP`.
- **`REVIEW: GROK`, `REVIEW: CLAUDE`, and `REVIEW: MAHLER`** are reviews done by others. The build agent never writes, edits, or assumes one of these entries; it only reads them.
- **Phases P6 through P10** belong to the other roles. The build agent never starts them.

## Repository Adaptations

`_CONVENTIONS.md` §3 and §6 describe one game per repository. Here all twenty-five share one repository, so these mappings apply to every game. They change where things live, never what the conventions require.

| Conventions say | In this repository |
| --- | --- |
| The repository root `<slug>/` (§3) | The game's folder, `games/NN-<slug>/`. Every path in the conventions and the game roadmap (`project.yml`, `Makefile`, `App/`, `Packages/`, `Resources/`, `Tools/`, `Tests/`, and `docs/`) is relative to it. |
| `.github/workflows/ci.yml` (§3, §6) | `.github/workflows/<slug>.yml` at the repository root (GitHub only reads workflows there), with `defaults.run.working-directory: games/NN-<slug>`, triggered by pushes and pull requests that touch `games/NN-<slug>/**` or that workflow file, plus a weekly `schedule` run. It runs the §6 steps unchanged. |
| `docs/STATUS.md`, `docs/HANDOFF.md`, and the other `docs/` files (§3, §9) | `games/NN-<slug>/docs/…`, one set per game. |
| Branches `phase/Pn-short-name` (§6) | `<slug>/phase/Pn-short-name`, for example `night-market/phase/P1-rules`. |
| "Merges to `main` via PR" (§6) | The build agent has push access but no pull-request access. A phase branch is merged into `main` with a normal (non-force) push only after `make test` and `make lint` pass locally and CI is green on that branch. `main` must stay green. |
| Tags `gate-Gn-pass` (§6) | `<slug>/gate-Gn-pass`, for example `night-market/gate-G0-pass`. Tags are never moved or deleted. |
| The read order in `games/_shared/README.md` | Read the files in place: `games/_shared/_CONVENTIONS.md`, then `games/NN-<slug>/ROADMAP.md`. Do not copy them into the game folder; the only copied text is roadmap §4 into `docs/RULES.md` (S0.5). |

Each game is self-contained: no game imports another game's packages, and there is no shared engine. To save time, a game's P0 may copy proven foundation code (such as `SeededRNG`, `Fixed`, `Replay`, `Tools/check-imports.sh`, lint configs, the `Makefile`, and the debug overlay) from an earlier game's folder, renamed to the new prefix, as long as every G0 check still passes on its own.

Work on one game touches only `games/NN-<slug>/` and `.github/workflows/<slug>.yml`. Never change another game's folder or workflow; if a root-level change breaks another game's CI, revert the change.

## Build Order

`games/_shared/README.md` §6 says to start with an Approachable, solo-indie game (Orrery, Night Market, or Murmuration) and to leave Hardcore or larger-team games such as Meridian until the conventions, CI, and handoff loop are proven. Night Market goes first: it is Approachable, solo-indie, solo-play, and plain SpriteKit, so it exercises the conventions with the least rendering risk (Orrery needs RealityKit and Murmuration needs Metal). The rest follow by difficulty tier (Approachable, Intermediate, Deep, then Hardcore), then scope (solo-indie, small team, then larger team), then the lower end of the roadmap's effort estimate, then game number.

| Order | No. | Game | Tier | Scope |
| --- | --- | --- | --- | --- |
| 1 | 04 | Night Market | Approachable | Solo-indie |
| 2 | 12 | Murmuration | Approachable | Solo-indie |
| 3 | 02 | Orrery | Approachable to learn, deep to master | Solo-indie |
| 4 | 14 | Beacon Coast | Approachable | Solo-indie |
| 5 | 13 | Terrace | Approachable | Small team |
| 6 | 20 | Pack & Herd | Intermediate | Solo-indie |
| 7 | 24 | The Loom Court | Intermediate | Small team |
| 8 | 18 | Caravanserai | Intermediate | Small team |
| 9 | 22 | Rootbound | Intermediate | Small team |
| 10 | 11 | Lanternfall | Intermediate | Small team |
| 11 | 16 | Clockwork Menagerie | Intermediate | Small team |
| 12 | 19 | Atrium | Intermediate | Small team |
| 13 | 17 | Lesser Gods of the Vale | Intermediate | Small team |
| 14 | 15 | Paper Admirals | Intermediate | Small team |
| 15 | 21 | Sundial | Deep | Solo-indie |
| 16 | 25 | Gilded Ledger | Deep | Small team |
| 17 | 10 | Signal & Noise | Deep | Small team |
| 18 | 09 | Saltmarsh Concord | Deep | Small team |
| 19 | 08 | Hollow Crown | Deep | Small team |
| 20 | 01 | Cartographer's Gambit | Deep | Small team |
| 21 | 03 | Fugue | Deep | Small team |
| 22 | 23 | Last Depot | Hardcore | Small team |
| 23 | 06 | Palimpsest | Hardcore | Small team |
| 24 | 05 | Dispatch | Hardcore | Small team |
| 25 | 07 | Meridian | Hardcore | Larger team |

This order is fixed. Change it only if the maintainer says so; record any change in `STATUS.md`.

## Program Loop

A **stop** (`🛑 GLM STOP`, `🛑 GLM FINAL STOP`, or any stop in `_CONVENTIONS.md` §1.1 item 3) stops work on **that game only**. The build agent writes the game's `docs/HANDOFF.md` (§9), records the stop, and moves on to other work. It never begins the next phase of a stopped game until that game's stop is cleared, and it never waits idle while another game can move.

### Game States

Each game in the `STATUS.md` queue is in exactly one of these states:

| State | Meaning | Can the build agent work on it? |
| --- | --- | --- |
| Not Started | No work yet | Yes: start P0 |
| P0 to P5 | In that phase | Yes |
| Awaiting G2 Review | G2 checks passed; `🛑 GLM STOP` | No, until both `REVIEW: GROK` and `REVIEW: MAHLER` are recorded as PASS or PASS WITH CHANGES in the game's `docs/STATUS.md` |
| Pivot | A G2 review said PIVOT | No, until the game's `ROADMAP.md` is revised and a PASS is recorded |
| Stopped | A §1.1 item 3 stop: a gate check failed three consecutive fix attempts, an Apple account, signing, payment, or third-party account step is needed, a rule ambiguity has no default, or a dependency outside the allow-list seems necessary | No, until the cause is resolved (an answer in `docs/OPEN_QUESTIONS.md`, a maintainer step done, or the maintainer's approval recorded in an ADR) |
| G5 Handed Off | G5 checks passed, `docs/HANDOFF.md` complete; `🛑 GLM FINAL STOP` | Never again: P6–P10 belong to the other roles |

### Choosing the Next Step

At the start of every session and after every stop, `git pull` and pick the first that applies:

1. **CI is red on `main`:** fix it first.
2. **A game is in progress** (state P0 to P5): continue it until it reaches its next stop. Only one game is in progress at a time.
3. **A stopped game has been cleared** (a G2 review PASS or PASS WITH CHANGES, a revised roadmap with a PASS, or a resolved stop): resume it at the next phase, applying any PASS WITH CHANGES items first. If several are cleared, take the earliest in the build order.
4. **Otherwise, start the next Not Started game** in the build order.
5. **If no game can move,** every remaining game is waiting on someone else. Make sure `STATUS.md` lists exactly what each one waits for, and check again at the next session. Do not change any game while waiting.

### At Every Gate

Run every check in the game's GATE block plus the standard checks in `_CONVENTIONS.md` §8.1, paste the evidence into the game's `docs/STATUS.md`, merge the phase branch, tag `<slug>/gate-Gn-pass` for `GLM-SELF` gates that pass, and update `STATUS.md`. For G2, tag `<slug>/gate-G2-pass` when you resume the game after both reviews are recorded as PASS or PASS WITH CHANGES. G5 is tagged by its reviewers, not by the build agent. A `REVIEW: CLAUDE (async, non-blocking)` at G3 never blocks P4.

### At a Stop

1. Write or update the game's `docs/HANDOFF.md` with all ten items in `_CONVENTIONS.md` §9 plus the game roadmap's §9.
2. Commit and push; check CI.
3. Set the game's state in the `STATUS.md` queue, add what it waits for under **Waiting on Others**, and write a log line.
4. Choose the next step (above) in the same session.

## Momentum Rules

- Always take the next concrete step. At the end of every step, `STATUS.md` names the next one.
- No plan-review rounds: the roadmaps are complete. Read the conventions and the game's roadmap in full before its P0 (`games/_shared/README.md` §2, item 2), then build.
- A design ambiguity that would change a rule in `docs/RULES.md` goes in the game's `docs/OPEN_QUESTIONS.md`. If the roadmap gives a default (its §13 lists one for each open question), use the default and keep going; stop that game only when there is no default.
- Treat each game's `ROADMAP.md` and everything in `games/_shared/` as read-only. Record deviations as ADRs in the game's `docs/DECISIONS.md`.
- Every gate check is objective and is shown with real command output. Never mark a check passed without it, and never skip or disable a test to get green.

## Resuming After a Restart

`STATUS.md` (program) and the current game's `docs/STATUS.md` must always be enough to continue exactly where the work stopped. To resume: `git pull`; read `STATUS.md`, then the current game's `docs/STATUS.md` and `docs/HANDOFF.md` (if any), then the game's `ROADMAP.md` section for the current phase; run `make test` in the game's folder to confirm the tree is green; and continue from **Next step**. If the working tree has uncommitted changes, decide from `STATUS.md` whether they are the step in progress; finish and commit them, or set them aside with `git stash` and note it.

## Environment Limits

The build agent runs on a Mac with Xcode and simulators only: no physical device, no Apple account, and no App Store Connect. Anything in P0–P5 that needs more is treated as a stop of that kind for that game (`_CONVENTIONS.md` §1.1). Frame-rate checks in P0–P5 are measured on simulators or the Mac as the roadmaps state; real-device budgets belong to P8. Game Center, iCloud, Pencil, and Mac platform features before P7 are stubs behind protocols.

## Copyright and Third-Party Content

The repository is all rights reserved (see `LICENSE`) and published for reference only; it does not take outside contributions. Original and generated code, art, sound, and music are all rights reserved. Third-party assets, fonts, sample libraries, and dependencies are allowed only under CC0 or another permissive license that allows use in a commercial, closed-source app (for example CC BY, MIT, BSD, Apache-2.0, or the SIL Open Font License), each listed in the game's `docs/THIRD_PARTY.md` (name, version, source URL, license, and the exact attribution text, which the app's credits screen later shows) before it is committed. Nothing under copyleft or non-commercial terms (GPL, LGPL, AGPL, CC BY-SA, CC BY-NC, or similar). Dependencies must also be on the allow-list in `_CONVENTIONS.md` §4.4.

## Program Done

The build agent's program is done when all twenty-five games are in **G5 Handed Off**. Release versions (`<slug>/vA.B.C` tags) are made later, by whoever completes P10, and are not the build agent's work.
