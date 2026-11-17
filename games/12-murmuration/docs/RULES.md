# Murmuration — Rules

Authoritative rules spec, copied from [`ROADMAP.md`](../ROADMAP.md) §4 at P0 and
maintained here. Rule IDs are stable and referenced by tests.

## World and Day

- **R-1** A region is a 2D world with fields (food), roosts (2–5), obstacles, and a seeded wind field (vector per 256-unit cell, changes every 20 seconds).
- **R-2** A day lasts 4,800 ticks (160 seconds at 1×); the last 900 ticks are dusk, when roost claims accumulate.

## Flock Control

- **R-3** The player's input produces a `LeaderPath` (sequence of world points sampled at tick resolution); the flock's leader point moves along the path at the flock's max speed.
- **R-4** Gestures map to actions: one finger draws the leader path; two fingers apart draws two paths and splits the flock proportionally by nearest path (sub-flocks); a pinch condenses (cohesion ×2 for 60 ticks, then cooldown 120 ticks); lifting all fingers leaves the leader point circling its last position.
- **R-5** Sub-flocks merge automatically when their centroids are within 200 units for 30 ticks.

## Boids

- **R-6** Each tick each bird updates velocity: separation (neighbors within 24 units), alignment (within 64), cohesion (within 96), leader attraction (toward the leader point of its sub-flock), wind, and obstacle avoidance; weights in `balance.json`; speed clamped to `[minSpeed, maxSpeed]`.
- **R-7** Neighbor queries use the spatial hash with deterministic iteration order (sorted by bird ID within a cell).

## Energy, Feeding, and Growth

- **R-8** Flock energy (per sub-flock, 0–1,000) drains by 1 per tick per 100 birds while flying; birds within a field's radius feed, adding energy by field richness (fields deplete and regrow).
- **R-9** For every 200 energy above 600, the sub-flock gains 5% birds (spawned at the flock's centroid); at 0 energy, birds drop out at 1% per 10 ticks.

## Predators

- **R-10** Falcons patrol and select dive targets: the bird group with the lowest local density at the flock's edge; a dive kills birds within a 30-unit radius of its path (density-dependent: fewer kills in dense areas) and forces a split if the dive passes through the centroid region.
- **R-11** Dense flocks (average neighbor count ≥ 10) reduce dive success by 50%.

## Roosts and Victory

- **R-12** During dusk, each roost counts birds within its radius per flock each tick; claim points accrue to the flock with the majority.
- **R-13** At day end, a roost is claimed by the flock with the most claim points; the day's winner holds more roosts (tie → more birds alive). In solo-objective regions (no rival), the goal is to roost a target number of birds.

## Invariants

- **INV-1** Bird count changes only through growth, falcons, starvation, and roost settling events.
- **INV-2** Birds never occupy obstacle interiors at tick end.
- **INV-3** Simulation is deterministic across devices (checkpoint hashes every 300 ticks).
- **INV-4** Spatial hash queries return exactly the neighbors a brute-force search returns (property test on 1,000 configurations).
