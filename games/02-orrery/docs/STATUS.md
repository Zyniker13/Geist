# Orrery — Phase and Gate Evidence

## P1 (Rules Engine Prototype) — COMPLETE, gate G1 evidence below

All P1 tasks (S1.1–S1.4, OR-P1.1…OR-P1.4) complete on `orrery/phase/P1-rules`
(commits f1c536b core · 036d5a1 rule tests · d7e052b victory tests · 6969963
goldens · 45baeb3 sim tool · 92f01b3 lint · d289f2d coverage tests · 218f454
make sim + formatting).

### Tasks

- [x] S1.1 full `GameState`, `Action`, `Event`, reducer (R-1…R-17), no UI
- [x] S1.2 one or more tests per rule ID + INV property checks (100 tests)
- [x] S1.3 headless CLI `Tools/sim`: random-legal-move games, per-ply INV-1/2/3
      checks, two-pass INV-4 hash agreement, timing distribution
- [x] S1.4 ten committed golden replays replaying bit-exactly, twice per run
- [x] OR-P1.1 rotation and slot-angle math (RotationTests, R-1…R-3, R-7)
- [x] OR-P1.2 actions, ko (both R-6 clauses), pass (TurnFlowTests, R-5, R-6, R-8)
- [x] OR-P1.3 alignment/capture ordering + Grand Alignment, ≥ 25 hand-built
      positions incl. opposite-side lines, across-the-sun spans, and two
      simultaneous post-rotation alignments (AlignmentTests, R-9…R-14)
- [x] OR-P1.4 victory (R-15…R-17) + GameStateHash canonical FNV-1a digest
      (victory tests + hash tests)

### Rule-ID coverage map

| Rules | Tests |
| --- | --- |
| R-1 (angles mod 48) | Angle48Tests, RotationTests |
| R-2 (slot angles) | RotationTests.slotAngles, slotAngleRoundTrip |
| R-3 (offsets/speeds) | standardVariantShape, roundRotation |
| R-4 (start, P1 first) | initialState |
| R-5 (place/nudge) | placeBasics, nudgeBasics + illegality cases |
| R-6 (ko both clauses) | koImmediateUndo, koSameDirectionAllowed, koOtherRingAllowed, noTwoNudgesInARow, twoNudgesAllowedWithEmptyReserve, koSurvivesRotation, twoNudgesAcrossRoundBoundary |
| R-7 (round rotation) | roundRotation, occupantsRideTheRing, passAdvancesRound |
| R-8 (pass) | passIllegalOtherwise, legalMovesNoPassEarly, forcedPass, passAdvancesRound |
| R-9/R-10 (lines, signed positions) | lineGeometry, signedPositions, signedPositionsGrouped |
| R-11 (≥ 3 alignment) | threshold, perLineIsolation |
| R-12 (capture span) | captureStrictlyBetween, captureAcrossSun, endpointSharingImpossible, captureSameLineOnly, captureOppositeRayInside |
| R-13 (check ordering a/b) | captureOnPlace, onlyActingPlayerChecked, postRotationSequencing, postRotationSimultaneous, postRotationOtherPlayerStillChecked |
| R-14 (Grand Alignment) | grandAlignmentWins, grandAlignmentNeedsSameRay, grandAlignmentBeforeCaptures, grandAlignmentAfterRotation, grandAlignmentSecondPlayer |
| R-15 (captures win) | capturesWin, capturesBoundary, captureCanEndGame |
| R-16 (round limit, tie-break) | roundLimitTieBreak, tieBreaks, roundLimitOrdering |
| R-17 (elimination) | eliminatedLoses, eliminationByCapture |

### GATE G1 checks (real outputs)

- `swift test --package-path Packages/ORCore`:
  **`Test run with 100 tests in 11 suites passed after 0.047 seconds`** — exit 0
- Other six packages (`swift test`): **1 test passed each** — exit 0 ×6
- ORCore coverage (`swift test --enable-code-coverage` + `llvm-cov report`):
  **TOTAL line coverage 96.49% (939 lines, 33 missed)** — gate needs ≥ 90% ✓
- `make sim N=5000` (also run standalone as
  `Tools/sim/.build/out/Products/Release/sim --games 5000 --seed 1`):
  **`games: 5000 × 2 passes, mismatches: 0`** — INV-4 identical hashes on two
  runs ✓; **0 crashes** (preconditions on INV-1/2/3 fired zero times over
  2×5000 games × ~78 plies); **timing ms: median 0.207, mean 0.207, p95 0.249,
  max 0.654** — median < 2 ms CPU ✓. Win distribution under the random policy:
  one 1920 / two 3080 (placeholder for AI balance; real balance lands in P4).
- `make lint`: **SwiftLint `Found 0 violations, 0 serious in 58 files`
  (--strict), swift-format 0 findings, content-lint `0 files, 0 errors`,
  check-imports `clean`**
- `xcodebuild build -scheme OR-macOS -destination 'platform=macOS'`:
  **`** BUILD SUCCEEDED **`**
- `~/.hermes/bin/sim-lock xcodebuild test -scheme OR -destination
  'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13'`:
  **`** TEST SUCCEEDED **`** — ORUITests `testLaunchShowsPlaceholderMenu()`
  **Passed** (9.2 s, xcresult Test-OR-2026.11.23_20-51-38) — P1 adds no UI, so
  the launch smoke is the app-level check.

### Notes

- Two real R-6 bugs were found and fixed by the tests: the two-nudges-in-a-row
  clause is per-player own-turn memory (`nudgedLastTurn` — `lastNudge` alone
  could never express it), and the end-of-round rotation does NOT clear the ko
  memory (R-6 binds the immediately preceding *turn*; the rotation is not a
  turn).
- One reducer bug found by the defensive-pass test: legality of `.pass` is
  "no place or nudge exists", not "the action list is empty" (the list itself
  contains the pass when nothing else is legal).
- `.aligned` events now fire for every aligned line whether or not it
  captures — the schematic view (P2) highlights aligned lines on every check.
- GameState hashing uses its own encoding version
  (`StateHash.gameStateEncodingVersion = 2`), separate from the P0 trivial
  state's `encodingVersion = 1`, so the committed trivial golden
  (`8398107817133141332`) stays pinned forever.
- The INV-1 checker inside the sim initially used the wrong captured-count
  direction (`captured[p]` counts what p captured, not what p lost) — fixed
  before any gate evidence was recorded; no engine change.
- 5,000-game sim: max single-game 0.654 ms (an outlier pass-start blip),
  well under budget; no core hot path exceeded the 2 ms median target.

### G1: PASS — tag `orrery/gate-G1-pass` after merge to main

Sign-off: GLM-SELF

---

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
