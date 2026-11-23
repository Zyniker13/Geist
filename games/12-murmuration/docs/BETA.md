# Murmuration — Beta Notes and Tester Guide

Everything here is prepared by the build agent; TestFlight upload and
group management are maintainer items (see `docs/STATUS.md` and the open
`needs-maintainer` issues).

## What this build is

Murmuration is a flock-herding strategy game: you steer one starling
flock through ten iPad-first regions, splitting it to feed across
scattered fields while rival flocks contest roosts and falcons scatter
unprotected birds. Ten regions (Meadow tutorial through Summit), three
AI difficulty tiers (gentle/standard/hard), a five-step tutorial, daily
challenges with one modifier each, and a leaderboard per region.

## How to test (10-minute pass)

1. Launch → the menu lists Play, versus mode, region select, and
   settings. Pick Play on the Meadow first.
2. Steer with a finger or Apple Pencil: the flock follows your touch;
   the leader-point ring shows the steering target. Birds forage at
   fields, then must return to a roost before the day ends.
3. Try splitting: drag a finger away from the main flock — birds split
   off to reach a second field while rivals take the contested roost.
   Falcon assist (Settings) makes falcons avoid the flock, for early
   players.
4. Let the day end: the results screen shows birds fed, roost share,
   and the rival outcome; the debug overlay (three-finger double tap)
   shows FPS, tick, seed, and state hash.
5. Pause/resume from the pause button or the Mac `Game` menu; play on
   iPad or Mac.

## What to report

- Anything that looks wrong: flock steering feels imprecise, birds
  stuck, falcon behavior unfair, unreadable colors (high-contrast rival
  toggle exists in Settings), text clipped.
- Performance: frame hitches at large flock sizes (the debug overlay
  shows FPS; the target is 60 fps with 3,000 birds on a real iPad, 120
  on ProMotion).
- VoiceOver: swipe through the menu and results and confirm labels make
  sense.

## Builds

- `make test` must be green on the exact commit; see `docs/STATUS.md`.
- Local substitutes used instead of device checks are listed in
  `docs/STATUS.md` (G7/G8) and issue #11.
- Stats export is opt-in only: Settings → "Include my stats in exports"
  → "Export Stats to Documents" writes `murmuration-stats.json` to the
  app's Documents folder. Nothing is uploaded; the file holds aggregate
  play counts only (no identifiers). Export it and share the file if
  you want the balance pass to include your data.
