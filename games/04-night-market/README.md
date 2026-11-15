# Night Market

A 2D grid-based market management game. Build stalls, place fixtures, manage queues, and survive the night.

## Stack

- **Language:** Swift 6.0
- **Platform:** iOS (iPad-first), macOS (Catalyst)
- **Build:** XcodeGen + SwiftPM packages
- **Testing:** XCTest + Swift Testing
- **Lint:** SwiftLint + swift-format

## Packages

| Package | Path | Depends On |
|---------|------|------------|
| NMCore | `Packages/NMCore/Sources/NMCore` | — |
| NMContent | `Packages/NMContent/Sources/NMContent` | NMCore |
| NMAI | `Packages/NMAI/Sources/NMAI` | NMCore, NMContent |
| NMRender | `Packages/NMRender/Sources/NMRender` | NMCore |
| NMAudio | `Packages/NMAudio/Sources/NMAudio` | NMCore |
| NMPlatform | `Packages/NMPlatform/Sources/NMPlatform` | NMCore |
| NMMeta | `Packages/NMMeta/Sources/NMMeta` | NMCore |

## Building

```bash
make gen    # Generate Xcode project
make build  # Build iOS + macOS
make test   # Run all tests
make lint   # Run linters
```

## Determinism

All randomness uses `SeededRNG` (Xoshiro256** seeded via SplitMix64). System random, `Date()`, and `UUID()` are banned in Core, Content, and AI via SwiftLint custom rules.

## License

All rights reserved. See `../../LICENSE`.
