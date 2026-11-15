# Program Roadmap

Geist holds **twenty-five iPad-first strategy games** (iOS, iPadOS, and macOS), each specified by its own roadmap in `games/NN-<slug>/ROADMAP.md`. This file says how the build agent builds all twenty-five, one after another and each one end to end, without waiting for anyone: the build order, how a game's work maps onto this one repository, how to file what only the maintainer can do, and how to move to the next game. It does not restate the games or the shared process; those live in the game roadmap set.

Read this file and `STATUS.md` first, every time. `AGENTS.md` lists which file is the source of truth for each thing.

## Precedence

The game roadmap set controls. The set is `games/_shared/_CONVENTIONS.md`, `games/_shared/_TEMPLATE.md`, and each `games/NN-<slug>/ROADMAP.md`.

- `games/_shared/_CONVENTIONS.md` governs process, stack, standards, phases P0–P10, gates G0–G10, sign-off, owner-only steps and their local substitutes, testing, CI content, and budgets.
- A game's `ROADMAP.md` governs that game's design, rules, content, and modules, and overrides the conventions only where it says so explicitly.
- This file adds only what the set does not cover: the order of the twenty-five games, the [Repository Adaptations](#repository-adaptations) needed because all twenty-five share one repository, [Issues for the Maintainer](#issues-for-the-maintainer), and the [Program Loop](#program-loop). Where this file seems to contradict the set on anything else, the set wins.

## Roles in This Program

- **The build agent** is the role coded `GLM` in the set. It does every phase, **P0 through P10**, of every game, and checks every gate itself (`GLM-SELF`).
- **The maintainer** does only what needs an Apple account, real devices, money, or a public action (`_CONVENTIONS.md` §1). The build agent prepares everything for those steps, files each one as an issue, and keeps going. The maintainer may play builds and leave feedback in issues at any time; that is never a gate.

## Repository Adaptations

`_CONVENTIONS.md` §3 and §6 describe one game per repository. Here all twenty-five share one repository, so these mappings apply to every game. They change where things live, never what the conventions require.

| Conventions say | In this repository |
| --- | --- |
| The repository root `<slug>/` (§3) | The game's folder, `games/NN-<slug>/`. Every path in the conventions and the game roadmap (`project.yml`, `Config/`, `Makefile`, `App/`, `Packages/`, `Resources/`, `Tools/`, `Tests/`, and `docs/`) is relative to it. |
| `.github/workflows/ci.yml` (§3, §6) | `.github/workflows/<slug>.yml` at the repository root (GitHub only reads workflows there), with `defaults.run.working-directory: games/NN-<slug>`, triggered by pushes and pull requests that touch `games/NN-<slug>/**` or that workflow file, plus a weekly `schedule` run. It runs on `macos-latest`, selects the newest Xcode 27 on the image (`sudo xcode-select -s` in CI is fine; if `macos-latest` has no Xcode 27, use the newest `macos-NN` image that does and note it in ADR-0001), and picks simulator destinations by querying `xcrun simctl list devices available` rather than hard-coding names. It runs the §6 steps unchanged. |
| `docs/STATUS.md`, `docs/HANDOFF.md`, and the other `docs/` files (§3, §9) | `games/NN-<slug>/docs/…`, one set per game. |
| Branches `phase/Pn-short-name` (§6) | `<slug>/phase/Pn-short-name`, for example `night-market/phase/P1-rules`. |
| "Merges to `main` via PR" (§6) | The build agent pushes with git only. A phase branch is merged into `main` with a normal (non-force) push only after `make test` and `make lint` pass locally and CI is green on that branch. `main` must stay green. |
| Tags `gate-Gn-pass` (§6) | `<slug>/gate-Gn-pass`, for example `night-market/gate-G0-pass`. Tags are never moved or deleted. Release tags (`<slug>/vA.B.C`) are made only when the maintainer submits a game. |
| The read order in `games/_shared/README.md` | Read the files in place: `games/_shared/_CONVENTIONS.md`, then `games/NN-<slug>/ROADMAP.md`. Do not copy them into the game folder; the only copied text is roadmap §4 into `docs/RULES.md` (S0.5). |

Each game is self-contained: no game imports another game's packages, and there is no shared engine. To save time, a game's P0 may copy proven foundation code (such as `SeededRNG`, `Fixed`, `Replay`, `Tools/check-imports.sh`, lint configs, the `Makefile`, `Config/Bundle.xcconfig`, and the debug overlay) from an earlier game's folder, renamed to the new prefix, as long as every G0 check still passes on its own.

Work on one game touches only `games/NN-<slug>/` and `.github/workflows/<slug>.yml`. Never change another game's folder or workflow, except to apply maintainer feedback filed against that game; if a root-level change breaks another game's CI, revert the change.

## Issues for the Maintainer

Everything that needs the maintainer is filed as a **GitHub issue** in this repository, and nothing else is used to ask: owner-only steps (`_CONVENTIONS.md` §1.1, item 1, and §8.2), checks still failing after three attempts (item 2), questions without a roadmap default (item 3), and needed dependencies (item 4).

**Labels:** every issue gets `needs-maintainer` and the game's slug (for example `night-market`), plus `blocked` for item 2 or 4, or `question` for item 3. Program-wide issues use `program` instead of a slug.

**Title and body:** title `<slug>: <what is needed>`; body with what the maintainer needs to do, why, what the build agent already did locally (with paths to the evidence), and what the build agent does once it is done. One issue per need; before filing, search open issues with the same labels and add a comment instead of a duplicate. Issues are public: the rules in "Public Repository" in `AGENTS.md` apply to them.

**How:** at the start of every session, run `gh auth status`. If it succeeds, file with `gh issue create --repo Zyniker13/Geist --title "…" --body-file <file> --label needs-maintainer --label <slug>` (plus `blocked` or `question`), and record the issue number in the game's `docs/STATUS.md` evidence. Read answers with `gh issue list --repo Zyniker13/Geist --label needs-maintainer --state all` and `gh issue view <n> --comments`.

**Fallback, when `gh` is not authenticated:** add the item under **Needs the Maintainer** in `STATUS.md` instead, as one bullet with the labels in brackets, `[needs-maintainer] [<slug>] [blocked]`, then the title, then the body. This is the only fallback. When `gh auth status` later succeeds, file every fallback item as an issue and remove it from the list.

Filing never pauses work. The build agent never closes an issue the maintainer opened; it closes its own issue only after the maintainer's answer or action is applied, with a comment naming the commit.

## Program Loop

Only one game is in progress at a time. The build agent never stops a game to wait for anything: owner-only steps, failing checks, and questions are handled as in `_CONVENTIONS.md` §1.1 and filed as above.

### Game States

| State | Meaning |
| --- | --- |
| Not Started | No work yet. |
| P0 to P10 | In that phase. |
| Blocked | The next phase depends on a check still `FAILED` after three attempts (`_CONVENTIONS.md` §1.1, item 2); its `blocked` issue is open. Resume it when the issue is answered (step 3 below). |
| Done | G10 checked: every task the build agent can do through P10 is complete, every gate is tagged or has its `FAILED` checks filed as `blocked` issues, and every owner-only item is filed. |

### Choosing the Next Step

At the start of every session and after every gate, `git pull`, check `gh auth status`, and pick the first that applies:

1. **CI is red on `main`:** fix it first.
2. **A game is in progress** (state P0 to P10): continue it.
3. **The maintainer has answered or acted on an issue** (a comment, a closed issue, or an answer under a fallback item): apply it to that game (resuming it if it is Blocked), then return here.
4. **Otherwise, start the next Not Started game** in the build order.
5. **Every game is Done or Blocked:** retry every `FAILED` check across the games once more and apply any new maintainer answers. If games are still Blocked, check their issues again at the next session; otherwise the program is done.

### At Every Gate

Run every check in the game's GATE block plus the standard checks in `_CONVENTIONS.md` §8.1, paste the evidence into the game's `docs/STATUS.md` (marking each check PASS, `SUBSTITUTED` with its issue, or `FAILED` with its issue), keep `docs/HANDOFF.md` current (§9), merge the phase branch, tag `<slug>/gate-Gn-pass` when no check is `FAILED`, update `STATUS.md`, and start the next phase.

## Momentum Rules

- Always take the next concrete step. At the end of every step, `STATUS.md` names the next one.
- No plan-review rounds: the roadmaps are complete. Read the conventions and the game's roadmap in full before its P0 (`games/_shared/README.md` §2, item 2), then build.
- Use the roadmap's default for every open question in its §13 and keep going; the maintainer may answer later in an issue.
- Treat each game's `ROADMAP.md` and everything in `games/_shared/` as read-only. Record deviations as ADRs in the game's `docs/DECISIONS.md`.
- Every gate check is objective and is shown with real command output. Never mark a check passed without it, and never skip or disable a test to get green.

## Resuming After a Restart

`STATUS.md` (program) and the current game's `docs/STATUS.md` must always be enough to continue exactly where the work stopped. To resume: `git pull`; read `STATUS.md`, then the current game's `docs/STATUS.md` and `docs/HANDOFF.md`, then the game's `ROADMAP.md` section for the current phase; run `make test` in the game's folder to confirm the tree is green; and continue from **Next step**. If the working tree has uncommitted changes, decide from `STATUS.md` whether they are the step in progress; finish and commit them, or set them aside with `git stash` and note it.

## Environment

The build agent runs on a Mac with Xcode 27.2 and its simulators only: no physical device, no Apple account, and no App Store Connect. Anything that needs more uses the local substitutes in `_CONVENTIONS.md` §8.2. On the build machine, use these simulators (from `xcrun simctl list devices available`): **iPad Pro 13-inch (M5)** for the 13-inch iPad, the latest-iPad-Pro CI step, and ProMotion figures; **iPad Pro 11-inch (M5)** for the 11-inch iPad; **iPad** (the base model) and **iPad mini (A20 Pro)** as the stand-ins for the iPad (A16) and iPad mini (A17 Pro) frame-rate floor; and **iPhone 18 Pro Max** for the 6.9-inch iPhone. Ignore other simulators already on the machine. Snapshot and performance results are recorded as simulator figures (`_CONVENTIONS.md` §8.2).

## Build Order

`games/_shared/README.md` §5 says to start with an Approachable, solo-indie game (Orrery, Night Market, or Murmuration) and to leave Hardcore or larger-team games such as Meridian until the conventions and CI are proven. Night Market goes first: it is Approachable, solo-indie, solo-play, and plain SpriteKit, so it exercises the conventions with the least rendering risk (Orrery needs RealityKit and Murmuration needs Metal). The rest follow by difficulty tier (Approachable, Intermediate, Deep, then Hardcore), then scope (solo-indie, small team, then larger team), then the lower end of the roadmap's effort estimate, then game number.

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

## Copyright and Third-Party Content

The repository is all rights reserved (see `LICENSE`) and published for reference only; it does not take outside contributions. Original and generated code, art, sound, and music are all rights reserved. Third-party assets, fonts, sample libraries, and dependencies are allowed only under CC0 or another permissive license that allows use in a commercial, closed-source app (for example CC BY, MIT, BSD, Apache-2.0, or the SIL Open Font License), each listed in the game's `docs/THIRD_PARTY.md` (name, version, source URL, license, and the exact attribution text, which the app's credits screen later shows) before it is committed. Nothing under copyleft or non-commercial terms (GPL, LGPL, AGPL, CC BY-SA, CC BY-NC, or similar). Dependencies must also be on the allow-list in `_CONVENTIONS.md` §4.4.

## Program Done

The program is done when all twenty-five games are **Done** and step 5 of "Choosing the Next Step" has run. Then write a final log line in `STATUS.md` listing, per game, the gates tagged and the open maintainer issues.
