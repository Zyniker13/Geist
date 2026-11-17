# Murmuration — Handoff

Kept current at every gate. Contents: what the game is, where it stands, how to build
and verify it, and what the maintainer needs to do that the build agent cannot.

## What this is

Real-time territory control: steer a flock of thousands of starlings with sweeping
gestures to claim roosts, evade falcons, and outmaneuver a rival flock. Solo vs AI and
local two-flock versus on one iPad. Twelve-region migration campaign.

## Build and verify

```bash
cd games/12-murmuration
make bootstrap   # once: xcodegen, swiftlint, swift-format
make gen && make build && make test && make lint
make spike       # boid tick-time spike (Release)
make sim         # headless rules-engine day, 4,000 birds, twice (G1)
make coverage    # MUCore coverage -> docs/COVERAGE.md (G1)
```

## Current state

**G0 (scaffold) and G1 (rules engine) passed.** The rules engine implements
R-1…R-13 (wind grid, day/dusk, leader paths, condense, merges, energy
drain/feeding/growth/starvation, falcon dives with the density shield, roost
claims and victory) as pure integer math over `GameState` with a persistent
`SeededRNG` — deterministic across Debug/Release and Mac vs the arm64 iOS
simulator (checkpoint hashes every 300 ticks, final hash `5cbccf1ff18d0a2a`).
67 MUCore tests, 20 committed golden replays, coverage 95.4% (sources).
See [`STATUS.md`](STATUS.md) for the phase/gate ledger with sign-offs,
[`DECISIONS.md`](DECISIONS.md) for ADRs (integer trig, neighbor-visit cap,
rescale floors), and [`COVERAGE.md`](COVERAGE.md) for the coverage table.

Next phase: P2 core-loop vertical slice (FlockRenderer, gestures, first
playable regions).

## Owner-only items

- App Store Connect / TestFlight / signing: maintainer-only (build agent archives with
  `CODE_SIGNING_ALLOWED=NO` only).
- Real-device verification (iPad Pro M4 fps, Pencil input): maintainer or hardware
  access required; substitutes documented in `_CONVENTIONS.md` §8.2.
