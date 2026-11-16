# Murmuration — Phase and Gate Evidence

## P0 (Setup) — PASSED

**Spec:**

- Repo layout: `Config/`, `App/iOS/`, `App/macOS/`, `App/Shared/`, `Resources/`, `Tests/UITests/`, `Tools/`, `docs/`, `Packages/{MMCore,MMContent,MMLogic,MMRender,MMPlatform,MMMeta}/`
- XcodeGen: iOS target `MM` + macOS target `MM-macOS` in `project.yml`; configFiles → `Config/Bundle.xcconfig`; SWIFT_VERSION 6.0; deployment targets iOS 26.0 / macOS 26.0
- SwiftPM packages: MMCore (no deps), MMContent (→ MMCore), MMLogic (→ MMCore), MMRender (→ MMCore), MMPlatform (→ MMCore), MMMeta (no deps) — each with Sources and Tests
- CI: `.github/workflows/murmuration.yml` — lint + test jobs on main, paths `games/12-murmuration/**`
- Lint configs: `.swiftlint.yml` (same rules as Night Market: `banned_random` regex, opt-in rules, excluded dirs); `.swift-format` (JSON, matches Night Market)
- Stub sources/tests in every package (compile cleanly)
- Bundle ID placeholder: `com.example.murmuration`
- Initial test scaffolding: XCTest `testExample` → `XCTAssertTrue(true)` in every package + UITests

**Evidence:**

- `make gen` (xcodegen generate) — exit 0
- `make build` (iOS + macOS) — exit 0, **BUILD SUCCEEDED** on both
- `swift test` (all 6 packages) — exit 0, 0 violations
- `swiftlint --strict` — 0 violations in 23 files
- `swift-format lint --recursive` — exit 0

**Sign-off:** GLM-SELF, on the evidence above.
