import XCTest
@testable import MUCore

/// MU-P5.2 daily-modifier engine knobs: the wind-strength multiplier and
/// the regeneration-cadence override on GameState.
final class DailyWindKnobTests: XCTestCase {
    func testDefaultStrengthReproducesLegacyFieldBitForBit() {
        // strengthQ16 65536 (1.0x) must leave every vector untouched.
        let legacy = GameState.windField(
            generation: 2, seed: 0xABCD, windSeedOffset: 17,
            worldWidth: 2048, worldHeight: 1536
        )
        let scaled = GameState.windField(
            generation: 2, seed: 0xABCD, windSeedOffset: 17,
            worldWidth: 2048, worldHeight: 1536,
            strengthQ16: 65_536
        )
        XCTAssertEqual(legacy.x, scaled.x)
        XCTAssertEqual(legacy.y, scaled.y)
    }

    func testStrongWindsDoubleEveryVector() {
        // 2.0x scales the magnitude, not the direction: each component
        // doubles exactly (the pattern is a pure integer multiply).
        let base = GameState.windField(
            generation: 0, seed: 9, windSeedOffset: 0,
            worldWidth: 2048, worldHeight: 1536
        )
        let strong = GameState.windField(
            generation: 0, seed: 9, windSeedOffset: 0,
            worldWidth: 2048, worldHeight: 1536,
            strengthQ16: 131_072
        )
        XCTAssertEqual(strong.x.count, base.x.count)
        for cell in 0..<base.x.count {
            // The field floors each product (>>16), so 2.0x lands within
            // one Q16.16 LSB of exactly double the 1.0x vector.
            XCTAssertEqual(strong.x[cell], base.x[cell] * 2, accuracy: 1)
            XCTAssertEqual(strong.y[cell], base.y[cell] * 2, accuracy: 1)
        }
    }

    func testStrongWindsUniformAndShearDoNotOverflowInt32() {
        // Regression (MU-P5.2): the uniform and shear branches multiplied
        // a Q16.16 unit component (up to 65536) by the scaled magnitude in
        // Int32 — fine at 1.0x (65536 * 19661 just fits) but an overflow
        // trap at 2.0x (65536 * 39322 does not). Every generation/cell
        // combination must now produce vectors without trapping.
        for generation in 0...3 {
            let strong = GameState.windField(
                generation: generation, seed: 11, windSeedOffset: 0,
                worldWidth: 2048, worldHeight: 1536,
                pattern: .uniform,
                strengthQ16: 131_072
            )
            let strongShear = GameState.windField(
                generation: generation, seed: 11, windSeedOffset: 0,
                worldWidth: 2048, worldHeight: 1536,
                pattern: .shear,
                strengthQ16: 131_072
            )
            XCTAssertEqual(strong.x.count, strongShear.x.count)
            let maxAbs = zip(strong.x, strong.y).map { max(abs(Int($0)), abs(Int($1))) }.max() ?? 0
            XCTAssertLessThanOrEqual(maxAbs, 39_322, "2x magnitude is 0.6 units/tick = 39322 Q16.16")
        }
    }

    func testEffectiveWindRegenTicksDefaultsTo600() {
        let state = makeGoldenWorld(birdCount: 50, seed: 3)
        XCTAssertEqual(state.windRegenTicksOverride, 0)
        XCTAssertEqual(state.effectiveWindRegenTicks, GameState.windRegenTicks)
    }

    func testFogHalvesRegenerationCadence() {
        // The reducer regenerates at the START of a tick whose number is a
        // multiple of the cadence; after N full applyTick calls the state
        // tick is N and the field still carries the last completed
        // rebuild. At the 300-tick cadence, state tick 600 holds the
        // generation-1 field (rebuilt at the start of tick 300; the
        // generation-2 rebuild belongs to the start of tick 600, one call
        // away). The 600-tick default would still hold generation 0.
        var state = makeGoldenWorld(birdCount: 50, seed: 5)
        state.windRegenTicksOverride = 300
        var rng = SeededRNG(seed: 5)
        for _ in 0..<600 {
            let (next, _) = applyTick(to: state, rng: &rng)
            state = next
        }
        XCTAssertEqual(state.tick, 600)
        let fogField = GameState.windField(
            generation: 1, seed: state.seed, windSeedOffset: state.windSeedOffset,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight,
            pattern: state.windPattern
        )
        XCTAssertEqual(state.windCellsX, fogField.x)
        XCTAssertEqual(state.windCellsY, fogField.y)
    }

    func testDefaultCadenceDoesNotRegenerateAtTick300() {
        // Guard for the fog test: without the override the tick-300 field
        // still carries generation 0, which differs from generation 1.
        var state = makeGoldenWorld(birdCount: 50, seed: 5)
        var rng = SeededRNG(seed: 5)
        for _ in 0..<300 {
            let (next, _) = applyTick(to: state, rng: &rng)
            state = next
        }
        let generation1 = GameState.windField(
            generation: 1, seed: state.seed, windSeedOffset: state.windSeedOffset,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight,
            pattern: state.windPattern
        )
        XCTAssertNotEqual(state.windCellsX, generation1.x)
    }

    func testStrongWindsChangeTheTrajectory() {
        // The knob must actually reach the sim: two identical days, one
        // at 2.0x wind, end at different hashes.
        var state = makeGoldenWorld(birdCount: 50, seed: 7)
        var rng = SeededRNG(seed: 7)
        for _ in 0..<1_200 {
            let (next, _) = applyTick(to: state, rng: &rng)
            state = next
        }
        var strong = makeGoldenWorld(birdCount: 50, seed: 7)
        strong.windStrengthQ16 = 131_072
        var strongRng = SeededRNG(seed: 7)
        for _ in 0..<1_200 {
            let (next, _) = applyTick(to: strong, rng: &strongRng)
            strong = next
        }
        XCTAssertNotEqual(stateHash(state), stateHash(strong))
    }
}
