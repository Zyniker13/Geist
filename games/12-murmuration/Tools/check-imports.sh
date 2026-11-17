#!/bin/bash
# S0.3: Core, Content, and AI are pure Swift — no UI, rendering, or platform frameworks.
set -euo pipefail
cd "$(dirname "$0")/.."

violations=0
for pkg in MUCore MUContent MUAI; do
  for banned in SwiftUI SpriteKit UIKit AppKit GameKit Metal MetalKit SceneKit RealityKit AVFoundation CloudKit CoreHaptics MapKit CoreMotion; do
    if grep -rqE "^[[:space:]]*import[[:space:]]+${banned}([[:space:]]|$)" "Packages/${pkg}/Sources" 2>/dev/null; then
      echo "check-imports: ${pkg} imports banned framework ${banned}"
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -gt 0 ]; then
  echo "check-imports: ${violations} violation(s)"
  exit 1
fi
echo "check-imports: OK"
