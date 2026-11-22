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

**G0–G4 passed. P5 (meta and replayability) complete, G5 evidence being
recorded.** The rules engine implements R-1…R-13 with 20 golden replays at
replayContentVersion 17; P4 shipped AI opponents (three difficulty tiers,
balance v16); P5 adds the meta layer in `Packages/MUMeta`:

- **Campaign (MU-P5.1):** a twelve-stage route over the six regions
  (`MetaState.campaignRoute`), flock carry between stages (floor 400,
  clamped to the next region's capacity), resume at the first unplayed
  stage, stage recording via `MetaStore.recordCampaignStage`.
- **Daily (MU-P5.2):** `DailyChallenge` derives dayNumber/modifier/wind
  offset from the UTC date (epoch 2026-01-01); six modifiers map to
  region/engine knobs in `Region+Daily.applying(dailyModifier:)` —
  strong winds (wind magnitude ×2, engine `windStrengthQ16`), extra
  falcons (+1), scarce fields (richness ÷2, floor 1), fog (wind regen
  300-tick cadence, engine `windRegenTicksOverride`), double roosts
  (+half-radius twin per roost, floor 32), tiny flock (birds ÷2, floor
  200). Local best scores persist per date. UI tests pin a day with
  `-uitest-daily-day N`.
- **Achievements (MU-P5.3):** 20 achievements + `LifetimeStats`
  (largest flock, longest unbroken flight streak, roosts, starvation,
  versus/daily/campaign counts) folded per completed day in
  `GameModel.recordMetaForDay()`; `MetaStore.record` persists and
  returns freshly earned achievements.
- **HUD evidence rows:** `game.stage` ("stage N/12" during campaign)
  and `debug.daily` ("dayNumber modifier") in the debug overlay.

Coverage (docs/COVERAGE.md P5 section): MUCore 95.7%, MUAI 79.0%,
MUMeta 81.7%, overall 87.0% — all gate thresholds met.

Next phase: P6 aesthetics and audio pass (ink-wash shader, granular
wingbeat synthesis).

## Owner-only items

- App Store Connect / TestFlight / signing: maintainer-only (build agent archives with
  `CODE_SIGNING_ALLOWED=NO` only).
- Real-device verification (iPad Pro M4 fps, Pencil input): maintainer or hardware
  access required; substitutes documented in `_CONVENTIONS.md` §8.2.
