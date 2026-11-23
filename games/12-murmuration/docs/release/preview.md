# Murmuration — App Preview Notes (P10 draft)

Captured by the build agent with `Tools/release-preview.sh` on the
canonical iPad Pro 13-inch simulator. `preview.mp4` beside this file is
the raw capture, committed as the P10 draft. App Store Connect preview
placement, trimming, and any final re-record are maintainer items.

## Capture facts

- **Source:** `Tools/release-preview.sh` — `simctl io recordVideo
  --codec h264 --force`, self-playing launch flags
  (`-uitest-play -uitest-region meadow -uitest-seed 202611
  -uitest-fast 4 -uitest-falcons 3`).
- **Device:** zGeist_bot-iPad-Pro-13 (iPad Pro 13-inch simulator),
  portrait.
- **File:** `preview.mp4`, 53 s, 19 MB, 2064×2752, H.264 High, ~22 fps.
- **Limits respected:** capture under the 60 s record cap; file under
  the 25 MB commit cap.

## Frame notes (timings from the committed file)

| Range | What is on screen |
| --- | --- |
| 0:00–0:05 | Springboard lead-in before launch (by design). |
| ~0:05 | MU launches straight into the seeded auto-playing meadow day. |
| 0:05–0:53 | Continuous gameplay: flock streaming between fields, day ticking fast (×4), HUD counters live, falcon pressure visible as dark diamonds, roost disc absorbing birds near dusk. |

Verified frames: 0:03 (springboard, no dialogs), 0:25 (mid-play flock
river, HUD "Day 1/1 · birds 2,193 · energy 757", no overlays), 0:52
(active sim, 2,390 birds, Pause/Restart live, no dialogs).

## Maintainer items (for App Store Connect)

1. Trim to ≤30 s (a 15–30 s cut of 0:05–0:35 works: launch → flock
   stream → falcon stoop) and add captions.
2. Optionally re-record at Release build with music after signing is
   set up; this draft is Debug.
3. Export per-platform preview variants in App Store Connect and place
   the video first in the iPad portrait slot.
