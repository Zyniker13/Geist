import XCTest
import MUCore
import MUContent
@testable import MUAI

/// Temporary diagnostic: why do the day-start clouds merge within 60 ticks
/// under the P4 leader brake? Logs per-tick centroid separation and both
/// pilots' leader points. Enable with MU_MERGE_DIAG=1.
final class MergeDiagnostics: XCTestCase {
    private func centroid(_ state: GameState, sub: UInt8) -> (Double, Double, Int) {
        var sx = 0.0, sy = 0.0, n = 0
        for i in 0..<state.birds.posX.count where state.subFlockAssignments[i] == sub {
            sx += Double(state.birds.posX[i])
            sy += Double(state.birds.posY[i])
            n += 1
        }
        return (sx / Double(max(n, 1)), sy / Double(max(n, 1)), n)
    }

    private func makeTestRegion(birdCount: Int = 1400) -> Region {
        Region(
            id: "test", name: "Test",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: birdCount, falconCount: 1, hasRival: true,
            rivalStartBirds: birdCount * 3 / 7,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
    }

    private func apply(_ actions: [GameAction], to state: GameState) -> GameState {
        var state = state
        for action in actions {
            let (next, _) = applyAction(action, to: state)
            state = next
        }
        return state
    }

    private func step(
        _ state: GameState,
        rng: inout SeededRNG,
        autoplayer: inout Autoplayer,
        rival: inout GentleRival
    ) -> (GameState, [GameEvent]) {
        var state = state
        var events: [GameEvent] = []
        if let action = autoplayer.action(for: state) {
            let (next, evts) = applyAction(action, to: state)
            state = next
            events.append(contentsOf: evts)
        }
        if let action = rival.action(for: state) {
            let (next, evts) = applyAction(action, to: state)
            state = next
            events.append(contentsOf: evts)
        }
        let (next, evts) = applyTick(to: state, rng: &rng)
        return (next, events + evts)
    }

    func testMergeDiagnostic() throws {
        guard ProcessInfo.processInfo.environment["MU_MERGE_DIAG"] != nil else {
            throw XCTSkip("set MU_MERGE_DIAG=1")
        }
        let region = makeTestRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        var rng = SeededRNG(seed: region.seed)
        var ai = Autoplayer()
        var rival = GentleRival()

        var belowStreak = 0
        for t in 0..<60 {
            let (next, events) = step(state, rng: &rng, autoplayer: &ai, rival: &rival)
            state = next
            for event in events {
                if case .merge = event { print("MERGE EVENT at tick \(t)") }
            }
            let a = centroid(state, sub: 0)
            let b = centroid(state, sub: 1)
            let dx = a.0 - b.0, dy = a.1 - b.1
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < 200 { belowStreak += 1 } else { belowStreak = 0 }
            print(String(format: "t=%02d sub0=(%.0f,%.0f,n=%d) sub1=(%.0f,%.0f,n=%d) dist=%.0f below=%d", t, a.0, a.1, a.2, b.0, b.1, b.2, dist, belowStreak))
        }
    }
}
