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

    func testCatalogLoadsSixRegions() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        XCTAssertEqual(catalog.regions.count, 6, "expected six shipped regions")
        XCTAssertEqual(
            Set(catalog.ids),
            ["meadow", "ridge", "delta", "fenlands", "gorge", "commons"],
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
        XCTAssertNotNil(catalog.region(id: "fenlands"))
        XCTAssertNotNil(catalog.region(id: "gorge"))
        XCTAssertNotNil(catalog.region(id: "commons"))
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

    // MARK: - P3 world features (MU-P3.1)

    /// A region authored before P3 (no `obstacles`, `windPattern`, or
    /// `falconBehavior` keys) decodes with the engine defaults: no
    /// obstacles, uniform wind, patrol falcons.
    func testLegacyRegionJSONDecodesWithDefaults() throws {
        let legacyJSON = """
            {
              "id": "legacy",
              "name": "Legacy",
              "worldWidth": 1024,
              "worldHeight": 1024,
              "birdCount": 100,
              "falconCount": 1,
              "hasRival": false,
              "rivalStartBirds": 0,
              "windSeedOffset": 0,
              "seed": 1,
              "roosts": [
                { "x": 512, "y": 512, "radius": 64 }
              ],
              "fields": [
                { "x": 512, "y": 512, "radius": 64, "richness": 50 }
              ],
              "palette": {
                "skyTop": { "r": 0.2, "g": 0.2, "b": 0.3, "a": 1.0 },
                "skyHigh": { "r": 0.4, "g": 0.4, "b": 0.5, "a": 1.0 },
                "skyLow": { "r": 0.8, "g": 0.6, "b": 0.5, "a": 1.0 },
                "skyBottom": { "r": 0.95, "g": 0.8, "b": 0.6, "a": 1.0 },
                "hillFar": { "r": 0.3, "g": 0.3, "b": 0.3, "a": 1.0 },
                "hillMid": { "r": 0.2, "g": 0.2, "b": 0.2, "a": 1.0 },
                "hillNear": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1.0 },
                "birdInk": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1.0 },
                "birdHighlight": { "r": 0.25, "g": 0.35, "b": 0.4, "a": 1.0 },
                "rival": { "r": 0.35, "g": 0.25, "b": 0.15, "a": 1.0 },
                "fieldOchre": { "r": 0.8, "g": 0.65, "b": 0.35, "a": 1.0 },
                "fieldGreen": { "r": 0.5, "g": 0.6, "b": 0.4, "a": 1.0 },
                "falcon": { "r": 0.13, "g": 0.1, "b": 0.08, "a": 1.0 }
              }
            }
            """
        let region = try JSONDecoder().decode(
            Region.self, from: legacyJSON.data(using: .utf8)!
        )
        XCTAssertEqual(region.obstacles.count, 0, "legacy regions have no obstacles")
        XCTAssertEqual(region.windPattern, .uniform, "legacy wind pattern")
        XCTAssertEqual(region.falconBehavior, .patrol, "legacy falcon behavior")
    }

    /// A region round-trips through JSON with obstacles, wind pattern, and
    /// falcon behavior intact.
    func testRegionJSONRoundTripsWorldFeatures() throws {
        let region = Region(
            id: "featureful", name: "Featureful",
            worldWidth: 1024, worldHeight: 1024,
            birdCount: 100, falconCount: 1, hasRival: false,
            windSeedOffset: 7, seed: 7,
            roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
            fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
            palette: samplePalette(),
            obstacles: [
                Region.ObstacleDef(x: 512, y: 512, radius: 96),
                Region.ObstacleDef(x: 200, y: 800, radius: 64),
            ],
            windPattern: .shear,
            falconBehavior: .lurk
        )
        let data = try JSONEncoder().encode(region)
        let decoded = try JSONDecoder().decode(Region.self, from: data)
        XCTAssertEqual(decoded, region)
    }

    /// An unknown wind pattern or falcon behavior string fails to load.
    func testUnknownFeatureStringFailsToDecode() {
        for (key, bad) in [("windPattern", "mystery"), ("falconBehavior", "stoop")] {
            let json = """
                {"id":"x","name":"X","worldWidth":100,"worldHeight":100,
                "birdCount":10,"falconCount":1,"hasRival":false,
                "windSeedOffset":0,"seed":1,
                "roosts":[{"x":10,"y":10,"radius":5}],
                "fields":[{"x":90,"y":90,"radius":5,"richness":5}],
                "palette":{},"\(key)":"\(bad)"}
                """
            let data = Data(json.utf8)
            XCTAssertThrowsError(
                try JSONDecoder().decode(Region.self, from: data),
                "\(key): expected decode failure for \(bad)"
            )
        }
    }

    /// makeGameState() carries the region's world features into the sim.
    func testMakeGameStateCarriesWorldFeatures() {
        let region = Region(
            id: "featureful", name: "Featureful",
            worldWidth: 1024, worldHeight: 1024,
            birdCount: 100, falconCount: 1, hasRival: false,
            windSeedOffset: 7, seed: 7,
            roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
            fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
            palette: samplePalette(),
            obstacles: [
                Region.ObstacleDef(x: 512, y: 512, radius: 96),
                Region.ObstacleDef(x: 200, y: 800, radius: 64),
            ],
            windPattern: .shear,
            falconBehavior: .lurk
        )
        let state = region.makeGameState()
        XCTAssertEqual(state.windPattern, .shear)
        XCTAssertEqual(state.falconBehavior, .lurk)
        XCTAssertEqual(state.obstacleCount, 2)
        XCTAssertEqual(state.obstacleCenterX, [Int32(512), Int32(200)])
        XCTAssertEqual(state.obstacleCenterY, [Int32(512), Int32(800)])
        XCTAssertEqual(state.obstacleRadius, [Int32(96), Int32(64)])
    }

    /// Every shipped region carries at least one obstacle; across the
    /// catalog both falcon behaviors and all three wind patterns are in use
    /// (G3 counts: 6 regions, 2 falcon behaviors).
    func testShippedRegionsUseWorldFeatures() throws {
        let catalog = try RegionCatalog.load(from: regionsDir)
        for region in catalog.regions {
            XCTAssertGreaterThanOrEqual(
                region.obstacles.count, 1,
                "\(region.id): expected at least one obstacle"
            )
        }
        let behaviors = Set(catalog.regions.map(\.falconBehavior))
        XCTAssertEqual(behaviors, [.patrol, .lurk], "expected both falcon behaviors in use")
        let patterns = Set(catalog.regions.map(\.windPattern))
        XCTAssertEqual(patterns, [.uniform, .shear, .gusts], "expected all wind patterns in use")
    }

    /// Validation rejects degenerate obstacles: non-positive radius or a
    /// center outside the world.
    func testValidationRejectsBadObstacle() {
        let base = Region(
            id: "obst", name: "Obst",
            worldWidth: 1000, worldHeight: 1000,
            birdCount: 100, falconCount: 1, hasRival: false,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
            fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
            palette: samplePalette()
        )
        let zeroRadius = base.copy(obstacles: [Region.ObstacleDef(x: 500, y: 500, radius: 0)])
        XCTAssertTrue(
            RegionCatalog.validate(zeroRadius).contains { $0.contains("obstacle[0] radius") },
            "expected obstacle radius problem"
        )
        let outOfBounds = base.copy(obstacles: [Region.ObstacleDef(x: 1500, y: 500, radius: 64)])
        XCTAssertTrue(
            RegionCatalog.validate(outOfBounds).contains { $0.contains("obstacle[0]") && $0.contains("out of bounds") },
            "expected obstacle out-of-bounds problem"
        )
    }

    // MARK: - Solo objectives (MU-P3.2, R-13)

    /// A solo region (no rival, positive target) passes validation.
    func testValidationAcceptsSoloRegion() {
        let region = Region(
            id: "solo", name: "Solo",
            worldWidth: 1000, worldHeight: 1000,
            birdCount: 400, falconCount: 1, hasRival: false,
            soloTargetBirds: 250,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
            fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
            palette: samplePalette()
        )
        XCTAssertEqual(
            RegionCatalog.validate(region), [],
            "a well-formed solo region must validate clean"
        )
    }

    /// Validation rejects a negative target, a target above the flock size,
    /// and any nonzero target in a rival region.
    func testValidationRejectsBadSoloTarget() {
        func region(target: Int, rival: Bool) -> Region {
            Region(
                id: "solo", name: "Solo",
                worldWidth: 1000, worldHeight: 1000,
                birdCount: 400, falconCount: 1, hasRival: rival,
                rivalStartBirds: rival ? 150 : 0,
                soloTargetBirds: target,
                windSeedOffset: 0, seed: 1,
                roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
                fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
                palette: samplePalette()
            )
        }
        let negative = RegionCatalog.validate(region(target: -1, rival: false))
        XCTAssertTrue(
            negative.contains { $0.contains("soloTargetBirds must be >= 0") },
            "expected negative-target problem, got \(negative)"
        )
        let tooBig = RegionCatalog.validate(region(target: 401, rival: false))
        XCTAssertTrue(
            tooBig.contains { $0.contains("soloTargetBirds must be <= birdCount") },
            "expected over-flock problem, got \(tooBig)"
        )
        let withRival = RegionCatalog.validate(region(target: 1, rival: true))
        XCTAssertTrue(
            withRival.contains { $0.contains("soloTargetBirds must be 0 in a rival region") },
            "expected rival-region problem, got \(withRival)"
        )
    }

    /// `makeGameState` carries the region's target into the simulation
    /// (INV-3: content JSON → Region → GameState, deterministic ints).
    func testMakeGameStateCarriesSoloTarget() throws {
        let solo = Region(
            id: "solo", name: "Solo",
            worldWidth: 1000, worldHeight: 1000,
            birdCount: 400, falconCount: 1, hasRival: false,
            soloTargetBirds: 250,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 200, y: 200, radius: 80)],
            fields: [Region.FieldDef(x: 800, y: 800, radius: 80, richness: 5)],
            palette: samplePalette()
        )
        XCTAssertEqual(
            solo.makeGameState().soloTargetBirds, 250,
            "solo target must reach the GameState"
        )
        // Shipped regions are all versus regions, so they must carry 0.
        let catalog = try RegionCatalog.load(from: regionsDir)
        for region in catalog.regions {
            XCTAssertEqual(
                region.makeGameState().soloTargetBirds, 0,
                "\(region.id): versus region must have no solo target"
            )
        }
    }

    /// A region JSON authored before P3.2 (no `soloTargetBirds` key) decodes
    /// with target 0, so the six shipped versus regions stay valid.
    func testSoloTargetDefaultsToZeroWhenKeyMissing() throws {
        let json = """
            {"id":"x","name":"X","worldWidth":100,"worldHeight":100,
            "birdCount":10,"falconCount":1,"hasRival":false,
            "windSeedOffset":0,"seed":1,
            "roosts":[{"x":10,"y":10,"radius":5}],
            "fields":[{"x":90,"y":90,"radius":5,"richness":5}],
            "palette":{"skyTop":{"r":0.2,"g":0.2,"b":0.3,"a":1.0},
            "skyHigh":{"r":0.4,"g":0.4,"b":0.5,"a":1.0},
            "skyLow":{"r":0.8,"g":0.6,"b":0.5,"a":1.0},
            "skyBottom":{"r":0.95,"g":0.8,"b":0.6,"a":1.0},
            "hillFar":{"r":0.3,"g":0.3,"b":0.3,"a":1.0},
            "hillMid":{"r":0.2,"g":0.2,"b":0.2,"a":1.0},
            "hillNear":{"r":0.1,"g":0.1,"b":0.1,"a":1.0},
            "birdInk":{"r":0.1,"g":0.1,"b":0.1,"a":1.0},
            "birdHighlight":{"r":0.25,"g":0.35,"b":0.4,"a":1.0},
            "rival":{"r":0.35,"g":0.25,"b":0.15,"a":1.0},
            "fieldOchre":{"r":0.8,"g":0.65,"b":0.35,"a":1.0},
            "fieldGreen":{"r":0.5,"g":0.6,"b":0.4,"a":1.0},
            "falcon":{"r":0.13,"g":0.1,"b":0.08,"a":1.0}}}
            """
        let region = try JSONDecoder().decode(Region.self, from: Data(json.utf8))
        XCTAssertEqual(region.soloTargetBirds, 0, "missing key decodes to 0")
        XCTAssertEqual(
            RegionCatalog.validate(region), [],
            "a legacy region without the key must validate clean"
        )
    }
}
