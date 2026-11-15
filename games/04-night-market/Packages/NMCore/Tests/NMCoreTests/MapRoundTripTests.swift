import Testing
import Foundation
@testable import NMCore

/// P3 content: the committed map JSONs must decode, the taipei map must
/// reproduce the built-in GameState.initial layout byte-for-byte, and the
/// other maps must produce legal start states.
struct MapRoundTripTests {
    /// Resolves Resources/Content/maps from this test file's location
    /// (Packages/NMCore/Tests/NMCoreTests → ../../../../Resources/Content/maps).
    private func loadMap(_ name: String) throws -> MapDefinition {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // NMCoreTests
            .appendingPathComponent("../../../../Resources/Content/maps/\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MapDefinition.self, from: data)
    }

    @Test func taipeiContentMatchesBuiltinExactly() throws {
        let map = try loadMap("taipei")
        let builtin = GameState.initial(seed: 42)
        let content = try GameState.initial(seed: 42, map: map)
        #expect(StateHash.hex(builtin) == StateHash.hex(content))
        #expect(builtin == content)
    }

    @Test func bangkokAndMarrakeshProduceLegalStartStates() throws {
        for name in ["bangkok", "marrakesh"] {
            let map = try loadMap(name)
            let state = try GameState.initial(seed: 7, map: map)
            #expect(state.stalls.count == 6, Comment(rawValue: name))
            #expect(state.gates.count == map.gates.count, Comment(rawValue: name))
            #expect(state.fixtures.count == map.lanternSpots.count, Comment(rawValue: name))
            for stall in state.stalls {
                switch state.grid.tile(at: stall.position) {
                case .ground, .plaza: break
                case .water, .building:
                    Issue.record("\(name): stall on unwalkable tile \(stall.position)")
                }
            }
        }
    }

    @Test func bangkokGatesOpenBySchedule() throws {
        let map = try loadMap("bangkok")
        let state = try GameState.initial(seed: 11, map: map)
        #expect(state.gates[0].opensAtTick == nil)
        #expect(state.gates[1].opensAtTick == 3600)
        #expect(state.gates[2].opensAtTick == 7200)
    }

    @Test func decodeRejectsBadTiles() {
        let bad = MapDefinition(
            id: "x", name: "X", size: [4, 4], tiles: "AAAA", gates: [], gateOpenTicks: [],
            zones: [:], stallStride: 1, lanternSpots: [], schedule: "s", palette: "p")
        #expect(throws: ContentError.self) { try bad.decodeTiles() }
    }
}
