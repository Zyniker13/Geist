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

    func testStepIsDeterministic() {
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
                birds: &birdsA, hash: &hashA, leaderX: 1024, leaderY: 768,
                windXQ: 327_680, windYQ: 0, params: params,
                worldWidth: a.width, worldHeight: a.height
            )
            stepBirds(
                birds: &birdsB, hash: &hashB, leaderX: 1024, leaderY: 768,
                windXQ: 327_680, windYQ: 0, params: params,
                worldWidth: b.width, worldHeight: b.height
            )
        }
        XCTAssertEqual(birdsA.posX, birdsB.posX)
        XCTAssertEqual(birdsA.posY, birdsB.posY)
        XCTAssertEqual(birdsA.velX, birdsB.velX)
        XCTAssertEqual(birdsA.velY, birdsB.velY)
    }

    func testSpeedsStayClamped() {
        let flock = makeFlock(count: 300, seed: 5)
        var birds = flock.birds
        var hash = flock.hash
        let params = BoidsParams()
        for _ in 0..<500 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash, leaderX: 1024, leaderY: 768,
                windXQ: 655_360, windYQ: 655_360, params: params,
                worldWidth: flock.width, worldHeight: flock.height
            )
            for i in 0..<birds.count {
                let v2 = Int64(birds.velX[i]) * Int64(birds.velX[i]) + Int64(birds.velY[i]) * Int64(birds.velY[i])
                XCTAssertGreaterThanOrEqual(v2, Int64(params.minSpeed) * Int64(params.minSpeed) - 2, "speed fell below minimum at bird \(i)")
                XCTAssertLessThanOrEqual(v2, Int64(params.maxSpeed) * Int64(params.maxSpeed) + 2, "speed exceeded maximum at bird \(i)")
            }
        }
    }

    func testBirdsStayInWorld() {
        let flock = makeFlock(count: 200, seed: 77)
        var birds = flock.birds
        var hash = flock.hash
        let params = BoidsParams()
        for _ in 0..<600 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash, leaderX: 0, leaderY: 0,
                windXQ: 0, windYQ: 0, params: params,
                worldWidth: flock.width, worldHeight: flock.height
            )
            for i in 0..<birds.count {
                XCTAssertTrue(birds.posX[i] >= 0 && birds.posX[i] < flock.width, "x out of bounds: \(birds.posX[i])")
                XCTAssertTrue(birds.posY[i] >= 0 && birds.posY[i] < flock.height, "y out of bounds: \(birds.posY[i])")
            }
        }
    }

    func testFlockCohesionRisingWithLeaderAttraction() {
        // With no wind and a fixed leader, the flock's centroid should move toward
        // the leader point over the run (leader attraction is the dominant steering).
        let flock = makeFlock(count: 250, seed: 19)
        var birds = flock.birds
        var hash = flock.hash
        let params = BoidsParams()
        func centroidDistance() -> Int64 {
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
        let start = centroidDistance()
        for _ in 0..<400 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(
                birds: &birds, hash: &hash, leaderX: 1024, leaderY: 768,
                windXQ: 0, windYQ: 0, params: params,
                worldWidth: flock.width, worldHeight: flock.height
            )
        }
        let end = centroidDistance()
        XCTAssertLessThan(end, start / 2, "centroid did not approach the leader: \(start) -> \(end)")
    }
}
