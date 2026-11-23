#!/bin/zsh
# P10 app-preview capture: records a self-playing meadow day with
# `simctl io recordVideo` on the canonical iPad Pro 13-inch simulator
# into docs/release/preview.mp4. The raw capture is committed here;
# trimming, upload, and App Store Connect placement are maintainer
# items (see docs/release/preview.md).
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
GAME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$GAME_DIR"
UDID=$(xcrun simctl list devices | grep 'zGeist_bot-iPad-Pro-13 (' | grep -Eo '[0-9A-F-]{36}')
test -n "$UDID" || { echo "no zGeist_bot-iPad-Pro-13 found"; exit 1; }
echo "using $UDID"
# Resolve the Debug simulator product from build settings (never hardcode
# a machine-specific DerivedData path in the repo).
APP=$(xcodebuild -scheme MU -configuration Debug -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3; exit}')/MU.app
test -d "$APP" || { echo "MU.app not built: run 'make build' (Debug) first"; exit 1; }
echo "using $APP"
OUT="$GAME_DIR/docs/release/preview.mp4"
BUNDLE=com.example.murmuration

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

# Record for 55 s (hard limit 60): home-screen lead-in, fresh launch
# into a seeded auto-playing day with fast-forward ticks, falcons on.
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT" &
REC=$!
sleep 5
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-play -uitest-region meadow \
  -uitest-seed 202611 -uitest-fast 4 -uitest-falcons 3
sleep 48
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "done: $OUT"
