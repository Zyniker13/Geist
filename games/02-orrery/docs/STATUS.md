# Orrery — Phase and Gate Evidence

## P0 (Setup) — COMPLETE, gate G0 passed

All tasks S0.1–S0.7 and OR-P0.1 complete. Evidence below; branch
`orrery/phase/P0-setup`, commit `cc71ad0` (scaffold) + this docs commit.

### Tasks

- [x] S0.1 repo layout, `project.yml`, Makefile, lint configs, seven packages compile
- [x] S0.2 `SeededRNG` (xoshiro256** via SplitMix64) + `Fixed` (Q32.32) with known-answer vectors
- [x] S0.3 `Tools/check-imports.sh` (adds a UI/platform-import ban), SwiftLint banned-API custom rules (incl. `Float` in Core), `content-lint` skeleton
- [x] S0.4 CI workflow (`.github/workflows/orrery.yml`, actions pinned to v4.2.2 SHAs); app builds and launches on iPad + Mac
- [x] S0.5 docs skeleton; `docs/RULES.md` copied from roadmap §4 with rule IDs intact; ADR-0001 (toolchain), ADR-0002 (stack), ADR-0003/0004/0005 restated
- [x] S0.6 `Replay` + trivial-state golden-replay harness; one committed golden file (`trivial-golden-1.json`, hash 8398107817133141332) verified twice per run
- [x] S0.7 debug overlay: three-finger double-tap (iPad) and ⌘⇧D (Mac); FPS/TICK/SEED/HASH readout
- [x] OR-P0.1 `Angle48` with wraparound tests for ±1…±96, line indexing (R-9/R-10 semantics), shortest-difference, clock labels

### Gate G0 checks (real outputs)

- `swift test --package-path Packages/ORCore`: **`Test run with 32 tests in 4 suites passed`** — exit 0
- `swift test` (ORContent, ORAI, ORRender, ORAudio, ORPlatform, ORMeta): **1 test passed each** — exit 0 ×6
- `swiftlint --strict`: **`Found 0 violations, 0 serious in 34 files`** — exit 0
- `swift-format lint --recursive Packages/ App/ Tests/`: **0 findings** (formatter run canonicalized the tree first)
- `Tools/check-imports.sh`: **clean** — exit 0
- `Tools/content-lint`: **0 files, 0 errors** (no content JSON yet; schema validator arrives in P3)
- `xcodebuild build -scheme OR` (iPad sim destination): **`** BUILD SUCCEEDED **`**
- `xcodebuild build -scheme OR-macOS` (macOS): **`** BUILD SUCCEEDED **`**
- `xcodebuild test -scheme OR` on `zGeist_bot-iPad-Pro-13` via sim-lock: **`** TEST SUCCEEDED **` — `Executed 1 test, with 0 failures`** (`testLaunchShowsPlaceholderMenu`, 4.6 s)
- Banned-API lint fixture: the `banned_float_core` custom rule targets Core/Content/AI paths and `check-imports.sh` greps the same trees; both verified against the rule patterns this phase (a deliberate-violation fixture file is added with the P1 reducer where the ban first has bite)
- Launch screenshot: `docs/media/p0-launch.png` (iPad Pro 13-in simulator, placeholder menu)

### Notes

- `Fixed` carries the magnitude-safe negative handling proven in Murmuration
  (`raw.magnitude` and `0 &- Int64.min` both trap on Swift 6.4.2); regression
  tests for `Int64.min` in `rounded()` and `description(precision:)` are in.
- The SeededRNG known-answer vector was computed from independent Python and
  scratch-Swift implementations of the same algorithms (seed 1 →
  `3752bdaf106afaec`, …) — any change to the PRNG now fails this test.
- An exact-antipode `difference(from:)` resolves positive (+24) by convention;
  documented in the test that pins it.

### G0: PASS — tag `orrery/gate-G0-pass` after merge to main

Sign-off: GLM-SELF
