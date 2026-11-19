import XCTest
import MUCore
@testable import MUContent

/// P3.2 regression tests for the flat-bundle region loaders. The app bundle
/// flattens the resource tree, so the region files sit at the bundle root
/// (no `Content/regions` subdirectory). `loadNamedRegions` must load them by
/// name from a flat directory (ADR-0024).
final class RegionCatalogTests: XCTestCase {
    /// Game root, derived from this source file's path.
    private var gameRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    private var regionsDir: URL {
        gameRoot.appendingPathComponent("Resources/Content/regions")
    }

    func testLoadNamedRegionsFromFlatDirectory() throws {
        let flatDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mu-flat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: flatDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: flatDir) }

        let names = ["commons", "delta", "fenlands", "gorge", "meadow", "ridge"]
        for name in names {
            let src = regionsDir.appendingPathComponent("\(name).json")
            let dst = flatDir.appendingPathComponent("\(name).json")
            try FileManager.default.copyItem(at: src, to: dst)
        }

        let regions = try RegionCatalog.loadNamedRegions(names, from: flatDir)
        XCTAssertEqual(regions.count, 6, "expected six regions from the flat directory")
        XCTAssertEqual(Set(regions.map(\.id)), Set(names), "unexpected region ids")
    }

    func testLoadNamedRegionsThrowsWhenFileMissing() throws {
        let flatDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mu-flat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: flatDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: flatDir) }

        let src = regionsDir.appendingPathComponent("meadow.json")
        let dst = flatDir.appendingPathComponent("meadow.json")
        try FileManager.default.copyItem(at: src, to: dst)

        XCTAssertThrowsError(
            try RegionCatalog.loadNamedRegions(["meadow", "ridge"], from: flatDir),
            "expected a throw when a named region file is missing"
        ) { error in
            XCTAssertEqual(error as? RegionError, .missingRegions)
        }
    }
}
