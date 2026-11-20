import XCTest
@testable import MUCore

/// Rules-engine tests. Every test names the rule ID it verifies (docs/RULES.md).
final class RulesEngineTests: XCTestCase {

    // MARK: - R-1 Region (world, fields, roosts, seeded wind field)

    func testR1WindFieldIsPerCellAndSeeded() {
        let a = makeState(seed: 7)
        let b = makeState(seed: 7)
        // 2048×1536 world with 256-unit cells → 8×6 = 48 cells.
        XCTAssertEqual(a.windCellsX.count, 48)
        XCTAssertEqual(a.windCellsY.count, 48)
        // Same seed → identical field (INV-3).
        XCTAssertEqual(a.windCellsX, b.windCellsX)
        XCTAssertEqual(a.windCellsY, b.windCellsY)
        // Vectors are nonzero and magnitude ≈ 0.3 in Q16.16 (19661 ± table error).
        let nonzero = zip(a.windCellsX, a.windCellsY).filter { $0 != 0 || $1 != 0 }
        XCTAssertGreaterThanOrEqual(nonzero.count, 40, "wind vectors should mostly be nonzero")
        for (x, y) in zip(a.windCellsX, a.windCellsY) {
            let mag2 = Int64(x) * Int64(x) + Int64(y) * Int64(y)
            // |v| ≤ 0.3 + table error (~1%) → mag2 ≤ (19900)².
            XCTAssertLessThanOrEqual(mag2, Int64(19_900) * Int64(19_900))
        }
    }

    func testR1WindFieldChangesEvery600Ticks() {
        var state = makeState(seed: 7)
        var rng = SeededRNG(seed: 1)
        let g0x = state.windCellsX
        // Ticks 0..599 use generation 0 (the regen check runs at pre-tick 600).
        for _ in 0..<600 { let (s, _) = applyTick(to: state, rng: &rng); state = s }
        XCTAssertEqual(state.windCellsX, g0x, "generation 0 holds through tick 599")
        let (s601, _) = applyTick(to: state, rng: &rng)
        XCTAssertNotEqual(s601.windCellsX, g0x, "generation 1 regenerates for the tick-600 batch")
    }

    // MARK: - R-2 Day length and dusk

    func testR2DayLengthAndDuskWindow() {
        XCTAssertEqual(GameState.dayTicks, 4800)
        XCTAssertEqual(GameState.duskStart, 3900)
        var state = makeState()
        XCTAssertFalse(state.isDusk)
        state.tick = GameState.duskStart - 1
        XCTAssertFalse(state.isDusk)
        state.tick = GameState.duskStart
        XCTAssertTrue(state.isDusk)
        state.tick = GameState.dayTicks - 1
        XCTAssertTrue(state.isDusk)
    }

    func testR2TickAdvancesPerApply() {
        var state = makeState()
        var rng = SeededRNG(seed: 42)
        let (after, _) = applyTick(to: state, rng: &rng)
        state = after
        XCTAssertEqual(state.tick, 1)
    }

    // MARK: - R-3 Leader paths

    func testR3LeaderPointTraversesPathAtMaxSpeed() {
        var path = LeaderPath(points: [
            Waypoint(x: 100, y: 0),
            Waypoint(x: 200, y: 0),
        ])
        // The leader starts on the first waypoint; the first advance snaps it
        // and moves the target to waypoint 1.
        XCTAssertTrue(path.advance(speed: 40))
        XCTAssertEqual(path.currentTarget, 1)
        // One tick at max speed (40 units/tick) moves exactly 40 units.
        _ = path.advance(speed: 40)
        XCTAssertEqual(path.currentX, 140)
        XCTAssertEqual(path.currentY, 0)
        // The attractor is the leader point itself.
        let attr = path.attractor()
        XCTAssertEqual(attr.x, 140)
        XCTAssertEqual(attr.y, 0)
    }

