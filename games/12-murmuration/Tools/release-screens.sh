#!/bin/zsh
# P10 release screenshots: captures the menu, a mid-flight flock over the
# meadow, the high-contrast rival look, and falcon-assist steering on the
# canonical iPad Pro 13-inch simulator into docs/release/screenshots/.
# Every play shot uses the same seed and pauses at a fixed tick, so the
# captures are reproducible.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
GAME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$GAME_DIR"
# Look up the UDID by name: device-set maintenance can recreate a
# simulator with a new UDID.
UDID=$(xcrun simctl list devices | grep 'zGeist_bot-iPad-Pro-13 (' | grep -Eo '[0-9A-F-]{36}')
test -n "$UDID" || { echo "no zGeist_bot-iPad-Pro-13 found"; exit 1; }
echo "using $UDID"
# Resolve the Debug simulator product from build settings (never hardcode
# a machine-specific DerivedData path in the repo).
APP=$(xcodebuild -scheme MU -configuration Debug -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3; exit}')/MU.app
test -d "$APP" || { echo "MU.app not built: run 'make build' (Debug) first"; exit 1; }
echo "using $APP"
OUT="$GAME_DIR/docs/release/screenshots"
mkdir -p "$OUT"
BUNDLE=com.example.murmuration

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

# The iOS 27.2 simulator draws a window-resize handle (a small gray arc) in
# the bottom-right corner of every app window; the home screen has none and
# a device build has none, so it is pure capture chrome. Cover it with the
# 74x72 rect directly above the corner (that donor zone is uniform in every
# captured frame). Needs ffmpeg (FFMPEG env var or PATH); skipped with a
# warning otherwise.
fix_corner() {
  FFMPEG="${FFMPEG:-$(command -v ffmpeg || true)}"
  if [ -z "$FFMPEG" ]; then
    echo "WARN: ffmpeg not found; leaving simulator resize arc in $1"
    return 0
  fi
  "$FFMPEG" -hide_banner -loglevel error -i "$OUT/$1.png" \
    -vf "crop=74:72:1990:2608" "$OUT/$1.corner.png" -y
  "$FFMPEG" -hide_banner -loglevel error -i "$OUT/$1.png" -i "$OUT/$1.corner.png" \
    -filter_complex "overlay=1990:2680" "$OUT/$1.fixed.png" -y
  mv "$OUT/$1.fixed.png" "$OUT/$1.png"
  rm -f "$OUT/$1.corner.png"
}

shot() {
  xcrun simctl io "$UDID" screenshot "$OUT/$1.png" > /dev/null
  fix_corner "$1"
  echo "captured $1"
}

# 1. Menu (fresh install, no flags: -uitest-play would skip straight to
#    the play surface, so launch bare).
xcrun simctl launch "$UDID" "$BUNDLE"
sleep 6
shot 01-menu

# 2. Mid-flight flock: seeded meadow day, sim paused at a fixed tick so
#    the frame is reproducible.
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-play -uitest-region meadow \
  -uitest-seed 202611 -uitest-fast 6 -uitest-pause-at 15000
sleep 50
shot 02-flock

# 3. High-contrast rivals, same seed and tick.
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-play -uitest-region meadow \
  -uitest-seed 202611 -uitest-fast 6 -uitest-pause-at 15000 -uitest-high-contrast
sleep 45
shot 03-high-contrast

# 4. Falcon assist steering, same seed and tick.
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-play -uitest-region meadow \
  -uitest-seed 202611 -uitest-fast 6 -uitest-pause-at 15000 -uitest-assist
sleep 45
shot 04-assist

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "done: $OUT"
