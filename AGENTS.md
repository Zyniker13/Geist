# Working in This Repository

This guide is for whoever works in this repository, human or agent. Read `ROADMAP.md` (the program roadmap) and `STATUS.md` (where the program stands) first, then the current game's `games/NN-<slug>/ROADMAP.md` and `STATUS.md`.

## Precedence

Where this file conflicts with the game roadmap set, the set governs. The set is `games/_shared/_CONVENTIONS.md`, `games/_shared/_TEMPLATE.md`, and each `games/NN-<slug>/ROADMAP.md`. The same rule applies to conflicts with `ROADMAP.md`, `STATUS.md`, and `docs/game-roadmap-template.md`. See [Precedence](ROADMAP.md#precedence).

The set governs on phases P0–P10 and gates G0–G10, including the GLM hard stops at G2 and G5; the technology stack; iPad-first platforms (iOS, iPadOS, and macOS); the online and privacy choices; the premium universal-purchase default; and the suggested build order (Orrery, Night Market, or Murmuration first). `docs/game-roadmap-template.md` is superseded by `games/_shared/_TEMPLATE.md`.

## Priorities

A game that works and is fun, then stability and data safety, then privacy and accessibility, then launch polish, then extra content. Never ship a change that can lose or corrupt a player's saved progress.

## Rules

- Follow phases P0–P10 and gates G0–G10 in `games/_shared/_CONVENTIONS.md`, including the GLM hard stops at G2 and G5. Where `ROADMAP.md` differs, the game roadmap set governs; see [Precedence](ROADMAP.md#precedence). Plan review is capped at three passes for the program and three per game.
- Run the game's `scripts/check.sh` before every push, and the global `scripts/check.sh` before pushing an engine change or closing out a game. Each runs what CI runs; keep them in step.
- Every change that alters behavior comes with tests, and every bug fix starts with a regression test. Never skip or disable a test to get green.
- Keep shared logic in the engine package under `Engine/` and game-specific logic in the game's folder. An engine change must keep every game that has reached G2 green.
- Every save-format change is a numbered migration with tests from every earlier version.
- Every asset has a provenance line in its game's `ASSETS.md`. Use only original, procedurally generated, or permissively licensed third-party assets and dependencies, with any required attribution recorded, and nothing under copyleft or non-commercial terms (see "Assets and Licensing" in `ROADMAP.md`).
- No analytics, advertising, or tracking SDKs.
- Record each significant decision in `docs/decisions/` (program) or the game's `docs/decisions/` (Context, Decision, Consequences), numbered in order.
- Keep `STATUS.md` current after every meaningful step: phase, game, stage, last done, next step, blocked on, and a log line.
- Work on `main` in small commits that keep CI green, or on a short-lived branch for a large change. Never force-push or rewrite pushed history.
- Pin GitHub Actions to full commit SHAs and keep workflow permissions read-only.
- Versions follow `vA.B.C`: A for a major release or rewrite, B for a feature release, and C for a fix or small change. Tags carry a prefix: `<slug>/vA.B.C`, `engine/vA.B.C`, or `program/vA.B.C`.

## Public Repository

Everything here is public, but all rights are reserved (see `LICENSE`): the repository is published for reference only and does not take outside contributions. Never commit secrets of any kind (including signing certificates, provisioning profiles, or keys that look real), email addresses, personal names, hostnames, IP addresses, local paths outside the repository, or anything about the machines or services used to develop it. Test data uses obviously fake values (`alice`, `example.com`). Commit messages describe the code only.
