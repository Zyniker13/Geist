# Murmuration — Architecture

Package graph (dependency direction per `_CONVENTIONS.md` §3.1; arrows point at the
dependency):

```
MU (iOS app) ─┐
MU-macOS ─────┤
              ├─→ MURender ─→ MUCore
              ├─→ MUAudio
              ├─→ MUPlatform ─→ MUCore
              ├─→ MUContent ─→ MUCore
              └─→ MUAI ─→ MUCore
MUMeta (standalone)
```

- **MUCore** — the rules engine: deterministic reducer over `GameState`, fixed-point
  boid simulation (`Sim/`), world entities (`World/`), predators, scoring, and
  `Replay`. Pure Swift; no UI or platform imports (enforced by `Tools/check-imports.sh`).
- **MUContent** — content tables (regions, campaign, modifiers) loaded from
  `Resources/Content/*.json` with typed loaders and validation.
- **MUAI** — rival flock steering, falcon behavior, and the autoplayer used by sims
  and UI tests.
- **MURender** — Metal instanced bird rendering and landscape layers; reads Core
  state, never mutates it.
- **MUAudio** — AVAudioEngine graph: granular wingbeats, regional pads.
- **MUPlatform** — Game Center, iCloud, Pencil, and haptics adapters behind protocols.
- **MUMeta** — migration campaign, daily seeds, achievements, stats.

Determinism contract (INV-3): one pure reducer, seeded randomness only via
`SeededRNG`, integer/fixed-point math only, checkpoint hashes every 300 ticks.
