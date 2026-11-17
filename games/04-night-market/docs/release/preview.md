# Night Market — App Preview Video (P10 capture)

Captured by the build agent with `simctl io recordVideo` on the
13-inch iPad Pro simulator (see `Tools/release-preview.sh`). Upload,
trimming, and App Store Connect asset placement are maintainer items.

## What the capture shows (frame-probed)

- `0:00–0:10` — iPad home screen: recording starts before the app
  launches. **Trim this lead-in for any App Store cut.**
- `0:10` — fresh launch straight into a Taipei night (UI-test
  autochoose): stalls lit, lantern glow, first customers arriving.
- `0:30` — early night (18:18, 3 visitors): stall cluster lit, glow
  over the plot.
- `0:45` — the auto-built walkway lane filling from the gates toward
  the stalls (12/30 placed), visitor dots walking the path.
- `0:55` — mid night (18:43, Score 4, Walkway 12/30, 5 visitors):
  walkway, stalls, seating, lantern glow all live.

Rain is scenario-scripted and verified on-sim in the P2/P6 evidence,
but no rain appears inside this 55 s gameplay window — do not promise
rain in the trimmed preview.

## Specs (measured from the committed file)

- Device: iPad Pro 13-inch (M5) simulator, portrait.
- Codec: H.264 High, yuv420p, 2064×2752, ~1187 kb/s, 65.29 s total
  (`ffprobe`/`ffmpeg -i` output).
- App Store preview target: 15–30 s. Recommended maintainer edit: cut
  `0:10–0:35` (launch + first crowd wave + lane build); no audio track
  is required (the procedural soundtrack is in-app only and not
  captured by `simctl io`).

## How it was produced

`Tools/release-preview.sh` installs the Debug app on the simulator,
starts `recordVideo --codec h264 --force`, launches the app with the
UI-test launch arguments (`-uitest-fresh -uitest-autolane
-uitest-autochoose`) so the night plays itself, and finalizes the file
with SIGINT after the terminate. The raw capture is committed at
`docs/release/preview.mp4`.
