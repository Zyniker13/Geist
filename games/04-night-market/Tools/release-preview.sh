#!/bin/bash
# P10 app preview video: record a mid-night market sequence (glow, steam,
# crowd flow) on the 13-inch iPad Pro simulator and finalize with SIGINT.
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DEV=EE7C4629-CD3E-4312-ADE1-920B9B615417
OUT="$(cd "$(dirname "$0")/../docs/release" && pwd)/preview.mp4"
BUNDLE=com.example.night-market
APP=/Users/agent/Library/Developer/Xcode/DerivedData/NightMarket-eormriyvtokrsfdujmzvnqtbvkld/Build/Products/Debug-iphonesimulator/NM.app

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b > /dev/null
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$DEV" "$APP"

xcrun simctl io "$DEV" recordVideo --codec h264 --force "$OUT" &
REC=$!
sleep 10
xcrun simctl launch "$DEV" "$BUNDLE" -uitest-fresh -uitest-autolane -uitest-autochoose
sleep 55
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
kill -INT "$REC"
wait "$REC" 2>/dev/null
echo "preview: $OUT"
ls -la "$OUT"
