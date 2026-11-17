# Murmuration

Real-time territory control: steer a flock of thousands of starlings with sweeping
gestures to claim roosts, evade falcons, and outmaneuver a rival flock. Roadmap:
[`ROADMAP.md`](ROADMAP.md).

## Stack

- CPU simulation: fixed 30 Hz tick, fixed-point boids (`Int32` positions in a
  4,096×3,072 world, Q16.16 velocities), deterministic across devices.
- Rendering: Metal instanced quads hosted in SwiftUI, interpolated at 120 Hz.
- Packages: `MUCore` (rules engine), `MUContent`, `MUAI`, `MURender`, `MUAudio`,
  `MUPlatform`, `MUMeta`.

## Build

```bash
make bootstrap  # install tool dependencies (xcodegen, swiftlint, swift-format)
make gen        # generate Murmuration.xcodeproj from project.yml
make build      # build iOS (MU) + macOS (MU-macOS)
make test       # swift test (7 packages) + iPad UI tests
make lint       # swiftlint --strict + swift-format + content-lint + check-imports
make spike      # MU-P0.1 perf spike: 4,000 boids, tick time on Mac Release
```

## Layout

- `App/` — SwiftUI shell (iOS `MU`, macOS `MU-macOS`), placeholder menu, debug overlay.
- `Packages/` — SwiftPM packages per the roadmap's module split.
- `Resources/Content/` — JSON content tables (source of truth for balance).
- `Tools/` — `spike` (perf + golden generation), `content-lint`, `check-imports.sh`.
- `docs/` — RULES, ARCHITECTURE, DECISIONS (ADRs), STATUS, HANDOFF, and friends.
