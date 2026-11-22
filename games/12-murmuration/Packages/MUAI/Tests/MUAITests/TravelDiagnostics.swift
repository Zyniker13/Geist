import XCTest
import MUCore
import MUContent
@testable import MUAI

/// Temporary diagnostic: replicate the balance day-1 setup and measure flock travel.
final class TravelDiagnostics: XCTestCase {
    private func centroid(_ state: GameState) -> (Int, Int) {
        var sx = 0.0, sy = 0.0, n = 0
        for i in 0..<state.birds.posX.count where state.subFlockAssignments[i] == 0 {
            sx += Double(state.birds.posX[i])
            sy += Double(state.birds.posY[i])
            n += 1
        }
        let ax = sx / Double(max(n, 1))
        let ay = sy / Double(max(n, 1))
        return (Int(ax), Int(ay))
    }

    func testFlockTravelsToFieldWithNoAI() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { dir = dir.deletingLastPathComponent() }
        let catalog = try RegionCatalog.load(from: dir.appendingPathComponent("Resources/Content/regions"))
        let region = catalog.region(id: "commons")!
        var state = region.makeGameState()
        state.energy[0] = 8_000
        let field = region.fields[0]
        _ = applyAction(.setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: Int32(field.x), y: Int32(field.y))]), to: state)
        var rng = SeededRNG(seed: region.seed)
        let fx = Int(field.x)
        let fy = Int(field.y)
        for step in 0...24 {
            if step > 0 { (state, _) = applyTick(to: state, rng: &rng) }
            if step % 4 == 0 {
                let pos = centroid(state)
                let cx = pos.0
                let cy = pos.1
                let dx = cx - fx
                let dy = cy - fy
                let dd = dx * dx + dy * dy
                let dist = Int((Double(dd)).squareRoot())
                print("TRAVEL t=\(state.tick) c=(\(cx),\(cy)) dist=\(dist) p=\(state.birds.posX.count)")
            }
        }
    }
}
