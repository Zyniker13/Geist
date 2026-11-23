# RULES.md — Core Rules Specification (copied from ROADMAP.md §4; rule IDs are canonical)

**Board**
- R-1 Angles are integers mod 48 (`Angle48`). Four rings, indexed 1 (inner) to 4 (outer).
- R-2 Standard variant slot counts: ring 1 = 8 slots (every 6 units), ring 2 = 12 (every 4), ring 3 = 16 (every 3), ring 4 = 24 (every 2). Slot `k` of ring `i` sits at angle `(offset_i + k × 48 / slots_i) mod 48`.
- R-3 Each ring has an `offset` (initially 0 in Standard) and a `speed` in angle units per round: Standard speeds ring 1 = +12, ring 2 = +8, ring 3 = −3, ring 4 = +2 (negative = counter-rotation).
- R-4 Each player starts with 10 planets in reserve. Player 1 (cobalt) moves first.

**Turn**
- R-5 On a turn the player takes exactly one action: `place(ring, slot)` into an empty slot from reserve, or `nudge(ring, ±1 slot)` which immediately rotates that ring by one slot step (changes `offset` by `±48/slots_i`).
- R-6 Nudge ko: a player may not nudge the ring the opponent nudged on the immediately preceding turn in the opposite direction (prevents undo loops). A player may not nudge two turns in a row (they must place in between) unless their reserve is empty.
- R-7 After both players have taken a turn (one round), all rings rotate by their speed (`offset += speed`).
- R-8 If a player has no legal action, they pass.

**Lines, Alignment, and Capture**
- R-9 A line is an unordered pair of opposite angles `{a, a+24}` for `a` in 0…23.
- R-10 A planet's signed position on line `{a, a+24}` is `+ring` if its angle is `a`, `−ring` if its angle is `a+24`.
- R-11 An alignment for player P exists on a line when ≥ 3 of P's planets lie on it.
- R-12 Capture: for an alignment with signed positions S, every enemy planet on that line with signed position strictly between `min(S)` and `max(S)` is captured (removed from the game and counted for P).
- R-13 Alignment checks happen (a) after every action, for the acting player only, and (b) after the round rotation (R-7), for the player who moves next first, then the other player, each using the board state after the previous player's captures.
- R-14 Grand Alignment: if a player has one planet on each of the 4 rings on the same angle `a` (same ray, not the opposite side), that player wins immediately (checked whenever alignments are checked, before captures).

**Victory**
- R-15 A player who captures 5 enemy planets wins.
- R-16 The game ends after 20 rounds; the player with more planets on the board wins; tie → more captures; tie → Player 2 wins (compensates first-move advantage; verify in sims).
- R-17 A player with no planets on the board and none in reserve loses.

**Invariants**
- INV-1 Each slot holds at most one planet; planets in reserve + on board + captured = 10 per player.
- INV-2 Ring offsets stay in 0…47 after normalization.
- INV-3 Captures only remove the opponent's planets.
- INV-4 Replay determinism (same seed and actions → same hash).
- INV-5 Alpha-beta at depth d returns the same best move as plain minimax at depth d on 500 random positions (d ≤ 3).
