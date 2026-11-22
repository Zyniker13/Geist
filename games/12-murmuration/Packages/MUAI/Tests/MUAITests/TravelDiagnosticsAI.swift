import XCTest
import MUCore
import MUContent
@testable import MUAI

/// Temporary diagnostic: replicate the balance day-1 setup with AI on, log actions.
final class TravelDiagnosticsAI: XCTestCase {
    private func centroid(_ state: GameState) -> (Int, Int) {
        var sx = 0.0, sy = 0.0, n = 0
        for i in 0..<state.birds.posX.count where state.subFlockAssignments[i] == 0 {
            sx += Double(state.birds.posX[i])
            sy += Double(state.birds.posY[i])
            n += 1
        }
        return (Int(sx / Double(max(n, 1))), Int(sy / Double(max(n, 1))))
    }

    func testFlockTravelsWithAIOn() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { dir = dir.deletingLastPathComponent() }
        let catalog = try RegionCatalog.load(from: dir.appendingPathComponent("Resources/Content/regions"))
        let region = catalog.region(id: "commons")!
        if ProcessInfo.processInfo.environment["MU_AI"] != nil {
            try runAIProbe(region: region)
        } else if ProcessInfo.processInfo.environment["MU_SMALL"] != nil {
            try runSmallFlockProbe(region: region)
        } else {
            try runParkProbe(region: region)
        }
    }

    /// Density probe: a small flock (no falcon, no rival) walks a long
    /// straight leader path — measures the centroid's sustainable speed
    /// versus the birds' 40/tick max, isolating leader-following from
    /// crowd churn.
    private func runSmallFlockProbe(region: Region) throws {
        var state = region.makeGameState()
        state.falcons = []
        // Keep sub-flock 0 only, trimmed to 200 birds.
        var kept = 0
        var assignments: [UInt8] = []
        var xs: [Int32] = []
        var ys: [Int32] = []
        var vx: [Int32] = []
        var vy: [Int32] = []
        for i in 0..<state.birds.posX.count where kept < 200 {
            kept += 1
            assignments.append(state.subFlockAssignments[i])
            xs.append(state.birds.posX[i])
            ys.append(state.birds.posY[i])
            vx.append(state.birds.velX[i])
            vy.append(state.birds.velY[i])
        }
        state.subFlockAssignments = assignments
        var birds = BirdSoA(capacity: kept)
        for j in 0..<kept {
            birds.append(x: xs[j], y: ys[j], velXQ: vx[j], velYQ: vy[j], subFlock: 0)
        }
        state.birds = birds
        state = applyAction(
            .setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: 1800, y: 1200)]),
            to: state).0
        var rng = SeededRNG(seed: region.seed)
        var last = centroid(state)
        for _ in 0..<400 {
            (state, _) = applyTick(to: state, rng: &rng)
            if state.tick % 50 == 0 {
                let pos = centroid(state)
                let lead = state.leaderPaths.first
                let dx = pos.0 - last.0
                let dy = pos.1 - last.1
                let speed = (Double(dx * dx + dy * dy).squareRoot()) / 50
                print("SMALL t=\(state.tick) c=(\(pos.0),\(pos.1)) lead=(\(lead?.currentX ?? -1),\(lead?.currentY ?? -1)) speed=\(String(format: "%.1f", speed))")
                last = pos
            }
        }
    }

    /// AI on: full day loop with the autoplayer, logging actions and state.
    private func runAIProbe(region: Region) throws {
        var state = region.makeGameState()
        var autoplayer = Autoplayer()
        state = applyAction(.setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: 1500, y: 300), Waypoint(x: 300, y: 300)]), to: state).0
        var rng = SeededRNG(seed: region.seed)
        for _ in 0..<4800 {
            if state.tick >= 4000 { break }
            if let action = autoplayer.action(for: state) {
                state = applyAction(action, to: state).0
                if case .setLeaderPath(let sf, let wps) = action, sf == 0 {
                    let w = wps.first ?? Waypoint(x: -1, y: -1)
                    let kind = state.fields.contains(where: {
                        $0.centerX == w.x && $0.centerY == w.y
                    }) ? "forage" : "standoff"
                    var food = ""
                    for f in state.fields { food += "f:\(f.maxDepletion - f.currentDepletion) " }
                    print("ACTION t=\(state.tick) \(kind) (\(w.x),\(w.y)) \(food)")
                }
            }
            (state, _) = applyTick(to: state, rng: &rng)
            if state.tick % 100 == 0 {
                let pos = centroid(state)
                var n = 0
                for i in 0..<state.birds.posX.count where state.subFlockAssignments[i] == 0 { n += 1 }
                print("TICK t=\(state.tick) n=\(n) bank=\(state.energy.first ?? -1) c=(\(pos.0),\(pos.1))")
            }
        }
    }

    /// AI off: park the flock in the northwest corner and report how
    /// tight the milling ball stays with condense refreshed every 60
    /// ticks — separates standoff dynamics from forage dynamics.
    private func runParkProbe(region: Region) throws {
        var probe = region.makeGameState()
        probe = applyAction(.setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: 100, y: 100)]), to: probe).0
        var rng = SeededRNG(seed: region.seed)
        var condenseClock = 0
        for _ in 0..<3000 {
            if probe.tick >= 2400 { break }
            condenseClock += 1
            if condenseClock >= 60 {
                probe = applyAction(.condense(subFlock: 0), to: probe).0
                condenseClock = 0
            }
            (probe, _) = applyTick(to: probe, rng: &rng)
            if probe.tick % 100 == 0 {
                let pos = centroid(probe)
                var radii: [Double] = []
                for i in 0..<probe.birds.posX.count {
                    let dx = Double(probe.birds.posX[i]) - Double(pos.0)
                    let dy = Double(probe.birds.posY[i]) - Double(pos.1)
                    radii.append((dx * dx + dy * dy).squareRoot())
                }
                radii.sort()
                let p90 = radii[Int(Double(radii.count - 1) * 0.9)]
                let maxR = radii[radii.count - 1]
                var fx = -1, fy = -1
                if !probe.falcons.isEmpty {
                    fx = Int(probe.falcons[0].currentX)
                    fy = Int(probe.falcons[0].currentY)
                }
                let lead = probe.leaderPaths.first
                let frame = BoidsFrame(
                    leaderX: 0, leaderY: 0,
                    windXQ: 0, windYQ: 0,
                    worldWidth: probe.worldWidth, worldHeight: probe.worldHeight,
                    leadersX: [], leadersY: [],
                    windCellsX: probe.windCellsX, windCellsY: probe.windCellsY,
                    windGridCols: Int32(max(1, Int(probe.worldWidth) / GameState.windCellSize)),
                    windGridRows: Int32(max(1, Int(probe.worldHeight) / GameState.windCellSize)),
                    windCellSize: Int32(GameState.windCellSize))
                let w = frame.wind(at: Int32(pos.0), Int32(pos.1))
                print(
                    "PARK t=\(probe.tick) n=\(radii.count) c=(\(pos.0),\(pos.1))"
                    + " p90=\(Int(p90)) max=\(Int(maxR))"
                    + " falcon=(\(fx),\(fy))"
                    + " lead=(\(lead?.currentX ?? -1),\(lead?.currentY ?? -1))"
                    + " wind=(\(w.x >> 16),\(w.y >> 16))")
            }
        }
    }
}
