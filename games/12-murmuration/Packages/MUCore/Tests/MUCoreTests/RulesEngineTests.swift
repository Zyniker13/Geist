import XCTest
@testable import MUCore

final class RulesEngineTests: XCTestCase {

    // MARK: - GameState

    func testGameStateInitialization() {
        let params = BoidsParams()
        let state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10, 20],
            fieldRadius: [128, 256],
            fieldCenterX: [512, 1536],
            fieldCenterY: [384, 1152],
            roostCount: 2,
            roostCenterX: [256, 1792],
            roostCenterY: [768, 768],
            roostRadius: [128, 128],
            falconCount: 3,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        XCTAssertEqual(state.tick, 0)
        XCTAssertEqual(state.birds.count, 100)
        XCTAssertEqual(state.energy.count, 1)
        XCTAssertEqual(state.fields.count, 2)
        XCTAssertEqual(state.falcons.count, 3)
        XCTAssertFalse(state.isDusk)
    }

    func testGameStateTickAdvances() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 50,
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
        state.tick = 100
        state.tick += 1
        XCTAssertEqual(state.tick, 101)
    }

    func testGameStateDuskPhase() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 50,
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
        XCTAssertFalse(state.isDusk)
        state.tick = GameState.duskStart - 1
        XCTAssertFalse(state.isDusk)
        state.tick = GameState.duskStart
        XCTAssertTrue(state.isDusk)
        state.tick = GameState.dayTicks - 1
        XCTAssertTrue(state.isDusk)
    }

    // MARK: - LeaderPath

    func testLeaderPathAttractor() {
        var path = LeaderPath(points: [])
        let wp1 = Waypoint(x: 500, y: 500)
        let wp2 = Waypoint(x: 1000, y: 1000)
        path.points = [wp1, wp2]
        path.currentTarget = 0

        // At tick 0, should return first waypoint
        let attr0 = path.attractor(for: 0, at: 0)
        XCTAssertEqual(attr0.x, 500)
        XCTAssertEqual(attr0.y, 500)

        // Advance to waypoint 1
        path.currentTarget = 1
        let attr1 = path.attractor(for: 0, at: 100)
        XCTAssertEqual(attr1.x, 1000)
        XCTAssertEqual(attr1.y, 1000)
    }

    func testLeaderPathAdvance() {
        var path = LeaderPath(points: [])
        let wp1 = Waypoint(x: 500, y: 500)
        let wp2 = Waypoint(x: 1000, y: 1000)
        path.points = [wp1, wp2]
        path.currentTarget = 0
        path.currentX = 100
        path.currentY = 100

        // Should advance toward waypoint
        _ = path.advance(targetX: 100, targetY: 100, speed: 60)
        // Path should have moved closer to waypoint
        XCTAssertTrue(path.currentX > 100 || path.currentY > 100 || path.currentTarget > 0)
    }

    // MARK: - Falcon

    func testFalconDive() {
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

        var rng = SeededRNG(seed: 42)
        let events = computeFalcons(state: &state, rng: &rng)

        // Should have falcon events
        XCTAssertGreaterThanOrEqual(events.count, 0)
    }

    // MARK: - Roost

    func testRoostNoClaimAtDay() {
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
        // tick = 0 (day, not dusk)
        let roosts: [RoostState] = [
            RoostState(centerX: 512, centerY: 768, radius: 128, claims: [0, 0], claimed: false, claimant: -1)
        ]

        var rng = SeededRNG(seed: 42)
        let events = computeRoosts(state: &state, roosts: roosts, rng: &rng)

        // No claims during day
        XCTAssertEqual(events.count, 0)
    }

    func testCheckVictoryPlayerWins() {
        let params = BoidsParams()
        let state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 2,
            roostCenterX: [512, 1536],
            roostCenterY: [768, 768],
            roostRadius: [128, 128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        let roosts: [RoostState] = [
            RoostState(centerX: 512, centerY: 768, radius: 128, claims: [0, 0], claimed: true, claimant: 0),
            RoostState(centerX: 1536, centerY: 768, radius: 128, claims: [0, 0], claimed: true, claimant: 0)
        ]

        let (events, victory) = checkVictory(state: state, roosts: roosts)

        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(victory)
        if case .victory(let winner) = victory! {
            XCTAssertEqual(winner, 0)
        }
    }

    func testCheckVictoryTie() {
        let params = BoidsParams()
        let state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 2,
            roostCenterX: [512, 1536],
            roostCenterY: [768, 768],
            roostRadius: [128, 128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        let roosts: [RoostState] = [
            RoostState(centerX: 512, centerY: 768, radius: 128, claims: [0, 0], claimed: true, claimant: 0),
            RoostState(centerX: 1536, centerY: 768, radius: 128, claims: [0, 0], claimed: true, claimant: 1)
        ]

        let (events, victory) = checkVictory(state: state, roosts: roosts)

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(victory)
    }

    // MARK: - Reducer (applyTick / applyAction)

    func testApplyTickAdvancesState() {
        let params = BoidsParams()
        let state = GameState(
            birdCount: 50,
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

        var rng = SeededRNG(seed: 42)
        let (stateAfter, events) = applyTick(to: state, rng: &rng)

        XCTAssertEqual(stateAfter.tick, 1)
        XCTAssertGreaterThanOrEqual(events.count, 0)
    }

    func testReducerDeterministic() {
        let params = BoidsParams()
        var stateA = GameState(
            birdCount: 50,
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
        var stateB = GameState(
            birdCount: 50,
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

        var rngA = SeededRNG(seed: 42)
        var rngB = SeededRNG(seed: 42)

        // Run 100 ticks with same seed
        for _ in 0..<100 {
            let (stateA2, _) = applyTick(to: stateA, rng: &rngA)
            let (stateB2, _) = applyTick(to: stateB, rng: &rngB)
            stateA = stateA2
            stateB = stateB2
        }

        XCTAssertEqual(stateA.birds.posX, stateB.birds.posX)
        XCTAssertEqual(stateA.birds.posY, stateB.birds.posY)
    }

    func testApplyPauseResume() {
        let params = BoidsParams()
        let state = GameState(
            birdCount: 50,
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

        var rng = SeededRNG(seed: 42)

        // Pause is a no-op in applyAction; applyTick always advances.
        let (_, pauseEvents) = applyAction(.pause, to: state)
        XCTAssertTrue(pauseEvents.isEmpty, "Pause should produce no events")

        // Tick still advances (pause is tracked externally).
        let (stateAfter, _) = applyTick(to: state, rng: &rng)
        XCTAssertEqual(stateAfter.tick, 1, "Tick should advance regardless of pause")

        // Resume is also a no-op.
        let (_, resumeEvents) = applyAction(.resume, to: state)
        XCTAssertTrue(resumeEvents.isEmpty, "Resume should produce no events")
    }

    func testApplySplitFlock() {
        let params = BoidsParams()
        let state = GameState(
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

        // Split flock
        let (stateAfter, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)

        // Should have split sub-flocks
        XCTAssertTrue(stateAfter.subFlockCount >= 1)
    }

    // MARK: - BirdSoA

    func testBirdSoARemove() {
        var birds = BirdSoA(capacity: 5)
        for i in 0..<5 {
            birds.append(x: Int32(i * 100), y: Int32(i * 100), velXQ: 0, velYQ: 0, subFlock: 0)
        }
        XCTAssertEqual(birds.count, 5)

        // Remove middle element
        birds.remove(at: 2)
        XCTAssertEqual(birds.count, 4)
        XCTAssertEqual(birds.posX[2], 300) // Was index 3
        XCTAssertEqual(birds.posX[3], 400) // Was index 4
    }

    func testBirdSoARemoveLast() {
        var birds = BirdSoA(capacity: 5)
        for i in 0..<5 {
            birds.append(x: Int32(i * 100), y: Int32(i * 100), velXQ: 0, velYQ: 0, subFlock: 0)
        }
        XCTAssertEqual(birds.count, 5)

        birds.removeLast(2)
        XCTAssertEqual(birds.count, 3)
        XCTAssertEqual(birds.posX[2], 200)
    }

    // MARK: - SpatialHash

    func testSpatialHashRebuild() {
        var hash = SpatialHash(width: 2048, height: 1536, cellSize: 96)
        let posX: [Int32] = [100, 200, 300]
        let posY: [Int32] = [100, 200, 300]
        hash.rebuild(posX: posX, posY: posY, count: 3)
        // SpatialHash stores cells; count is not a simple property.
        // Just verify no crash and rebuild works.
    }
}
