# Orrery

A two-player abstract strategy game on brass rings that turn like planetary orbits. Line up three of your planets and the eclipse captures everything between.

## Stack

- **Language:** Swift 6.0
- **Platform:** iOS (iPad-first), macOS
- **Build:** XcodeGen + SwiftPM packages
- **Testing:** Swift Testing + XCTest/XCUITest
- **Lint:** SwiftLint + swift-format

## Packages

| Package | Depends On |
|---------|------------|
| ORCore | — |
| ORContent | ORCore |
| ORAI | ORCore, ORContent |
| ORRender | ORCore |
| ORAudio | ORCore |
| ORPlatform | ORCore |
| ORMeta | ORCore, ORContent |

## Building

```bash
make gen    # Generate Xcode project
make build  # Build iOS + macOS
make test   # Run all tests
make lint   # Run linters
```

## Determinism

All rules math uses integers (`Int`, `Angle48`, `Fixed`). `SeededRNG` is the only randomness source; System random, `Date()`, and `UUID()` are banned in Core, Content, and AI via SwiftLint custom rules and `Tools/check-imports.sh`.

## License

All rights reserved. See `../../LICENSE`.
