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
| ADR-0035 retune | v14/v15 | — | — | — | this pass |

balg4 per-region player win rates (100 days each): commons 56/68/72%,
delta 67/76/91%, gorge 70/84/90%, ridge 77/91/93%, fenlands 84/91/96%,
meadow 100/100/100% (gentle/normal/hard).

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

(Numbers refreshed after the final G4 sweep; see the tables below.)
