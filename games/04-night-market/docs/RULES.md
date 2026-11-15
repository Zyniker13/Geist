# RULES.md — Core Rules Specification (copied from ROADMAP.md §4; rule IDs are canonical)

**Map and Setup**
- R-1 The grid is 32×20 tiles; tiles are `ground`, `water` (canal, impassable without a bridge), `building` (impassable), or `plaza`.
- R-2 A map defines gates (2–4 at the edge), weighted spawn zones per stall color, and a stall schedule (R-6).
- R-3 Start: 2 stalls open (seeded positions from zones), 1 gate active, walkway budget 30 tiles, 2 lanterns, 0 awnings, 0 buskers.

**Clock**
- R-4 The night runs from 18:00 to 06:00; one in-game hour = 1,800 ticks (60 seconds at 1×).
- R-5 At each hour boundary the player chooses 1 of 2 upgrade offers (drawn by seed from `upgrades.json` weights); the simulation pauses until a choice is made.

**Stalls, Customers, and Gates**
- R-6 Schedule: new stalls open at scheduled ticks (± seeded jitter of up to 300 ticks), placed by weighted zone sampling on free ground tiles at least 3 tiles from other stalls; a new gate opens at 21:00 and 00:00 if the map has more.
- R-7 Customers spawn at gates at a rate that ramps by hour (`spawnRate[hour]` customers per minute), with color chosen proportionally to open stalls of each color.
- R-8 Customer lifecycle: walk to the nearest reachable stall of its color via flow field → join queue → be served → walk to the nearest reachable free seat within 8 path tiles (if any; sits 300 ticks) → walk to the nearest gate → despawn.
- R-9 A customer with no reachable stall of its color waits at the gate; waiting customers count toward that color's nearest stall's overflow (R-12).

**Movement and Steering**
- R-10 Movement is only on walkway, plaza, and bridge tiles. Edge cost (per tile step): base 10; dark tile (no lantern within radius 3) +6; rain and no awning +12; within busker radius 2 −3 (min 4); corner turn +2.
- R-11 Speed: base 48 units/tick; on a tile with n customers, speed = base × (100 − 15 × (n − 1)) / 100, min 12.

**Service and Overflow**
- R-12 Each stall serves one customer per `serviceTicks` (default 90). Queue capacity is 6 plus waiting gate customers attributed to it. When the queue exceeds capacity, an overflow timer runs (shown as a ring); it resets to 0 when back under capacity. Timer ≥ 600 ticks (20 s) ends the night.
- R-13 Score = customers served; a full night survived (reaching 06:00) adds a dawn bonus of 25% of the score.

**Actions (Allowed While Paused or Running)**
- R-14 `paintWalkway([Tile])` consumes budget per new tile; tiles must be ground or plaza; `eraseWalkway([Tile])` refunds the budget fully (no penalty) but customers on erased tiles are moved to the nearest walkway. The same relocation applies to any edit that makes a customer's tile untraversable (e.g. moving a bridge off its span); seat-seekers whose target seat becomes unreachable give up and walk to the exit instead. Edits never leave a customer on a non-traversable tile.
- R-15 `placeFixture(kind, tile)` and `moveFixture(id, tile)`: lanterns light radius 3; awnings cover a 3×3 area; buskers attract within radius 2; bridges span exactly 1–3 water tiles in a straight line.
- R-16 `chooseUpgrade(id)` at hour boundaries; `setSpeed(1|2|3)`; `pause`/`resume`.

**Weather**
- R-17 Rain showers are scheduled by seed (0–3 per night, 90–180 s each, never before 19:00); during rain the R-10 penalty applies.

**Invariants**
- INV-1 Walkway tiles used ≤ budget.
- INV-2 Customers occupy only traversable tiles; no customer is in two queues.
- INV-3 Customers served is non-decreasing.
- INV-4 Flow fields are consistent: following the field from any reachable tile reaches a stall of that color in finite steps.
- INV-5 Replay determinism (same seed and timed actions → same hash at every 1,800-tick checkpoint).
