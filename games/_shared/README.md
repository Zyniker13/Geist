# Strategy Game Roadmaps — How to Use This Set

Each game roadmap lives in a sibling folder at `../NN-<slug>/ROADMAP.md`, indexed in [`../README.md`](../README.md). This folder holds the two shared documents every roadmap depends on. The roadmaps are for iPad-first (iOS, iPadOS, and macOS) strategy games. The set is written to be handed to a GLM agent for initial development (phases P0–P5), after which Grok and Claude finish the work (P6–P10) with Mahler approving every external step.

## 1. Files

| File | Purpose |
| --- | --- |
| `_CONVENTIONS.md` | Shared rules for every game: roles and sign-off, fixed tech stack, repo layout, coding and determinism standards, testing, CI, performance budgets, the phase and gate model, standard tasks, handoff package, and effort units. **Read first. It wins over a game file on process, stack, standards, and gates. A game file wins on game-specific facts (rules, content, modules) and overrides this file only where it says so explicitly.** |
| `_TEMPLATE.md` | The section structure every roadmap follows (sections 0–13). Use it for any new game. |
| `../NN-<slug>/ROADMAP.md` | One roadmap per game (01–25), numbered in the order of the concepts Page. |
| `README.md` | This file. |

## 2. Ground Rules for the GLM Agent

1. **One repository for all twenty-five games.** Each game lives in its own folder, `../NN-<slug>/`, which stands in for the per-game repository root in `_CONVENTIONS.md` §3. Read `_CONVENTIONS.md` and the game roadmap in place; do not copy them. The root `ROADMAP.md` ("Repository Adaptations" and "Program Loop") gives the CI, branch, tag, and merge mappings and how a stop applies to one game while work continues on the next.
2. **Read order:** `_CONVENTIONS.md` in full, then the game roadmap in full, before writing any code.
3. **Run phases strictly in order** (P0 → P5). Do not begin phase N+1 until gate GN passes and is recorded in `docs/STATUS.md` with a `gate-GN-pass` tag.
4. **Gates are objective.** Each gate lists checks (tests, coverage, performance, counts). The agent runs every check, pastes the evidence into `docs/STATUS.md`, and marks the gate PASS only when every box is ticked.
5. **Hard stops:**
   - **🛑 GLM STOP at G2 (Vertical Slice).** Stop and wait for Grok and Mahler to review the slice. Resume only on an explicit PASS.
   - **🛑 GLM FINAL STOP at G5 (Meta and Replayability).** The GLM agent's work ends here. Complete `docs/HANDOFF.md` and stop.
   - Also stop when a gate fails three fix attempts, when any Apple account, signing, payment, or App Store Connect action is needed, when a rule is ambiguous (log it in `docs/OPEN_QUESTIONS.md`), or when a dependency outside the allow-list seems necessary.
6. **Determinism is non-negotiable.** Core, Content, and AI packages use the seeded RNG and fixed-point math; no `Float`, `Date()`, `UUID()`, or system randomness. `Tools/check-imports.sh` and replay golden hashes enforce it in CI.
7. **Never hand-edit `.pbxproj`.** Use XcodeGen.
8. **Mahler alone** approves and performs App Store Connect setup, external TestFlight, submission, pricing, and any spend.

## 3. Suggested Prompt for the GLM Agent

> You are the initial developer for `<Game Name>`. Read `games/_shared/_CONVENTIONS.md` and `games/NN-<slug>/ROADMAP.md` completely. Execute phases P0 through P5 in order. For each phase, complete every listed task, run every gate check, record evidence in the game's `docs/STATUS.md`, and tag `<slug>/gate-Gn-pass` only when all checks pass. Stop at G2 and wait for review. Stop permanently at G5 after completing `docs/HANDOFF.md`. Log any rule ambiguity in `docs/OPEN_QUESTIONS.md` instead of guessing. Never perform Apple account, signing, or payment actions.

## 4. After GLM: Grok and Claude

- **Claude** owns architecture review, platform features (P7), and polish, accessibility, and performance (P8), and signs off G5 architecture.
- **Grok** owns design and balance review, supports the aesthetics pass (P6), and leads beta (P9).
- Both start from `docs/HANDOFF.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/KNOWN_ISSUES.md`, and `docs/TODO_MAP.md`, then each game's section 9 ("Handoff to Grok and Claude") for fragile areas and first pickups.

## 5. Phase and Gate Model (Summary)

| Phase | Name | Owner | Gate Sign-Off |
| --- | --- | --- | --- |
| P0 | Setup | GLM | GLM-SELF |
| P1 | Rules Engine Prototype | GLM | GLM-SELF |
| P2 | Core Loop Vertical Slice | GLM | GROK + MAHLER · 🛑 GLM STOP |
| P3 | Content and Systems | GLM | GLM-SELF (Claude async review) |
| P4 | AI Opponents (or game-specific equivalent) | GLM | GLM-SELF |
| P5 | Meta and Replayability | GLM | CLAUDE + GROK + MAHLER · 🛑 GLM FINAL STOP |
| P6 | Aesthetics and Audio Pass | GROK + CLAUDE | MAHLER |
| P7 | Platform Features | CLAUDE | GROK |
| P8 | Polish, Accessibility, and Performance | CLAUDE | GROK + MAHLER |
| P9 | Beta and TestFlight | GROK + CLAUDE | MAHLER |
| P10 | Release Prep | CLAUDE + GROK | MAHLER (Mahler submits) |

## 6. Choosing a First Game

Start with an Approachable, Solo-indie scope roadmap (Orrery, Night Market, or Murmuration) to shake out the conventions, CI, and the GLM handoff loop before committing to a Hardcore or Larger-team project such as Meridian.
