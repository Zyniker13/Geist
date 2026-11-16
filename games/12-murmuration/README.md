# Murmuration

Flocking simulation game. Guide a flock to match target patterns.

## Build

```bash
make gen    # Generate Xcode project
make build  # Build iOS + macOS
make test   # Run tests
make lint   # Run linters
```

## Stack

- SpriteKit
- Swift 6.0
- XcodeGen + SwiftPM
- iOS 17.0 / macOS 14.0

## Structure

```
Packages/
├── MMCore      — Game state, rules, deterministic simulation
├── MMContent   — Maps, patterns, objectives
├── MMLogic     — Flocking algorithms
├── MMRender    — SpriteKit rendering
├── MMPlatform  — iOS/macOS integration
└── MMMeta      — Versioning and metadata
```
