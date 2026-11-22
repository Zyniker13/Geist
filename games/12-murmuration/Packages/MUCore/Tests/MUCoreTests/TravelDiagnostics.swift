import XCTest
@testable import MUCore

/// Temporary diagnostic: how fast does a flock close on a leader waypoint?
final class TravelDiagnostics: XCTestCase {
    func testFlockClosesOnLeaderWaypoint() {
        var state = GameState(
            birdCount: 500,
            worldWidth: 2048, worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [65], fieldRadius: [120],
            fieldCenterX: [1700], fieldCenterY: [1200],
            roostCount: 1, roostCenterX: [1024], roostCenterY: [400], roostRadius: [120],
            falconCount: 0, hasRival: false, soloTargetBirds: 0,
            windSeedOffset: 0,
            seed: 7
        )
        state.energy[0] = 5_000
        for i in 0..<state.birds.count {
            state.birds.posX[i] = Int32(200 + (i % 22) * 2)
            state.birds.posY[i] = Int32(200 + (i / 22) * 2)
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
            state.subFlockAssignments[i] = 0
        }
        _ = applyAction(.setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: 1000, y: 1000)]), to: state)
        var rng = SeededRNG(seed: 7)
        for step in 0...8 {
            if step > 0 { (state, _) = applyTick(to: state, rng: &rng) }
            var sx = 0.0, sy = 0.0
            for i in 0..<state.birds.count { sx += Double(state.birds.posX[i]); sy += Double(state.birds.posY[i]) }
            let cx = Int(sx / Double(state.birds.count)), cy = Int(sy / Double(state.birds.count))
            let d = ((cx - 1000) * (cx - 1000) + (cy - 1000) * (cy - 1000))
            print("TRAVEL t=\(state.tick) c=(\(cx),\(cy)) dist=\(Int(Double(d).squareRoot())) L=(\(state.leaderPaths[0].currentX),\(state.leaderPaths[0].currentY))")
        }
    }
}
