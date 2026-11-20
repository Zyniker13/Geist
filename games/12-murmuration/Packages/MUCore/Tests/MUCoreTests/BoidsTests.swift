import XCTest
@testable import MUCore

final class BoidsTests: XCTestCase {
    /// Spawn a flock of birds in a small world with a seeded distribution.
    private func makeFlock(
        count: Int, seed: UInt64, width: Int32 = 2048, height: Int32 = 1536
    ) -> (birds: BirdSoA, hash: SpatialHash, width: Int32, height: Int32) {
        var rng = SeededRNG(seed: seed)
        var birds = BirdSoA(capacity: count)
        for _ in 0..<count {
            let angle = Double(rng.next(upperBound: 6283)) / 1000.0
            let speed = 28.0
            let vx = Int32((cos(angle) * speed) * 65536.0)
            let vy = Int32((sin(angle) * speed) * 65536.0)
            birds.append(
                x: Int32(rng.next(upperBound: Int(width))),
                y: Int32(rng.next(upperBound: Int(height))),
                velXQ: vx,
                velYQ: vy,
                subFlock: 0
            )
        }
        let hash = SpatialHash(width: width, height: height, cellSize: 96)
        return (birds, hash, width, height)
    }

    /// Frame helper with common defaults (leader at world center, no wind).
    private func frame(
        leaderX: Int32 = 1024, leaderY: Int32 = 768,
        windX: Int32 = 0, windY: Int32 = 0,
        width: Int32, height: Int32
    ) -> BoidsFrame {
        BoidsFrame(
            leaderX: leaderX, leaderY: leaderY, windXQ: windX, windYQ: windY,
            worldWidth: width, worldHeight: height
        )
    }

    // INV-3: identical seeds and inputs produce identical trajectories.
    func testINV3StepIsDeterministic() {
        let a = makeFlock(count: 400, seed: 11)
        let b = makeFlock(count: 400, seed: 11)
        var birdsA = a.birds
        var birdsB = b.birds
        var hashA = a.hash
        var hashB = b.hash
        let params = BoidsParams()
        for _ in 0..<300 {
            hashA.rebuild(posX: birdsA.posX, posY: birdsA.posY, count: birdsA.count)
            hashB.rebuild(posX: birdsB.posX, posY: birdsB.posY, count: birdsB.count)
            stepBirds(
                birds: &birdsA, hash: &hashA,
                frame: frame(windX: 327_680, width: a.width, height: a.height),
                params: params
            )
            stepBirds(
                birds: &birdsB, hash: &hashB,
                frame: frame(windX: 327_680, width: b.width, height: b.height),
                params: params
            )
        }
        XCTAssertEqual(birdsA.posX, birdsB.posX)
        XCTAssertEqual(birdsA.posY, birdsB.posY)
        XCTAssertEqual(birdsA.velX, birdsB.velX)
        XCTAssertEqual(birdsA.velY, birdsB.velY)
    }

