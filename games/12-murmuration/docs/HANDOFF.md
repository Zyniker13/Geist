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
```

## Current state

See [`STATUS.md`](STATUS.md) for the phase/gate ledger with sign-offs.

## Owner-only items

- App Store Connect / TestFlight / signing: maintainer-only (build agent archives with
  `CODE_SIGNING_ALLOWED=NO` only).
- Real-device verification (iPad Pro M4 fps, Pencil input): maintainer or hardware
  access required; substitutes documented in `_CONVENTIONS.md` §8.2.
