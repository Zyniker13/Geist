import XCTest
@testable import MUCore

/// Reducer integration and engine-level invariants (determinism, count events).
final class ReducerIntegrationTests: XCTestCase {
    // MARK: - Reducer integration

    func testReducerDeterministic() {
        let a = makeState(birdCount: 50, seed: 42)
        let b = makeState(birdCount: 50, seed: 42)
        XCTAssertEqual(a, b, "makeState must be deterministic")
        var rngA = SeededRNG(seed: 42)
        var rngB = SeededRNG(seed: 42)
        var stateA = a
        var stateB = b
        for _ in 0..<100 {
            let (a2, _) = applyTick(to: stateA, rng: &rngA)
            let (b2, _) = applyTick(to: stateB, rng: &rngB)
            stateA = a2
            stateB = b2
        }
        XCTAssertEqual(stateA.birds.posX, stateB.birds.posX)
        XCTAssertEqual(stateA.birds.posY, stateB.birds.posY)
        XCTAssertEqual(stateA, stateB)
    }

    func testApplyPauseResume() {
        let state = makeState(birdCount: 50)
        let (_, pauseEvents) = applyAction(.pause, to: state)
        XCTAssertTrue(pauseEvents.isEmpty, "pause produces no events (tracked externally)")
        let (_, resumeEvents) = applyAction(.resume, to: state)
        XCTAssertTrue(resumeEvents.isEmpty, "resume produces no events")
    }

    func testApplySplitFlock() {
        let state = makeState(birdCount: 100)
        let (after, events) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        XCTAssertEqual(after.subFlockCount, 2)
        XCTAssertEqual(after.energy.count, 2, "the new sub-flock gets its own energy")
        XCTAssertTrue(events.contains { if case .split(0, 1) = $0 { return true }; return false })
        let flock0 = after.subFlockAssignments.filter { $0 == 0 }.count
        let flock1 = after.subFlockAssignments.filter { $0 == 1 }.count
        XCTAssertEqual(flock0 + flock1, 100)
        XCTAssertGreaterThan(flock1, 0)
        XCTAssertLessThan(flock1, 100)
    }

    /// INV-1 property test: bird count changes only through growth, falcons,
    /// and starvation events — never silently.
    func testINV1BirdCountChangesOnlyViaCountEvents() {
        var state = makeState(birdCount: 300, falconCount: 2, seed: 77)
        var rng = SeededRNG(seed: 77)
        for _ in 0..<600 {
            let before = state.birds.count
            let (next, events) = applyTick(to: state, rng: &rng)
            state = next
            let after = state.birds.count
            if after != before {
                let accounted = events.contains { event in
                    switch event {
                    case .energy(.grow), .energy(.starve):
                        return true
                    case .falcon(.diveResult(_, _, true)):
                        return true
                    default:
                        return false
                    }
                }
                XCTAssertTrue(accounted, "count changed \(before)→\(after) without a count event: \(events)")
            }
        }
    }

    /// INV-2 substitution: no obstacle geometry exists before P2/P3, so the
    /// tick-end bound check is the world rectangle (birds never leave it).
    func testINV2BirdsStayInWorldBounds() {
        var state = makeState(birdCount: 200, seed: 13)
        var rng = SeededRNG(seed: 13)
        for _ in 0..<400 {
            let (next, _) = applyTick(to: state, rng: &rng)
            state = next
            for i in 0..<state.birds.count {
                XCTAssertGreaterThanOrEqual(state.birds.posX[i], 0)
                XCTAssertLessThan(state.birds.posX[i], state.worldWidth)
                XCTAssertGreaterThanOrEqual(state.birds.posY[i], 0)
                XCTAssertLessThan(state.birds.posY[i], state.worldHeight)
            }
        }
    }

    // MARK: - BirdSoA

    func testBirdSoARemove() {
        var birds = BirdSoA(capacity: 5)
        for i in 0..<5 {
            birds.append(x: Int32(i * 100), y: Int32(i * 100), velXQ: 0, velYQ: 0, subFlock: 0)
        }
        XCTAssertEqual(birds.count, 5)
        birds.remove(at: 2)
        XCTAssertEqual(birds.count, 4)
        XCTAssertEqual(birds.posX[2], 300) // was index 3
        XCTAssertEqual(birds.posX[3], 400) // was index 4
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
    }
}
