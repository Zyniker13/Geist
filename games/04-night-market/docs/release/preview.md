# Night Market — App Preview Video (P10 draft)

Captured by the build agent with `simctl io recordVideo` on the
13-inch iPad Pro simulator (see `Tools/release-preview.sh`). Upload,
trimming, and App Store Connect asset placement are maintainer items.

## What the capture shows

- A fresh launch straight into a night: the auto-built walkway lane
  fills from the gates toward the stalls.
- Customer flow through the lane with steam and lantern glow at full
  night lighting; rain passes mid-capture on the default scenario.
- The HUD (clock, budget, queue badges) updating live.

## Specs

- Device: iPad Pro 13-inch (M5) simulator, portrait.
- Codec: H.264 (`--codec h264`), as recorded by `simctl io`.
- Length: ~65 s of a single night, captured 10 s after recording start
  so the app is already on the market scene.
- App Store preview target: 15–30 s. Trimming to the first ~25 s of
  gameplay (the lane build plus the first crowd wave) is the recommended
  maintainer edit; no audio track is required (the procedural
  soundtrack is in-app only and not captured by `simctl io`).

## How it was produced

`Tools/release-preview.sh` installs the Debug app on the simulator,
starts `recordVideo --codec h264 --force`, launches the app with the
UI-test launch arguments (`-uitest-fresh -uitest-autolane
-uitest-autochoose`) so the night plays itself, and finalizes the file
with SIGINT after the terminate. The raw capture is committed at
`docs/release/preview.mp4`.
