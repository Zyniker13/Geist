# Orrery — Phase and Gate Evidence

## P0 (Setup) — in progress

- **Started:** 2026-11-23
- **Scope:** S0.1–S0.7 + OR-P0.1 (`Angle48`).

### Tasks

- [ ] S0.1 repo layout, `project.yml`, Makefile, lint configs, packages compile
- [ ] S0.2 `SeededRNG` + `Fixed` with known-answer vector tests
- [ ] S0.3 `Tools/check-imports.sh`, SwiftLint banned-API custom rules, `content-lint` skeleton
- [ ] S0.4 CI workflow green on a placeholder app (iPad + Mac)
- [ ] S0.5 docs skeleton; `docs/RULES.md` copied from roadmap §4; ADR-0001/0002
- [ ] S0.6 `Replay` type + golden-replay harness with one committed golden file
- [ ] S0.7 debug overlay (three-finger double-tap on iPad, ⌘⇧D on Mac)
- [ ] OR-P0.1 `Angle48` with wraparound tests for ±1…±96
