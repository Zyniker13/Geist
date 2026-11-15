# NN — <Game Title> Roadmap

<!--
TEMPLATE v2.0 (2026-11-15). Copy this file to `../NN-<slug>/ROADMAP.md` and fill every section.
Rules for authors:
- Keep every section heading and number exactly as below so agents can navigate by section number.
- Do NOT restate the shared stack, standards, CI, or standard tasks from _CONVENTIONS.md; reference them (e.g. "S0.1–S0.7").
- Game-specific task IDs use the game prefix: <PFX>-P<phase>.<n> (e.g. CG-P3.4).
- Every task has: ID, title, deliverable (files/modules), and acceptance criteria.
- Every gate lists objective checks (commands, numbers, demonstrable features) and the sign-off code.
- Every gate is GLM-SELF. Steps only the maintainer can do use the local substitutes in _CONVENTIONS.md §8.2.
- Use the serial comma and Title Case headings.
-->

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | NN · `slug` |
| Code prefix | `PFX` (packages `PFXCore`, `PFXContent`, `PFXAI`, `PFXRender`, `PFXAudio`, `PFXPlatform`, `PFXMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | … |
| Difficulty tier | Approachable / Intermediate / Deep / Hardcore |
| Scope | Solo-indie / Small team / Larger team |
| Session length | … |
| Renderer | SpriteKit (2D) / RealityKit (3D) / + Metal for … |
| Players | Solo vs AI / local pass-and-play / async online (GameKit turn-based) |
| Conventions | `_CONVENTIONS.md` v2.0 (read first) |

## 1. Summary and Design Pillars

- **Hook:** one line (from the concepts Page).
- **Summary:** one paragraph.
- **Pillars (3–5):** each a short, testable statement, used to judge every gate and self-assessment.
- **Aesthetic spec:** palette (hex values), shapes/linework, typography, motion, music, SFX, and haptics.
- **Inspirations:** from the research.

## 2. Tech Stack Decision

State "Per `_CONVENTIONS.md` §2" plus only the game-specific choices (renderer, Metal shaders, simulation tick rate, audio approach) and why. Include an ADR list to create in P0 (ADR-0003+).

## 3. Repository Structure (Game-Specific Additions)

List the game-specific modules/files inside each package (tree form) and the main types.

## 4. Core Rules Specification

Numbered rules with stable IDs (`R-1`, `R-2`, …). Include: setup, turn/tick structure, actions, resolution order, scoring, win/loss, edge cases, and invariants (`INV-1` …) for property tests. This section is copied verbatim to `docs/RULES.md` in S0.5.

## 5. Data Schemas and Content Tables

Swift-style or JSON Schema-style definitions for state, actions, events, and every content table; content counts required by G3 and G5; a sample JSON row per table.

## 6. Balancing Parameters

A table of tunable constants (name, default, range, file) living in `Resources/Content/balance.json`, plus target metrics (win rates, game length) that sims must hit.

## 7. AI Approach

Algorithm per difficulty tier, evaluation features, time budgets, determinism requirements, and any solvers (daily-puzzle generation and verification).

## 8. Phases, Tasks, and Gates

For each of P0–P10: standard tasks referenced by ID, game-specific tasks (`PFX-Pn.m`) with deliverables and acceptance criteria, then a **GATE Gn** block:

```
GATE Gn — <name>
Checks:
  [ ] check 1 (command / metric / demonstrable feature)
  [ ] …
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

Game-specific additions to `_CONVENTIONS.md` §9: what to emphasize, fragile areas, and what to prioritize in P6–P10.

## 10. Risks and Mitigations

Table: risk, likelihood, impact, mitigation, and owner.

## 11. Out of Scope

Explicit list of things not to build (for v1.0).

## 12. Effort Estimates

Table: phase, owner, engineer-days range. Total.

## 13. Open Questions

Numbered; each with the default GLM uses unless the maintainer answers it in an issue.
