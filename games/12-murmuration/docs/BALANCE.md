# Murmuration — Balance Report (P4)

Source of truth for the MU-P4.1 balance work: the tier table, the sweep
method, and the measured targets from `ROADMAP.md` §6
(Autoplayer vs Gentle/Normal/Hard, 500 days per region): Autoplayer win
rates 85% / 60% / 35%; median flock size at dusk 1,000–2,500; falcon
losses 5–20% of peak flock.

## Method

The headless sim (`Tools/sim`, Release) runs `--balance <tier>`:
Autoplayer vs the tiered `GentleRival` on each shipped region, one seeded
day per row (`region.reseeded(day)`), mirroring the app's model loop
(autoplayer action, rival action, `applyTick`). Probes add CLI overrides
(`--rival-gate/-ratio/-splitmin/-standoff/-start`, `--falcon-budget`)
so the tier table is derived from measurements, not guesses; the chosen
values are then hard-coded in `GentleRival.cadence(_:)` and verified by
the recorded sweeps.

## History

| Stage | Engine | Gentle | Normal | Hard | Note |
| --- | --- | --- | --- | --- | --- |
| balg3 (2026-11-20) | v12 pre-ADR-0033 | 57.3% | 72.2% | — | side-ownership bug |
| balg4 (2026-11-20) | v13 post-ADR-0033 | 75.7% | 85.0% | 90.3% | ordering inverted |
| balg4b (2026-11-21) | v16 + ADR-0036 | 72.7% | 84.4% | 79.6% | shipped (ADR-0037) |

balg4 per-region player win rates (100 days each): commons 56/68/72%,
delta 67/76/91%, gorge 70/84/90%, ridge 77/91/93%, fenlands 84/91/96%,
meadow 100/100/100% (gentle/normal/hard).

## Final G4 sweep (balg4b, v16 binary, 500 days per region)

Autoplayer (player) win rates, one seeded day per row:

| Region | Gentle | Normal | Hard |
| --- | --- | --- | --- |
| commons | 52.2% | 67.6% | 61.6% |
| delta | 66.4% | 81.8% | 81.0% |
| fenlands | 84.6% | 91.6% | 87.6% |
| gorge | 52.6% | 80.6% | 63.2% |
| meadow | 100.0% | 99.8% | 100.0% |
| ridge | 80.4% | 84.8% | 84.0% |
| **Overall** | **72.7%** (2181/3000) | **84.4%** (2531/3000) | **79.6%** (2387/3000) |

Median player flock at dusk (per tier, across regions): gentle 394–1944,
normal 408–2019, hard 357–2360. Median falcon losses (player): 1.0–2.0%
of peak per day — below the 5–20% design band, corridor-bound (see the
falcon section). Zero crashes across all 9,000 swept days; rival pilot
cost peaked at 133.9 µs/tick and the autoplayer at 20.8 µs/tick, both far
under the 0.5 ms/tick budget.

Against the ROADMAP §6 targets (85/60/35): gentle and normal miss in
opposite directions and hard sits ~45 points high. The probe rounds above
show the remaining levers cannot reach the targets; ADR-0037 records the
deviation and the structural cause (the autoplayer's parked condense
drives a 3:1 growth advantage the rival cannot match without a condense
model redesign).

## Structural findings (probe rounds 1–3, 2026-11-21)

1. `forageInterval` is vestigial — the forage directive re-decides every
   tick; the effective day levers are `standoffDistance` and the flee
   cadence. A small standoff makes the rival graze the player's fields
   and fly more (the ADR-0032 drain applies in flight), so hard starved
   itself to ~0.47× the player and then tripped its own 2:1 contest
   guard, claiming zero roosts (rival roosts median 0 on hard in balg4).
2. The dusk-claim gate and the field standoff are different dials
   (ADR-0035): a low claim gate + a large field standoff is the strong
   combination — commons normal-tier player wins dropped 73.3% → 63.3%
   with gate 320 + standoff 640 (rival out-grows the player and wins
   bird-count tiebreaks).
3. A falcon forcedSplit mints a second flock on the struck flock's own
   side (ADR-0033). `planHard` used to answer with a dusk split that the
   per-side cap then rejected, spending the plan with neither flock
   routed; it now routes the two existing flocks to the two top roosts.
4. Meadow (single center roost) is structurally player-favored: the
   player's larger flock always holds the majority at the only roost, so
   every tier shows ~100% Autoplayer wins there. Recorded as a known
   shape, not tuned away (the global targets absorb it).

## Falcon losses

With the ADR-0034 stoop-path grab budget (8 per 1,000), daily falcon
kills are corridor-limited: the stoop targets the flock's sparse edge,
so the dive corridor (`diveRadius` 30 around the falcon→target→+60
segment) holds only a handful of birds; measured losses run ~1–2% of the
peak flock per day, below the 5–20% design band. Raising the grab budget
does not move the number (probe rounds: budgets 8/20/32/48 produce
identical days) because the corridor, not the budget, binds. Recorded as
an ADR-0035 note: the falcon-loss target is unreachable by budget tuning
alone; widening the corridor is a visible-behavior change deferred to the
P8 feel pass.

(Numbers refreshed after the final G4 sweep; see the tables above. The
falcon-loss finding is confirmed at 500-day scale: medians 1.0–2.0% of
peak per day, all tiers.)
