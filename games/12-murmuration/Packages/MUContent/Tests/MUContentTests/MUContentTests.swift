import XCTest
import MUCore
@testable import MUContent

/// Region catalog tests (S2.3). The suite loads the actual shipped regions
/// from `Resources/Content/regions` so the content and its validation stay in
/// lock-step, plus synthetic invalid regions for the validator itself.
final class MUContentTests: XCTestCase {
    /// Game root, derived from this source file's path.
    private var gameRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    private var regionsDir: URL {
        gameRoot.appendingPathComponent("Resources/Content/regions")
    }

    // MARK: - Shipped content

    func testCatalogLoadsThreeRegions() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        XCTAssertEqual(catalog.regions.count, 3, "expected three shipped regions")
        XCTAssertEqual(
            Set(catalog.ids),
            ["meadow", "ridge", "delta"],
            "unexpected region ids: \(catalog.ids)"
        )
    }

    func testEveryShippedRegionIsValid() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        let invalid = catalog.validateAll()
        XCTAssertTrue(invalid.isEmpty, "invalid regions: \(invalid)")
    }

    func testRegionLookupById() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        XCTAssertNotNil(catalog.region(id: "meadow"))
        XCTAssertNotNil(catalog.region(id: "ridge"))
        XCTAssertNotNil(catalog.region(id: "delta"))
        XCTAssertNil(catalog.region(id: "nope"))
    }

    // MARK: - GameState construction

    func testMakeGameStateMatchesRegionDefinition() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        for region in catalog.regions {
            let state = region.makeGameState()
            XCTAssertEqual(
                Int(state.birds.count), region.birdCount,
                "\(region.id): bird count mismatch"
            )
            XCTAssertEqual(
                state.worldWidth, region.worldWidth,
                "\(region.id): world width mismatch"
            )
            XCTAssertEqual(
                state.worldHeight, region.worldHeight,
                "\(region.id): world height mismatch"
            )
            XCTAssertEqual(
                state.roosts.count, region.roosts.count,
                "\(region.id): roost count mismatch"
            )
            XCTAssertEqual(
                state.falcons.count, region.falconCount,
                "\(region.id): falcon count mismatch"
            )
            XCTAssertEqual(
                state.hasRival, region.hasRival,
                "\(region.id): rival flag mismatch"
            )
            XCTAssertEqual(
                state.windSeedOffset, region.windSeedOffset,
                "\(region.id): wind seed offset mismatch"
            )
        }
    }

    /// Two GameStates built from the same region must hash identically.
    func testMakeGameStateIsDeterministic() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        for region in catalog.regions {
            let a = stateHash(region.makeGameState())
            let b = stateHash(region.makeGameState())
            XCTAssertEqual(a, b, "\(region.id): construction is not deterministic")
        }
    }

    // MARK: - Validation

    private func samplePalette() -> RegionPalette {
        .standard
    }

    func testValidationRejectsRegionWithoutRoostsOrFields() {
        let region = Region(
            id: "empty", name: "Empty",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 100, falconCount: 0, hasRival: false,
            windSeedOffset: 0, seed: 1,
            roosts: [], fields: [],
            palette: samplePalette()
        )
        let problems = RegionCatalog.validate(region)
        XCTAssertTrue(problems.contains { $0.contains("roost") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("field") }, "\(problems)")
    }

    func testValidationRejectsOutOfBoundsPlacement() {
        let region = Region(
            id: "oob", name: "OOB",
            worldWidth: 100, worldHeight: 100,
            birdCount: 10, falconCount: 0, hasRival: false,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 500, y: 50, radius: 10)],
            fields: [Region.FieldDef(x: 50, y: 500, radius: 10, richness: 5)],
            palette: samplePalette()
        )
        let problems = RegionCatalog.validate(region)
        XCTAssertEqual(
            problems.filter { $0.contains("out of bounds") }.count, 2,
            "expected roost and field out-of-bounds, got \(problems)"
        )
    }

    func testValidationRejectsNonPositiveSizes() {
        let region = Region(
            id: "bad", name: "Bad",
            worldWidth: 0, worldHeight: -1,
            birdCount: 0, falconCount: -1, hasRival: false,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 10, y: 10, radius: 0)],
            fields: [Region.FieldDef(x: 10, y: 10, radius: 0, richness: 0)],
            palette: samplePalette()
        )
        let problems = RegionCatalog.validate(region)
        XCTAssertTrue(problems.contains { $0.contains("worldWidth") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("worldHeight") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("birdCount") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("falconCount") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("roost[0] radius") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("field[0] radius") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("richness") }, "\(problems)")
    }

    func testValidationRejectsOutOfRangePaletteColor() {
        var palette = samplePalette()
        palette.birdInk = RGBAColor(r: 1.5, g: 0, b: 0)
        let region = Region(
            id: "palette", name: "Palette",
            worldWidth: 100, worldHeight: 100,
            birdCount: 10, falconCount: 0, hasRival: false,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 10, y: 10, radius: 5)],
            fields: [Region.FieldDef(x: 10, y: 10, radius: 5, richness: 5)],
            palette: palette
        )
        let problems = RegionCatalog.validate(region)
        XCTAssertTrue(
            problems.contains { $0.contains("palette") },
            "expected palette problem, got \(problems)"
        )
    }

    // MARK: - Round trip

    /// A region round-trips through JSON unchanged.
    func testRegionJSONRoundTrip() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        let original = try XCTUnwrap(catalog.region(id: "ridge"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Region.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
