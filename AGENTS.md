# Working in This Repository

This guide is for anyone, human or agent, changing this repository. Read `ROADMAP.md` (the program roadmap) and `STATUS.md` (where the program stands) first, then the current game's `games/NN-<slug>/ROADMAP.md` and `STATUS.md`.

## Priorities

A game that works and is fun, then stability and data safety, then privacy and accessibility, then launch polish, then extra content. Never ship a change that can lose or corrupt a player's saved progress.

## Rules

- Follow the phases, stages, and [Transition Protocol](ROADMAP.md#transition-protocol) in `ROADMAP.md`. Plan review is capped at three passes for the program and three per game.
- Run the game's `scripts/check.sh` before every push, and the global `scripts/check.sh` before pushing an engine change or closing out a game. Each runs what CI runs; keep them in step.
- Every change that alters behavior comes with tests, and every bug fix starts with a regression test. Never skip or disable a test to get green.
- Keep shared logic in the engine package under `Engine/` and game-specific logic in the game's folder. An engine change must keep every game that has reached G2 green.
- Every save-format change is a numbered migration with tests from every earlier version.
- Every asset has a provenance line in its game's `ASSETS.md`. Use only original, procedurally generated, or CC0-licensed assets (see "Assets and Licensing" in `ROADMAP.md`).
- No analytics, advertising, or tracking SDKs.
- Record each significant decision in `docs/decisions/` (program) or the game's `docs/decisions/` (Context, Decision, Consequences), numbered in order.
- Keep `STATUS.md` current after every meaningful step: phase, game, stage, last done, next step, blocked on, and a log line.
- Work on `main` in small commits that keep CI green, or on a short-lived branch for a large change. Never force-push or rewrite pushed history.
- Pin GitHub Actions to full commit SHAs and keep workflow permissions read-only.
- Versions follow `vA.B.C`: A for a major release or rewrite, B for a feature release, and C for a fix or small change. Tags carry a prefix: `<slug>/vA.B.C`, `engine/vA.B.C`, or `program/vA.B.C`.

## Public Repository

Everything here is public. Never commit secrets of any kind (including signing certificates, provisioning profiles, or keys that look real), email addresses, personal names, hostnames, IP addresses, local paths outside the repository, or anything about the machines or services used to develop it. Test data uses obviously fake values (`alice`, `example.com`). Commit messages describe the code only.