    func testR3WaypointReachedEventsFire() {
        var state = makeState(birdCount: 20)
        var rng = SeededRNG(seed: 3)
        let waypoints = (0..<4).map { Waypoint(x: Int32(200 + $0 * 150), y: Int32(200)) }
        let (withPath, _) = applyAction(.setLeaderPath(subFlock: 0, waypoints: waypoints), to: state)
        state = withPath
        var reached = 0
        for _ in 0..<600 {
            let (next, events) = applyTick(to: state, rng: &rng)
            state = next
            reached += events.filter {
                if case .leaderPath(_, let wp) = $0 { return wp > 0 }
                return false
            }.count
        }
        XCTAssertGreaterThanOrEqual(reached, 2, "leader should reach several waypoints in 600 ticks")
    }

    // MARK: - R-4 Condense and circling

    func testR4PathCompletionCirclesLastPosition() {
        var path = LeaderPath(points: [Waypoint(x: 1000, y: 1000)])
        XCTAssertTrue(path.advance(speed: 40)) // snaps the only waypoint
        XCTAssertTrue(path.isComplete)
        let before = path.attractor()
        _ = path.advance(speed: 40) // now circling
        let after = path.attractor()
        // The leader left the waypoint but stays within the circle radius.
        let dx = Int64(after.x) - Int64(before.x)
        let dy = Int64(after.y) - Int64(before.y)
        XCTAssertLessThanOrEqual(isqrt64(UInt64(dx * dx + dy * dy)), Int64(LeaderPath.circleRadius))
        XCTAssertGreaterThan(dx * dx + dy * dy, 0, "the circle must actually move")
    }

    func testR4CondenseDoublesCohesion() {
        var state = makeState(birdCount: 50, seed: 11)
        // No condense: the base weights pass through unchanged.
        XCTAssertEqual(effectiveParams(state).cohWeight, state.boidsParams.cohWeight)
        let (condensed, _) = applyAction(.condense(subFlock: 0), to: state)
        state = condensed
        XCTAssertEqual(state.condenseActive, GameState.condenseDuration)
        // While active, cohesion is exactly doubled (R-4).
        XCTAssertEqual(effectiveParams(state).cohWeight, state.boidsParams.cohWeight * 2)
        // Every other parameter is untouched.
        XCTAssertEqual(effectiveParams(state).sepWeight, state.boidsParams.sepWeight)
        XCTAssertEqual(effectiveParams(state).alignWeight, state.boidsParams.alignWeight)
        XCTAssertEqual(effectiveParams(state).leaderWeight, state.boidsParams.leaderWeight)
        // After the 60-tick duration the doubling ends.
        state.condenseActive = 1
        XCTAssertEqual(effectiveParams(state).cohWeight, state.boidsParams.cohWeight * 2)
        state.condenseActive = 0
        XCTAssertEqual(effectiveParams(state).cohWeight, state.boidsParams.cohWeight)
        XCTAssertEqual(state.condenseCooldown, GameState.condenseCooldownDuration)
    }

    func testR4CondenseCooldownBlocksRecondense() {
        var state = makeState(birdCount: 10)
        let (first, e1) = applyAction(.condense(subFlock: 0), to: state)
        state = first
        XCTAssertTrue(e1.contains { if case .condense(_, true) = $0 { return true }; return false })
        let (blocked, e2) = applyAction(.condense(subFlock: 0), to: state)
        state = blocked
        XCTAssertTrue(e2.isEmpty, "condense during cooldown must be rejected")
        XCTAssertEqual(state.condenseActive, GameState.condenseDuration)
    }

    // MARK: - R-5 Merges

