# Murmuration — Open Questions

From `ROADMAP.md` §13, with defaults in force until the maintainer answers.

1. **Device-class bird caps?** Default in force: leaderboards use a fixed cap of
   3,000 birds on all devices; visuals may render fewer. (No issue filed — the default
   is safe for cross-device parity.)
2. **Static-leader orbit radius and feel?** With `minSpeed` 18 units/tick a bird
   cannot stop, so a static leader point is orbited (measured: single bird settles
   into a slow spiral toward the leader, centroid of a 250-bird swarm wobbles at
   ~100–180 units). Default in force: gameplay steers with moving leader paths
   (R-3/R-4), so this only affects the "leader circling last position" idle state
   (R-4). Revisit feel at the P8 balance pass; no issue filed.
3. **Emergent flock cohesion at game densities?** Probes show a 250-bird cluster with
   random initial headings disperses to a ~1,300-unit-radius gas (sep 1.5 > coh 0.8,
   plus low neighbor density once dispersed); with aligned headings this should differ
   but is unmeasured. Default in force: keep the roadmap-fixed weights (1.5/1.0/0.8/
   1.2/0.6) and rely on the moving leader (R-3) to keep the flock together during
   play; the pinch gesture (cohesion ×2, R-4) exists for tightening. Measure with
   real gameplay scenarios in P1.2/P2 and retune via `balance.json` at P8 if the
   flock will not hold together; no issue filed yet.
4. **Speed saturation near max?** Probe flocks ratchet from 28 to ~35–38 units/tick
   over a few hundred ticks (forces partially aligned with velocity add energy; the
   min-speed rescale only injects below 18). Default in force: acceptable for now —
   birds cruise fast, the hard max clamp holds. Revisit at P8 (a drag term or
   force-projection rescale would be the candidate); no issue filed yet.
