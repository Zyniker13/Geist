#!/bin/zsh
# P10 release screenshots: captures the launcher, a mid-night market, the
# results screen, and the high-contrast look on the canonical iPad Pro
# 13-inch simulator into docs/release/screenshots/.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Look up the UDID by name: device-set maintenance can recreate a
# simulator with a new UDID.
UDID=$(xcrun simctl list devices | grep 'zGeist_bot-iPad-Pro-13 (' | grep -Eo '[0-9A-F-]{36}')
test -n "$UDID" || { echo "no zGeist_bot-iPad-Pro-13 found"; exit 1; }
echo "using $UDID"
APP=/Users/agent/Library/Developer/Xcode/DerivedData/NightMarket-eormriyvtokrsfdujmzvnqtbvkld/Build/Products/Debug-iphonesimulator/NM.app
OUT="$(dirname "$0")/../docs/release/screenshots"
mkdir -p "$OUT"
BUNDLE=com.example.night-market

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

shot() {
  xcrun simctl io "$UDID" screenshot "$OUT/$1.png" > /dev/null
  echo "captured $1"
}

# 1. Launcher (fresh install, no flags: any -uitest-* suppresses the
#    NewNightMenu in GameScreen.onAppear, so launch bare — no save exists
#    after the uninstall above, so showLauncher becomes true).
xcrun simctl launch "$UDID" "$BUNDLE"
sleep 6
shot 01-launcher

# 2. Mid-night market (auto-built lane, several minutes in for glow/steam).
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-fresh -uitest-autochoose -uitest-autolane
sleep 45
shot 02-market

# 3. High contrast look.
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-fresh -uitest-highcontrast -uitest-autolane
sleep 20
shot 03-high-contrast

# 4. Results screen (fast night to the end).
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -uitest-fresh -uitest-autochoose -uitest-fast
sleep 75
shot 04-results

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "done: $OUT"