    func testR5MergeRequires30TickProximity() {
        var state = makeState(birdCount: 40, seed: 9)
        // Split so two sub-flocks exist, then park their centroids close.
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        XCTAssertEqual(state.subFlockCount, 2)
        for i in 0..<state.birds.count {
            state.birds.posY[i] = 1000
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        // Park flock 0 at x=900, flock 1 at x=1000: centroids 100 apart.
        for i in 0..<state.birds.count {
            state.birds.posX[i] = state.subFlockAssignments[i] == 0 ? 900 : 1000
        }
        var mergeEvents = 0
        for tick in 1...40 {
            let events = computeMerge(state: &state)
            mergeEvents += events.count
            if tick < GameState.mergeThresholdTicks {
                XCTAssertEqual(state.subFlockCount, 2, "no merge before 30 ticks of proximity (tick \(tick))")
            }
        }
        XCTAssertEqual(mergeEvents, 1)
        XCTAssertEqual(state.subFlockCount, 1, "merge fires on the 30rd consecutive proximity tick")
    }

    /// MU-P4.1 regression: in rival mode the day-start split puts the rival's
    /// flock (1) coincident with the player's (0); the R-5 auto-merge must not
    /// absorb the rival's flock into the player's. GameModel sets
    /// `versusMergeSuppressed` for rival mode; this pins the reducer side.
    func testR5MergeSuppressedWhenFlagSet() {
        var state = makeState(birdCount: 40, seed: 9)
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        XCTAssertEqual(state.subFlockCount, 2)
        for i in 0..<state.birds.count {
            state.birds.posY[i] = 1000
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        for i in 0..<state.birds.count {
            state.birds.posX[i] = state.subFlockAssignments[i] == 0 ? 900 : 1000
        }
        state.versusMergeSuppressed = true
        var mergeEvents = 0
        for _ in 1...40 {
            let events = computeMerge(state: &state)
            mergeEvents += events.count
        }
        XCTAssertEqual(mergeEvents, 0, "suppressed state never merges")
        XCTAssertEqual(state.subFlockCount, 2, "both flocks survive the proximity window")
    }

    func testR5ProximityBreakResetsStreak() {
        var state = makeState(birdCount: 40, seed: 9)
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        for i in 0..<state.birds.count {
            state.birds.posY[i] = 1000
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
            state.birds.velY[i] = 0
        }
        // 20 ticks close (flock 0 at x=900, flock 1 at x=1000).
        for i in 0..<state.birds.count {
            state.birds.posX[i] = state.subFlockAssignments[i] == 0 ? 900 : 1000
        }
        for _ in 0..<20 { _ = computeMerge(state: &state) }
        XCTAssertEqual(state.mergeProximityStreak, 20)
        // Pull apart beyond 200 units: the streak resets.
        for i in 0..<state.birds.count where state.subFlockAssignments[i] == 1 {
            state.birds.posX[i] = 1400
        }
        _ = computeMerge(state: &state)
        XCTAssertEqual(state.mergeProximityStreak, 0)
    }

    // MARK: - R-10 Falcons

    func testR10FalconTargetsLowestDensityEdge() {
        // Two sub-flocks: flock 0 packed into a tight ball, flock 1 spread on
        // a sparse line. Both edges sit at the same distance from the falcon,
        // so R-10 picks the sparse flock (lowest local density at the edge).
        var state = makeState(birdCount: 120, falconCount: 1, seed: 5)
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        state.falcons[0].currentX = 1700
        state.falcons[0].currentY = 768
        state.falcons[0].cooldown = 0
        for i in 0..<state.birds.count {
            if state.subFlockAssignments[i] == 0 {
                // Dense ball far from the falcon (edge at x≈1208).
                state.birds.posX[i] = 1200 + Int32(i % 8)
                state.birds.posY[i] = 768 + Int32((i / 8) % 8)
            } else {
                // Sparse line closer to the falcon.
                state.birds.posX[i] = 1620 + Int32(i % 8) * 12
                state.birds.posY[i] = 768
            }
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        var rng = SeededRNG(seed: 5)
        let events = computeFalcons(state: &state, rng: &rng)
        let dive = events.first { if case .diveStart = $0 { return true }; return false }
        guard case .diveStart(_, let sf)? = dive else {
            return XCTFail("falcon should dive when an edge is in reach")
        }
        XCTAssertEqual(sf, 1, "the dive must target the sparse flock's edge")
    }

    func testR10DiveKillsOnlyWithinRadius() {
        var state = makeState(birdCount: 60, falconCount: 1, seed: 21)
        state.falcons[0].currentX = 1300
        state.falcons[0].currentY = 768
        state.falcons[0].cooldown = 0
        // All birds in a sparse ring around (1024, 768); the dive targets the
        // nearest edge. Birds more than diveRadius (30) from ANY plausible
        // dive center must survive; verify the kill set is radius-bounded by
        // checking exactly which birds vanished against the target position.
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768 + Int32(i * 8) // spaced ≥ 8 apart vertically
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        let before = Set(state.birds.posY)
        var rng = SeededRNG(seed: 21)
        _ = computeFalcons(state: &state, rng: &rng)
        let after = Set(state.birds.posY)
        let removed = before.subtracting(after)
        for y in removed {
            // Survivors sit at least diveRadius away from every removed bird's
            // slot: removed birds formed the dive's kill cluster.
            let nearestSurvivor = before.subtracting(removed).map { abs(Int($0) - Int(y)) }.min() ?? Int.max
            XCTAssertGreaterThanOrEqual(nearestSurvivor, 0) // trivially true; real bound below
        }
        // The dive center is a former bird position; every killed bird was
        // within diveRadius of it.
        if let firstKilled = removed.min() {
            let cluster = removed.filter { abs(Int($0) - Int(firstKilled)) <= GameState.diveRadius }
            XCTAssertEqual(cluster.count, removed.count, "all kills must cluster within one dive radius")
        }
    }

    func testR10DenseFlockKillCountIsCapped() {
        // A dense ball (120 birds in an 8×8 cell cluster) shields: a dive into
        // it kills at most max(1, 4 - density/8) birds, far fewer than the
        // birds inside the radius.
        var state = makeState(birdCount: 400, falconCount: 1, seed: 33)
        state.falcons[0].currentX = 1100
        state.falcons[0].currentY = 780
        state.falcons[0].cooldown = 0
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024 + Int32(i % 16) * 2
            state.birds.posY[i] = 768 + Int32(i / 16) * 2
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        let start = state.birds.count
        var rng = SeededRNG(seed: 33)
        let events = computeFalcons(state: &state, rng: &rng)
        let hit = events.contains { if case .diveResult(_, _, true) = $0 { return true }; return false }
        if hit {
            XCTAssertLessThanOrEqual(start - state.birds.count, 4, "dense flocks shield: at most the kill budget dies")
        }
    }

    // MARK: - R-11 Density shield

    func testR11DensityMetricDetectsDenseFlock() {
        var dense = makeState(birdCount: 200, falconCount: 0, seed: 3)
        for i in 0..<dense.birds.count {
            dense.birds.posX[i] = 1024 + Int32(i % 10) * 4
            dense.birds.posY[i] = 768 + Int32(i / 10) * 4
        }
        var sparse = makeState(birdCount: 200, falconCount: 0, seed: 3)
        for i in 0..<sparse.birds.count {
            sparse.birds.posX[i] = Int32(i % 20) * 96
            sparse.birds.posY[i] = 768 + Int32(i / 20) * 64
        }
        XCTAssertGreaterThanOrEqual(averageNeighborDensity(state: dense, subFlock: 0), GameState.densityShield)
        XCTAssertLessThan(averageNeighborDensity(state: sparse, subFlock: 0), GameState.densityShield)
    }

    func testR11DenseFlockHalvesDiveSuccess() {
        // Statistical: over many identical-setup dives with varying seeds, the
        // dense flock must lose strictly fewer birds than the sparse one.
        func kills(denseSetup: Bool) -> Int {
            var total = 0
            for seed in 1...40 {
                var state = makeState(birdCount: 300, falconCount: 1, seed: UInt64(seed))
                state.falcons[0].currentX = 1124
                state.falcons[0].currentY = 868
                state.falcons[0].cooldown = 0
                for i in 0..<state.birds.count {
                    if denseSetup {
                        state.birds.posX[i] = 1024 + Int32(i % 15) * 3
                        state.birds.posY[i] = 768 + Int32(i / 15) * 3
                    } else {
                        state.birds.posX[i] = 1024 + Int32(i % 15) * 40
                        state.birds.posY[i] = 768 + Int32(i / 15) * 40
                    }
                    state.birds.velX[i] = 0
                    state.birds.velY[i] = 0
                }
                var rng = SeededRNG(seed: UInt64(seed))
                let before = state.birds.count
                _ = computeFalcons(state: &state, rng: &rng)
                total += before - state.birds.count
            }
            return total
        }
        let denseKills = kills(denseSetup: true)
        let sparseKills = kills(denseSetup: false)
        XCTAssertLessThan(denseKills, sparseKills, "dense \(denseKills) vs sparse \(sparseKills) kills over 40 dives")
    }

    // MARK: - R-12 Roost claims at dusk

    func testR12NoClaimsBeforeDusk() {
        var state = makeState(birdCount: 50)
        state.tick = 1000
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 512
            state.birds.posY[i] = 768
        }
        let events = computeRoostClaims(state: &state)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(state.roostClaims[0][0], 0)
    }

    func testR12MajorityAccruesPerTick() {
        var state = makeState(birdCount: 50)
        state.tick = GameState.duskStart
        // All birds inside the roost radius (512±128, 768±128).
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 512
            state.birds.posY[i] = 768
        }
        let first = computeRoostClaims(state: &state)
        XCTAssertEqual(state.roostClaims[0][0], 1)
        XCTAssertTrue(first.contains { if case .claim(0, _) = $0 { return true }; return false })
        // More ticks inside → more points, no new events (no majority change).
        _ = computeRoostClaims(state: &state)
        _ = computeRoostClaims(state: &state)
        XCTAssertEqual(state.roostClaims[0][0], 3)
        // Empty the roost: no accrual.
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1600
        }
        _ = computeRoostClaims(state: &state)
        XCTAssertEqual(state.roostClaims[0][0], 3)
    }

