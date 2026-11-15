# Strategy Game Roadmaps — How to Use This Set

Each game roadmap lives in a sibling folder at `../NN-<slug>/ROADMAP.md`, indexed in [`../README.md`](../README.md). This folder holds the two shared documents every roadmap depends on. The roadmaps are for iPad-first (iOS, iPadOS, and macOS) strategy games. The set is written for one autonomous build agent (`GLM`) that builds each game end to end, phases P0 through P10, and files anything only the maintainer can do as an issue.

## 1. Files

| File | Purpose |
| --- | --- |
| `_CONVENTIONS.md` | Shared rules for every game: roles and sign-off, owner-only steps, fixed tech stack, repo layout, coding and determinism standards, testing, CI, performance budgets, the phase and gate model, standard tasks, local substitutes, handoff package, and effort units. **Read first. It wins over a game file on process, stack, standards, and gates. A game file wins on game-specific facts (rules, content, modules) and overrides this file only where it says so explicitly.** |
| `_TEMPLATE.md` | The section structure every roadmap follows (sections 0–13). Use it for any new game. |
| `../NN-<slug>/ROADMAP.md` | One roadmap per game (01–25), numbered in the order of the concepts Page. |
| `README.md` | This file. |

## 2. Ground Rules for the GLM Agent

1. **One repository for all twenty-five games.** Each game lives in its own folder, `../NN-<slug>/`, which stands in for the per-game repository root in `_CONVENTIONS.md` §3. Read `_CONVENTIONS.md` and the game roadmap in place; do not copy them. The root `ROADMAP.md` ("Repository Adaptations" and "Program Loop") gives the CI, branch, tag, and merge mappings and how to move from one game to the next.
2. **Read order:** `_CONVENTIONS.md` in full, then the game roadmap in full, before writing any code.
3. **Run phases strictly in order** (P0 → P10). Do not begin phase N+1 until gate GN is checked and recorded in `docs/STATUS.md`, with a `<slug>/gate-GN-pass` tag when every check passed or was substituted (`_CONVENTIONS.md` §8.2). The one exception is a check still `FAILED` after three different attempts (`_CONVENTIONS.md` §1.1, item 2).
4. **Gates are objective and self-checked.** Each gate lists checks (tests, coverage, performance, counts). The agent runs every check, pastes the evidence into `docs/STATUS.md`, and marks the gate PASS only when every box is ticked or substituted.
5. **Never stop.** Steps only the maintainer can do (Apple accounts, signing, App Store Connect, TestFlight, payment, real devices, and human playtests) get the local substitute in `_CONVENTIONS.md` §8.2 and a maintainer issue; blocked checks, ambiguities, and dependency needs follow `_CONVENTIONS.md` §1.1. Then continue.
6. **Determinism is non-negotiable.** Core, Content, and AI packages use the seeded RNG and fixed-point math; no `Float`, `Date()`, `UUID()`, or system randomness. `Tools/check-imports.sh` and replay golden hashes enforce it in CI.
7. **Never hand-edit `.pbxproj`.** Use XcodeGen.
8. **Only the maintainer** sets up App Store Connect, signing, TestFlight, submission, pricing, and any spend. The agent prepares everything for them and never performs these steps.

## 3. Suggested Prompt for the GLM Agent

> You are the developer for `<Game Name>`. Read `games/_shared/_CONVENTIONS.md` and `games/NN-<slug>/ROADMAP.md` completely. Execute phases P0 through P10 in order. For each phase, complete every listed task, run every gate check, record evidence in the game's `docs/STATUS.md`, and tag `<slug>/gate-Gn-pass` when all checks pass or are substituted. For anything only the maintainer can do, do the local substitute, file a maintainer issue, and continue. Follow roadmap defaults for open questions. Never perform Apple account, signing, or payment actions.

## 4. Phase and Gate Model (Summary)

| Phase | Name | Owner | Gate Sign-Off |
| --- | --- | --- | --- |
| P0 | Setup | GLM | GLM-SELF |
| P1 | Rules Engine Prototype | GLM | GLM-SELF |
| P2 | Core Loop Vertical Slice | GLM | GLM-SELF |
| P3 | Content and Systems | GLM | GLM-SELF |
| P4 | AI Opponents (or game-specific equivalent) | GLM | GLM-SELF |
| P5 | Meta and Replayability | GLM | GLM-SELF |
| P6 | Aesthetics and Audio Pass | GLM | GLM-SELF |
| P7 | Platform Features | GLM | GLM-SELF |
| P8 | Polish, Accessibility, and Performance | GLM | GLM-SELF |
| P9 | Beta and TestFlight | GLM (upload and groups are maintainer items) | GLM-SELF |
| P10 | Release Prep | GLM (submission is a maintainer item) | GLM-SELF |

## 5. Choosing a First Game

Start with an Approachable, Solo-indie scope roadmap (Orrery, Night Market, or Murmuration) to shake out the conventions and CI before committing to a Hardcore or Larger-team project such as Meridian.
