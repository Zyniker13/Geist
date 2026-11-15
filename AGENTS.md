# Working in This Repository

This guide is for whoever works in this repository, human or agent. Read `ROADMAP.md` (how the program runs) and `STATUS.md` (where it stands) first, then `games/_shared/_CONVENTIONS.md`, then the current game's `games/NN-<slug>/ROADMAP.md` and `games/NN-<slug>/docs/STATUS.md`.

## Precedence

The game roadmap set governs: `games/_shared/_CONVENTIONS.md`, `games/_shared/_TEMPLATE.md`, and each `games/NN-<slug>/ROADMAP.md`. Where this file, `ROADMAP.md`, or `STATUS.md` seems to conflict with the set, the set wins; see [Precedence](ROADMAP.md#precedence).

The set governs phases P0–P10 and gates G0–G10, including the `🛑 GLM STOP` at G2 and the `🛑 GLM FINAL STOP` at G5; the technology stack; iPad-first platforms (iOS, iPadOS, and macOS); the online and privacy choices; the premium universal-purchase default; and the suggested first games (Orrery, Night Market, or Murmuration).

## Sources of Truth

Each thing has exactly one home. Change it there; elsewhere, link to it.

| Topic | Single source |
| --- | --- |
| Process, stack, layout, architecture rules, dependency allow-list, testing, CI content, budgets, phases, gates, sign-offs, stops, and handoff contents | `games/_shared/_CONVENTIONS.md` |
| A game's design, rules, content, modules, tasks, gate checks, and open-question defaults | `games/NN-<slug>/ROADMAP.md` |
| The shape of a game roadmap | `games/_shared/_TEMPLATE.md` |
| Build order, repository adaptations (paths, CI files, branches, tags, and merging), the program loop, game states, and copyright rules | `ROADMAP.md` |
| Current program position, game queue and states, waiting on others, needs the maintainer, and the program log | `STATUS.md` |
| A game's phase, gate evidence, sign-offs, and review entries | `games/NN-<slug>/docs/STATUS.md` |
| A game's decisions (ADRs), including every deviation from its roadmap | `games/NN-<slug>/docs/DECISIONS.md` |
| A game's third-party components, their licenses, and attribution text | `games/NN-<slug>/docs/THIRD_PARTY.md` |
| A game's open questions and answers | `games/NN-<slug>/docs/OPEN_QUESTIONS.md` |
| A game's handoff at a stop | `games/NN-<slug>/docs/HANDOFF.md` |
| Copyright and license | `LICENSE` |
| How to report a vulnerability | `SECURITY.md` |

`games/_shared/` and each game's `ROADMAP.md` are read-only for the build agent.

## Rules

- Follow the phases, gates, and stops in `games/_shared/_CONVENTIONS.md`. A stop applies to that game only; then follow the [Program Loop](ROADMAP.md#program-loop).
- Never write, edit, or assume a `REVIEW:` entry. Only the reviewers record those.
- Before every merge to `main`, `make test` and `make lint` pass in the game's folder and CI is green on the branch. Never skip or disable a test to get green.
- Every change that alters behavior comes with tests, and every bug fix starts with a regression test.
- Work on one game touches only its folder and its workflow file, `.github/workflows/<slug>.yml`.
- Never force-push, rewrite pushed history, or move or delete a tag.
- Pin GitHub Actions to full commit SHAs and keep workflow permissions read-only.
- Use only dependencies on the allow-list in `_CONVENTIONS.md` §4.4, and only third-party assets under the terms in "Copyright and Third-Party Content" in `ROADMAP.md`.
- Keep `STATUS.md` and the game's `docs/STATUS.md` current after every meaningful step.

## Public Repository

Everything here is public, but all rights are reserved (see `LICENSE`): the repository is published for reference only and does not take outside contributions. Never commit secrets of any kind (including signing certificates, provisioning profiles, or keys that look real), email addresses, personal names, hostnames, IP addresses, local paths outside the repository, or anything about the machines or services used to develop it. Test data uses obviously fake values (`alice`, `example.com`). Commit messages describe the code only.
