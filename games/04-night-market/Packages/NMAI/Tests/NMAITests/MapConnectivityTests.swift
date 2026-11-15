import Foundation
import Testing
@testable import NMCore
@testable import NMAI

/// P5: every content map must be playable by the bot — after a full night,
/// the painted walkway network (plus bridges) must connect each open stall
/// to a gate, or the map's stall placement is at fault.
struct MapConnectivityTests {
    private func map(_ name: String) throws -> MapDefinition {
        // Maps live in the game's Resources/Content/maps; tests run from the
        // package directory, so walk up to the game root.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // NMAITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // NMAI
            .deletingLastPathComponent()  // Packages
            .appendingPathComponent("../Resources/Content/maps/\(name).json")
            .standardizedFileURL
        return try JSONDecoder().decode(MapDefinition.self, from: Data(contentsOf: url))
    }

    @Test("bot connects stalls on every content map", arguments: [
        "taipei", "bangkok", "marrakesh", "oaxaca", "seoul", "istanbul",
    ])
    func botConnectsStalls(mapName: String) throws {
        let def = try map(mapName)
        var state = try GameState.initial(seed: 42, map: def)
        var rng = SeededRNG(seed: 42)
        let planner = AutoPlanner()
        var illegal = 0
        var lastEvents: [Event] = []
        while !state.clock.isNightOver {
            if let action = planner.nextAction(for: state, events: lastEvents) {
                do {
                    state = try Reducer.apply(action, to: state, rng: &rng).0
                } catch {
                    illegal += 1
                    Issue.record("\(mapName): illegal action \(action)")
                    break
                }
            }
            let (next, events) = Tick.advance(state: state, rng: &rng)
            state = next
            lastEvents = events
        }
        #expect(illegal == 0, "\(mapName): \(illegal) illegal actions")
        // Every open stall must have a painted neighbor reachable from a gate.
        let network = AutoPlanner.networkTiles(state)
        #expect(!network.isEmpty, "\(mapName): empty walkway network (\(state.walkwayTiles.count) walkways, budget \(state.usedBudget)/\(state.walkwayBudget))")
        var connected = 0
        for stall in state.stalls where stall.isOpen {
            var reachable = false
            stall.position.forEachNeighbor(in: state.grid) { neighbor in
                if network.contains(neighbor) { reachable = true }
            }
            if reachable { connected += 1 }
        }
        #expect(
            connected >= 2,
            "\(mapName): only \(connected) stalls adjacent to the network (\(state.walkwayTiles.count) walkways painted, budget \(state.usedBudget)/\(state.walkwayBudget), served \(state.score))"
        )
    }
}