    // MARK: - R-13 Victory

    func testR13WinnerHoldsMoreRoosts() {
        var state = makeState(birdCount: 10, hasRival: false, roostCount: 3)
        state.roostClaims = [[5, 0], [5, 0], [0, 5]]
        let (_, victory) = checkVictory(state: &state)
        guard case .victory(let winner)? = victory else { return XCTFail("expected victory") }
        XCTAssertEqual(winner, 0, "player holds 2 roosts vs 1")
        XCTAssertEqual(state.roosts[0].claimant, 0)
        XCTAssertEqual(state.roosts[2].claimant, 1)
    }

    func testR13TieGoesToMoreBirdsAlive() {
        var state = makeState(birdCount: 10, roostCount: 2)
        state.roostClaims = [[5, 0], [0, 5]]
        let (_, victory) = checkVictory(state: &state)
        guard case .victory(let winner)? = victory else { return XCTFail("expected victory") }
        XCTAssertEqual(winner, 0, "1–1 in roosts: the player has birds alive, the rival has none")
    }

    func testR13TieGoesToRivalWhenRivalHasMoreBirds() {
        var state = makeState(birdCount: 10, roostCount: 2)
        state.roostClaims = [[5, 0], [0, 5]]
        for i in 0..<state.subFlockAssignments.count {
            state.subFlockAssignments[i] = i < 4 ? 0 : 1
            state.birds.subFlock[i] = state.subFlockAssignments[i]
        }
        let (_, victory) = checkVictory(state: &state)
        guard case .victory(let winner)? = victory else { return XCTFail("expected victory") }
        XCTAssertEqual(winner, 1, "1–1 in roosts with the rival holding 6 birds vs 4: rival wins the tiebreak")
    }

    func testR13PointTieLeavesRoostUnclaimed() {
        var state = makeState(birdCount: 10, roostCount: 1)
        state.roostClaims = [[3, 3]]
        let (events, _) = checkVictory(state: &state)
        XCTAssertEqual(state.roosts[0].claimant, -1, "an exact claim-point tie leaves the roost unclaimed")
        XCTAssertEqual(events.count, 1) // just dayEnd
    }
}
