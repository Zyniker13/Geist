import XCTest
@testable import MUCore

/// Energy rule tests (R-8, R-9): drain, feeding, growth, starvation.
final class EnergyRuleTests: XCTestCase {
    func testEnergyDrain() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [800]

        let drainEvents = computeEnergyDrain(state: &state)

        // With 100 birds, drain = 100 * 1 / 100 = 1
        XCTAssertEqual(drainEvents.count, 1)
        XCTAssertEqual(state.energy[0], 799)
    }

    func testEnergyDrainZeroBirds() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 0,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [800]

        let drainEvents = computeEnergyDrain(state: &state)

        // With 0 birds, drain = 0
        XCTAssertEqual(drainEvents.count, 0)
        XCTAssertEqual(state.energy[0], 800)
    }

    func testEnergyFeeding() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [50],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [100]

        // Place all birds inside the field
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768
        }

        var rng = SeededRNG(seed: 1)
        let feedEvents = computeFeeding(state: &state, rng: &rng)

        // Birds should feed from the field
        XCTAssertGreaterThan(feedEvents.count, 0)
        XCTAssertTrue(state.energy[0] > 100)
    }

    func testEnergyGrowth() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // Set energy above growth threshold
        state.energy = [800] // 800 > 600 threshold, excess = 200

        var rng = SeededRNG(seed: 1)
        let growthEvents = computeGrowth(state: &state, rng: &rng)

        // Should trigger growth
        XCTAssertGreaterThan(growthEvents.count, 0)
        if case .grow(_, let newBirds) = growthEvents[0] {
            _ = newBirds // Growth produced new birds
        } else {
            XCTFail("Expected .grow event")
        }
    }

    func testEnergyStarvation() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [0]

        var rng = SeededRNG(seed: 1)
        let starveEvents = computeStarvation(state: &state, rng: &rng)

        // Should kill some birds
        XCTAssertGreaterThan(starveEvents.count, 0)
        XCTAssertLessThan(state.birds.count, 100)
    }

    func testEnergyNoStarvationWhenPositive() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [10]

        var rng = SeededRNG(seed: 1)
        let starveEvents = computeStarvation(state: &state, rng: &rng)

        // No starvation when energy > 0
        XCTAssertEqual(starveEvents.count, 0)
        XCTAssertEqual(state.birds.count, 100)
    }
}