    // R-7: every bird stays inside [minSpeed, maxSpeed]; below-minimum is
    // allowed only under a decelerating force (ADR-0004).
    func testR7SpeedsStayClamped() {
        let flock = makeFlock(count: 300, seed: 5)
        var birds = flock.birds
        var hash = flock.hash
        let params = BoidsParams()
        let min2 = Int64(params.minSpeed) * Int64(params.minSpeed)
        let max2 = Int64(params.maxSpeed) * Int64(params.maxSpeed)
        for _ in 0..<500 {
            let prevVelX = birds.velX
            let prevVelY = birds.velY
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash,
                frame: frame(windX: 655_360, windY: 655_360, width: flock.width, height: flock.height),
                params: params
            )
            for i in 0..<birds.count {
                let vx = Int64(birds.velX[i])
                let vy = Int64(birds.velY[i])
                let v2 = vx * vx + vy * vy
                XCTAssertLessThanOrEqual(v2, max2 + 2, "speed exceeded maximum at bird \(i)")
                if v2 < min2 - 2 {
                    // Below the cruise floor is allowed only when this tick's
                    // net force decelerated the bird (a turning bird may dip
                    // below minSpeed so its direction can reverse).
                    let dvx = vx - Int64(prevVelX[i])
                    let dvy = vy - Int64(prevVelY[i])
                    let dot = dvx * vx + dvy * vy
                    XCTAssertTrue(v2 == 0 || dot < 0, "speed fell below minimum without a decelerating force at bird \(i): v2=\(v2) dot=\(dot)")
                }
            }
        }
    }

    /// Regression test: Swift binds `<<`/`>>` tighter than `*`//`, so an
    /// unparenthesized `unit << 16 * weight >> 16` applies `weight >> 16`
    /// (whole units only: 1.2 became 1.0, 0.8 and 0.6 became 0). A bird
    /// cruising at 30 units/tick outside the brake radius must gain exactly
    /// leaderWeight 1.2 units/tick; inside the radius the P4 brake instead
    /// removes exactly 0.5 of the bird's velocity per tick.
    func testR6LeaderForceMatchesWeight() {
        let width: Int32 = 2048, height: Int32 = 1536
        var birds = BirdSoA(capacity: 2)
        birds.append(x: 600, y: 768, velXQ: 1_966_080, velYQ: 0, subFlock: 0) // 900 from leader: no brake
        birds.append(x: 1000, y: 768, velXQ: 1_966_080, velYQ: 0, subFlock: 0) // 500 from leader: braked
        var hash = SpatialHash(width: width, height: height, cellSize: 96)
        hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
        stepBirds(
            birds: &birds, hash: &hash,
            frame: frame(leaderX: 1500, width: width, height: height),
            params: BoidsParams()
        )
        // 30 units + leaderWeight 1.2 (78_643 Q16.16), still inside [18, 40].
        XCTAssertEqual(birds.velX[0], 1_966_080 + 78_643)
        // Braked: −0.5 × 30 (983_040 Q16.16) then + leaderWeight 1.2.
        XCTAssertEqual(birds.velX[1], 1_061_683)
    }

    // Regression (P4 diagnostics): the leader force was a constant-magnitude
    // pull with no braking, so a parked flock swung past the leader point and
    // back forever — the centroid pendulummed ±800 units and the flock could
    // never hold a roost or a standoff. Inside `leaderBrakeRadius` the leader
    // now also damps velocity, so the flock converges onto the point and holds.
    func testFlockConvergesToStationaryLeader() {
        let flock = makeFlock(count: 250, seed: 19)
        var birds = flock.birds
        var hash = flock.hash
        var worst = Int64(0)
        for tick in 0..<600 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash,
                frame: frame(width: flock.width, height: flock.height),
                params: BoidsParams()
            )
            if tick >= 400 {
                worst = max(worst, centroidDistance(of: birds))
            }
        }
        XCTAssertLessThan(
            worst, 80,
            "parked flock never settled on the leader: worst offset \(worst)"
        )
    }

    // INV-2: no bird may leave the world bounds.
    func testINV2BirdsStayInWorld() {
        let flock = makeFlock(count: 200, seed: 77)
        var birds = flock.birds
        var hash = flock.hash
        let params = BoidsParams()
        for _ in 0..<600 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash,
                frame: frame(leaderX: 0, leaderY: 0, width: flock.width, height: flock.height),
                params: params
            )
            for i in 0..<birds.count {
                XCTAssertTrue(birds.posX[i] >= 0 && birds.posX[i] < flock.width, "x out of bounds: \(birds.posX[i])")
                XCTAssertTrue(birds.posY[i] >= 0 && birds.posY[i] < flock.height, "y out of bounds: \(birds.posY[i])")
            }
        }
    }

    /// Centroid distance to the default leader point (1024, 768).
    private func centroidDistance(of birds: BirdSoA) -> Int64 {
        var sumX: Int64 = 0
        var sumY: Int64 = 0
        for i in 0..<birds.count {
            sumX += Int64(birds.posX[i])
            sumY += Int64(birds.posY[i])
        }
        let cx = sumX / Int64(birds.count)
        let cy = sumY / Int64(birds.count)
        let dx = cx - 1024
        let dy = cy - 768
        return isqrt64(UInt64(dx * dx + dy * dy))
    }

    /// Leader attraction must have a causal pulling effect: with identical seed,
    /// spawn, and ticks, the run with `leaderWeight` active ends with its
    /// centroid closer to the leader point than the leaderless control run.
    ///
    /// A static leader can never park the flock on the leader point: with
    /// `minSpeed` 18 units/tick birds cannot stop, so they orbit it (see
    /// docs/OPEN_QUESTIONS.md). Gameplay steers with moving leader paths
    /// (R-3/R-4), so the invariant we assert is the causal pull, not parking.
    /// Exact distances shift with balance tuning; the ordering is the point.
    func testR6LeaderAttractsFlock() {
        let flock = makeFlock(count: 250, seed: 19)
        var withLeader = flock.birds
        var withHash = flock.hash
        var withoutLeader = flock.birds
        var withoutHash = flock.hash
        var paramsOff = BoidsParams()
        paramsOff.leaderWeight = 0
        let paramsOn = BoidsParams()
        for _ in 0..<400 {
            withHash.rebuild(posX: withLeader.posX, posY: withLeader.posY, count: withLeader.count)
            stepBirds(
                birds: &withLeader, hash: &withHash,
                frame: frame(width: flock.width, height: flock.height),
                params: paramsOn
            )
            withoutHash.rebuild(posX: withoutLeader.posX, posY: withoutLeader.posY, count: withoutLeader.count)
            stepBirds(
                birds: &withoutLeader, hash: &withoutHash,
                frame: frame(width: flock.width, height: flock.height),
                params: paramsOff
            )
        }
        let dOn = centroidDistance(of: withLeader)
        let dOff = centroidDistance(of: withoutLeader)
        XCTAssertLessThan(dOn, dOff, "leader attraction did not pull the flock closer than the leaderless control: \(dOn) vs \(dOff)")
    }

    /// Wind must have a causal steering effect: with identical seed, spawn,
    /// leader point, and ticks, the run with wind active ends up displaced
    /// downwind (along (1,1)) relative to the windless control. The probe is
    /// taken mid-travel toward an upwind leader point: the P4 leader brake
    /// holds a parked flock at its leader point (where wind's residual effect
    /// is only a few units), so the parked case cannot distinguish wind from
    /// cluster-shape variance.
    func testR1WindDriftsFlockDownwind() {
        let flock = makeFlock(count: 250, seed: 19)
        var withWind = flock.birds
        var withHash = flock.hash
        var withoutWind = flock.birds
        var withoutHash = flock.hash
        func downwind(_ birds: BirdSoA) -> Int64 {
            var sumX: Int64 = 0
            var sumY: Int64 = 0
            for i in 0..<birds.count {
                sumX += Int64(birds.posX[i])
                sumY += Int64(birds.posY[i])
            }
            let cx = sumX / Int64(birds.count) - 1024
            let cy = sumY / Int64(birds.count) - 768
            // Projection of the centroid offset onto the downwind unit (1,1)/√2,
            // scaled by √2 to stay in integers: (dx + dy) grows downwind.
            return cx + cy
        }
        for _ in 0..<120 {
            withHash.rebuild(posX: withWind.posX, posY: withWind.posY, count: withWind.count)
            stepBirds(
                birds: &withWind, hash: &withHash,
                frame: frame(
                    leaderX: 400, leaderY: 400,
                    windX: 655_360, windY: 655_360,
                    width: flock.width, height: flock.height
                ),
                params: BoidsParams()
            )
            withoutHash.rebuild(posX: withoutWind.posX, posY: withoutWind.posY, count: withoutWind.count)
            stepBirds(
                birds: &withoutWind, hash: &withoutHash,
                frame: frame(leaderX: 400, leaderY: 400, width: flock.width, height: flock.height),
                params: BoidsParams()
            )
        }
        let driftOn = downwind(withWind)
        let driftOff = downwind(withoutWind)
        XCTAssertGreaterThan(
            driftOn - driftOff, 100,
            "wind did not displace the traveling flock downwind: \(driftOn) vs \(driftOff)"
        )
    }

    // Regression: an ultra-dense flock (thousands of neighbors inside the
    // alignment radius) pushes the alignment sum past 2^31. Squaring that
    // sum inside normalizedScaled used to overflow Int64 and trap the
    // process mid-tick (SIGTRAP in Release, "Fatal error" in Debug) once a
    // real day's worth of ticks let the flock collapse into a dense cluster.
    // R-6: forces must compute for any flock shape; INV-3: deterministically.
    func testR6UltraDenseFlockAlignmentSumDoesNotOverflow() {
        let n = 2700
        var birds = BirdSoA(capacity: n)
        for _ in 0..<n {
            birds.append(x: 1024, y: 768, velXQ: 2_621_440, velYQ: 0, subFlock: 0)
        }
        var hash = SpatialHash(width: 2048, height: 1536, cellSize: 96)
        hash.rebuild(posX: birds.posX, posY: birds.posY, count: n)
        stepBirds(
            birds: &birds, hash: &hash,
            frame: frame(width: 2048, height: 1536),
            params: BoidsParams()
        )
        // All birds are co-located and aligned +x: separation and cohesion
        // contribute zero (zero displacement), alignment is +x at full
        // weight. The spawn point is also the default leader point, so the
        // P4 leader brake damps speed below maxSpeed — the guarded invariant
        // is that the alignment sum never overflows and every bird keeps
        // heading +x within its clamped speed range.
        for i in 0..<n {
            XCTAssertGreaterThan(birds.velX[i], 0)
            XCTAssertLessThanOrEqual(birds.velX[i], 2_621_440)
            XCTAssertEqual(birds.velY[i], 0)
        }
    }
}
