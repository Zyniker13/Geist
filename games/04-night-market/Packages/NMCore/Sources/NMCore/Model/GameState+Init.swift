/// Game state initialisation.
public extension GameState {
    /// Create initial game state from a seed.
    static func initial(seed: UInt64, contentVersion: String = "0.0.0") -> GameState {
        // Build a default 32×20 grid
        var tiles: [TileType] = Array(repeating: .ground, count: 32 * 20)
        // Add some water features (canals)
        for col in 10..<22 {
            tiles[7 * 32 + col] = .water(.canal)
            tiles[12 * 32 + col] = .water(.canal)
        }
        // Add plaza area
        for row in 8..<13 {
            for col in 12..<20 {
                tiles[row * 32 + col] = .plaza
            }
        }

        let grid = Grid(tiles: tiles)

        // Gates at edges
        let gates: [Gate] = [
            Gate(id: 0, position: Tile(col: 0, row: 9)),
            Gate(id: 1, position: Tile(col: 0, row: 10)),
        ]

        // Stalls
        let stallPositions: [Tile] = [
            Tile(col: 13, row: 9), Tile(col: 15, row: 9),
            Tile(col: 17, row: 9), Tile(col: 13, row: 11),
            Tile(col: 15, row: 11), Tile(col: 17, row: 11),
        ]

        let stalls: [Stall] = StallColor.allCases.enumerated().map { idx, color in
            Stall(
                id: idx,
                color: color,
                position: stallPositions[idx],
                serviceTicks: 90
            )
        }

        return GameState(
            grid: grid,
            stalls: stalls,
            gates: gates,
            fixtures: [],
            customers: [],
            weather: .clear,
            clock: Clock(tick: 0),
            walkwayTiles: [],
            walkwayBudget: 640,
            usedBudget: 0,
            score: 0,
            nextCustomerID: 0,
            nextFixtureID: 0,
            contentVersion: contentVersion,
            speedMultiplier: 1,
            isPaused: false
        )
    }
}
