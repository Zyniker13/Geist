import XCTest
@testable import MUMeta
import MUContent

/// MU-P5.2: each daily modifier maps to a region transform. The mapping
/// lives in MUMeta (Region+Daily.swift) because MUContent must not know
/// about meta concepts; the knobs themselves are engine/region fields.
final class DailyModifierMappingTests: XCTestCase {
    private static func region(
        birds: Int = 1000, falcons: Int = 1, richness: Int = 10,
        roostRadius: Int = 128, roostCount: Int = 2
    ) -> Region {
        Region(
            id: "meadow", name: "meadow",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: birds, falconCount: falcons,
            hasRival: false, rivalStartBirds: 0,
            soloTargetBirds: 0,
            windSeedOffset: 0, seed: 1,
            roosts: (0..<roostCount).map {
                Region.RoostDef(x: Int32(400 + $0 * 300), y: 768, radius: roostRadius)
            },
            fields: [
                Region.FieldDef(x: 1024, y: 768, radius: 200, richness: richness),
                Region.FieldDef(x: 300, y: 300, radius: 150, richness: richness),
            ],
            palette: RegionPalette.standard,
            obstacles: [], windPattern: .uniform, falconBehavior: .patrol
        )
    }

    func testStrongWindsScaleWindMagnitude() {
        let base = Self.region().makeGameState()
        let strong = Self.region().applying(dailyModifier: .strongWinds).makeGameState()
        XCTAssertEqual(strong.windStrengthQ16, 131_072)
        XCTAssertEqual(base.windStrengthQ16, 65_536)
        // The 2.0x magnitude reaches the field itself (2x ± 1 LSB of floor).
        for cell in 0..<base.windCellsX.count {
            XCTAssertEqual(strong.windCellsX[cell], base.windCellsX[cell] * 2, accuracy: 1)
            XCTAssertEqual(strong.windCellsY[cell], base.windCellsY[cell] * 2, accuracy: 1)
        }
    }

    func testExtraFalconsAddsOne() {
        let modified = Self.region(falcons: 1).applying(dailyModifier: .extraFalcons)
        XCTAssertEqual(modified.falconCount, 2)
    }

    func testScarceFieldsHalveRichness() {
        let modified = Self.region(richness: 10).applying(dailyModifier: .scarceFields)
        XCTAssertEqual(modified.fields.map(\.richness), [5, 5])
    }

    func testScarceFieldsRichnessFloorIsOne() {
        let modified = Self.region(richness: 1).applying(dailyModifier: .scarceFields)
        XCTAssertEqual(modified.fields.map(\.richness), [1, 1])
    }

    func testFogHalvesWindRegenCadence() {
        let modified = Self.region().applying(dailyModifier: .fog)
        XCTAssertEqual(modified.windRegenTicksOverride, 300)
        XCTAssertEqual(modified.makeGameState().effectiveWindRegenTicks, 300)
    }

    func testDoubleRoostsAddsAHalfRadiusTwinPerRoost() {
        let modified = Self.region(roostRadius: 128, roostCount: 2)
            .applying(dailyModifier: .doubleRoosts)
        XCTAssertEqual(modified.roosts.count, 4)
        XCTAssertEqual(modified.roosts[1].x, modified.roosts[0].x)
        XCTAssertEqual(modified.roosts[1].y, modified.roosts[0].y)
        XCTAssertEqual(modified.roosts[1].radius, 64)
        XCTAssertEqual(modified.roosts[3].radius, 64)
    }

    func testDoubleRoostsRadiusFloorIs32() {
        let modified = Self.region(roostRadius: 40, roostCount: 1)
            .applying(dailyModifier: .doubleRoosts)
        XCTAssertEqual(modified.roosts[1].radius, 32)
    }

    func testTinyFlockHalvesBirdCount() {
        let modified = Self.region(birds: 1000).applying(dailyModifier: .tinyFlock)
        XCTAssertEqual(modified.birdCount, 500)
    }

    func testTinyFlockFloorIs200() {
        let modified = Self.region(birds: 300).applying(dailyModifier: .tinyFlock)
        XCTAssertEqual(modified.birdCount, 200)
    }

    func testBaseRegionIsUnchangedByEveryModifierApplication() {
        // The mapping builds copies; the source region must never mutate.
        let source = Self.region()
        let original = source
        for modifier in DailyModifier.allCases {
            _ = source.applying(dailyModifier: modifier)
        }
        XCTAssertEqual(source, original)
    }
}
