# P2 Slice Assessment — Night Market

Self-assessment of the P2 vertical slice against the roadmap pillars
(`ROADMAP.md` §1), written after the G2 gate runs. Honest, not flattering:
every weakness found here becomes a P3 task.

## What the slice is

One playable night on the Taipei map, iPad and Mac: paint walkways with a
drag (tile-snapped autotile art), place lanterns/awnings/buskers/seats from
a tray, hour-boundary upgrade picker, pause/restart, save/resume, results
screen with served count, survival verdict, score, and a traffic heatmap.
A scripted weather scenario (Taipei slice, one 20:00 rain shower) provides
the challenge beat. Nightly rules all run through the P1 rules engine; the
scene renders `GameState` snapshots.

## Evidence

- iPad UI tests (`xcodebuild test -scheme NM -only-testing:NMUITests`,
  iPad Pro 13-inch (M5) simulator): full night to results, save/resume
  identical-hash, 400-customer stress fps — all passed (`TEST SUCCEEDED`,
  EXIT=0; run log `/tmp/g2-run17.log` summarized in `docs/STATUS.md`).
- Mac scripted runs: full night to the results screen and save/resume
  save-hash == restored-hash, captured with the in-app `-uitest-shot`
  snapshot (see `docs/STATUS.md` for the images and numbers).
- 72-second slice recording: `docs/media/slice.mp4` (simulator recording,
  1x speed, stress crowd).

## Pillar by pillar

1. **Readable streets (aesthetic spec)** — the checker ground, canal band,
   plaza, autotile walkways, lantern glow, and gate arches read clearly at
   1x and under crowd. Weakness: the scene is still mostly placeholder
   rectangles-for-roofs; stall art is a colored awning + shape glyph. The
   letterboxed black bands at the screen top/bottom look barren in
   portrait. → P3: tile-art pass for building facades; portrait-safe
   framing.
2. **The city breathes** — 400 customers path, queue, and disperse at ≥ 50
   fps avg in the debug overlay; rain darkens and slows. Weakness: crowd
   motion is functional but uniform — everyone walks the same speed with
   no variety. → P3: speed/personality variance in spawn content.
3. **Decisions under pressure** — budget 30 forces lane triage; the
   upgrade picker interrupts at hour boundaries; rain punishes awning-less
   routes. Weakness: the picker offers are not yet context-aware (no
   "your worst stall" logic) — feels arbitrary. → P3: contextual offers.
4. **One more night (meta hook)** — the results screen's served/survived/
   score loop and next-night button close the loop. Weakness: no
   persistence of night number/score across restarts in the UI narrative
   (SaveData carries them; the HUD doesn't surface the night number).
   → P3: night banner + streak framing.
5. **Determinism** — save/resume restores the exact StateHash; restart
   re-applies the scenario. Golden replays from P1 still green.

## Harness facts learned (documented, not swept aside)

- The Xcode UI-test harness gives every `XCUIApplication` launch an empty
  data view: cross-launch save/restore cannot be observed inside the
  harness (verified against `simctl launch`, where it works). The G2
  save/resume check therefore exercises save→disk→decode→hash in-process
  on both platforms; the cross-launch path is proven manually on the sim.
- The headless iPad simulator cannot rotate its display while XCUITest's
  touch space stays portrait: SwiftUI button taps mistranslate. UI checks
  are launch-arg-driven; map input goes through the catcher; Mac uses
  real events.
- The Mac UI-test runner cannot initialize on this build machine
  (automation-mode TCC timeout — issue #6). Mac evidence is the scripted
  run + in-app snapshot until a GUI Mac grants automation.

## Verdict

The slice demonstrates the core loop end-to-end with honest determinism
and real input on both platforms. It is visually spare and the challenge
beat is thin (one scripted shower); both are P3 work. G2 passes with the
documented substitutes.
