# Night Market — Beta Notes and Tester Guide

Everything here is prepared by the build agent; TestFlight upload and
group management are maintainer items (see `docs/STATUS.md` and the open
`needs-maintainer` issues).

## What this build is

Night Market is a cozy night-market management game: you pave walkways,
light lanterns, hire buskers, and place seats so customers flow from the
gates to the stalls and get served before the night ends at dawn. Six
maps (Taipei, Seoul, Bangkok, Marrakesh, Istanbul, Oaxaca), three
schedules, daily and weekly challenges with one modifier each, and a
per-map leaderboard set.

## How to test (10-minute pass)

1. Launch → the launcher sheet lists today's daily and weekly challenge
   and the unlocked maps. Pick the daily challenge.
2. Drag walkway tiles from the gates toward the stalls with a finger or
   Apple Pencil (hover highlights the tile under the tip; squeeze toggles
   erase). Customers appear after 18:00 and follow the walkways.
3. Watch a stall's queue badge: above the cap the overflow warning
   escalates; after the grace window the night ends. Assist mode (in the
   launcher) lengthens the grace window by 50%.
4. Let the night end: the results screen shows serves, unlocks, and the
   achievements earned; the debug overlay's POSTS row counts the
   leaderboard/achievement posts (Game Center requires a sandbox sign-in,
   issue #9).
5. Pause/resume/save from the Mac `Game` menu, or play on iPad.

## What to report

- Anything that looks wrong: customers stuck, tiles misplacing, unreadable
  colors (a high-contrast toggle exists in the launcher), text clipped.
- Performance: frame hitches in crowds (the debug overlay shows FPS; the
  target is 60 fps with 600 customers on a real iPad, 120 on ProMotion).
- VoiceOver: swipe through and confirm the queue summary makes sense.

## Builds

- `make test` must be green on the exact commit; see `docs/STATUS.md`.
- Local substitutes used instead of device checks are listed in
  `docs/STATUS.md` (G7/G8) and issues #8/#9.
