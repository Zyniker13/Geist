/// Flow-field pathfinding for customers.
///
/// Per-stall-color Dijkstra over the walkway graph. Recomputed when walkways, lights,
/// awnings, buskers, or weather change.
public struct FlowField {
    private var fields: [StallColor: [Tile: Int]]  // tile → steps to nearest stall of that color
    private var invalidationCount: Int = 0

    public init() {
        self.fields = [:]
    }

    /// Invalidate all cached fields.
    public mutating func invalidate() {
        fields.removeAll()
        invalidationCount += 1
    }

    /// Compute flow fields for all colors.
    public mutating func compute(for state: GameState) {
        invalidate()
        for color in StallColor.allCases {
            compute(for: color, in: state)
        }
    }

    private mutating func compute(for color: StallColor, in state: GameState) {
        // Find all open stalls of this color
        let targets = state.stalls.filter { $0.isOpen && $0.color == color }
        guard !targets.isEmpty else {
            fields[color] = [:]
            return
        }

        // Multi-source Dijkstra from all target stalls
        var distances: [Tile: Int] = [:]
        var queue: [(Tile, Int)] = []

        for stall in targets {
            distances[stall.position] = 0
            queue.append((stall.position, 0))
        }

        var head = 0
        while head < queue.count {
            let (tile, dist) = queue[head]
            head += 1

            for neighbor in tile.neighbors(in: state.grid) {
                // Unwalkable tiles are unreachable; skip them (never add their cost).
                guard state.grid.isWalkable(neighbor) else { continue }
                let newDist = dist + tileCost(neighbor, in: state, for: color)
                if distances[neighbor] == nil || newDist < distances[neighbor]! {
                    distances[neighbor] = newDist
                    queue.append((neighbor, newDist))
                }
            }
        }

        fields[color] = distances
    }

    /// Movement cost of a walkable tile. Callers must check `isWalkable` first.
    private func tileCost(_ tile: Tile, in state: GameState, for color: StallColor) -> Int {
        // Base cost
        var cost = 10

        // Dark penalty: no lantern within radius 3
        let hasLight = state.fixtures.contains { fixture in
            switch fixture.kind {
            case .lantern(let r):
                return tile.manhattanTiles(to: fixture.position) <= r
            default:
                return false
            }
        }
        if !hasLight { cost += 6 }

        // Rain penalty unless an awning is within one tile
        if state.weather.isRaining {
            let hasAwning = state.fixtures.contains { f in
                f.kind == .awning && tile.manhattanTiles(to: f.position) <= 1
            }
            if !hasAwning { cost += 12 }
        }

        // Busker bonus
        let buskerNearby = state.fixtures.contains { fixture in
            switch fixture.kind {
            case .busker(let r):
                return tile.manhattanTiles(to: fixture.position) <= r
            default:
                return false
            }
        }
        if buskerNearby { cost -= 3 }

        return max(4, cost)  // min 4
    }

    /// Get steps to nearest stall of a color from a tile.
    public func steps(toColor color: StallColor, at tile: Tile) -> Int? {
        fields[color]?[tile]
    }
}
