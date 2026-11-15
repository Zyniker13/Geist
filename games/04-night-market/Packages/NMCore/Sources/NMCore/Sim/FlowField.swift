/// Flow-field pathfinding (R-10).
///
/// Per-stall-color Dijkstra over traversable tiles with edge costs:
/// base 10, dark tile (no lantern within radius 3) +6, rain without awning
/// cover +12, within busker radius 2 −3, corner turn +2, minimum 4 per step.
/// Corner costs make the search direction-aware: states are (tile, direction
/// of arrival). A separate color-independent field targets the open gates.
///
/// Results are cached in `state.pathFields` keyed by `state.fieldVersion`;
/// edits (walkways, fixtures, opens, rain) bump the version and force a
/// recompute. Recomputation is pure — the cache never changes results.
public enum FlowFields {
    /// Ensure `state.pathFields` matches `state.fieldVersion`, recomputing if stale.
    /// Returns the (possibly updated) state.
    public static func ensureCurrent(for state: GameState) -> GameState {
        var s = state
        if s.pathFields.version == s.fieldVersion { return s }
        s.pathFields = compute(for: s)
        s.pathFields.version = s.fieldVersion
        return s
    }

    /// Compute all fields from scratch.
    public static func compute(for state: GameState) -> PathFields {
        var byColor: [StallColor: [Tile: Int]] = [:]
        for color in StallColor.allCases {
            byColor[color] = dijkstra(targets: state.openStalls.filter { $0.color == color }.map(\.position), in: state)
        }
        let toGates = dijkstra(targets: state.openGates.map(\.position), in: state)
        return PathFields(version: state.fieldVersion, byColor: byColor, toGates: toGates)
    }

    /// Multi-source Dijkstra over (tile, arrival-direction) states.
    ///
    /// Flat-array state: index = (row * width + col) * 4 + direction. Arrays
    /// beat nested dictionaries hard in Debug builds, and the whole grid is
    /// only 640 tiles.
    private static func dijkstra(targets: [Tile], in state: GameState) -> [Tile: Int] {
        guard !targets.isEmpty else { return [:] }

        let width = state.grid.width
        let height = state.grid.height
        let tileCount = width * height
        let stateCount = tileCount * 4

        var best = [Int](repeating: Int.max, count: stateCount)
        var result = [Int](repeating: -1, count: tileCount)
        // Bucket queue keyed by cost (edge costs are small positive integers).
        var frontier: [Int: [(Int, Int)]] = [:]  // cost → [(flatState, dirIndex)]
        var maxCost = 0

        func push(_ tileIndex: Int, _ dirIndex: Int, _ cost: Int) {
            let flat = tileIndex * 4 + dirIndex
            if best[flat] <= cost { return }
            best[flat] = cost
            frontier[cost, default: []].append((flat, dirIndex))
            if cost > maxCost { maxCost = cost }
        }

        for target in targets {
            let ti = target.row * width + target.col
            for d in 0..<4 {
                push(ti, d, 0)
            }
        }

        var minCost = 0
        while minCost <= maxCost {
            guard var bucket = frontier[minCost], !bucket.isEmpty else {
                minCost += 1
                continue
            }
            let (flat, dirIndex) = bucket.removeFirst()
            frontier[minCost] = bucket
            let cost = minCost
            let tileIndex = flat / 4
            if result[tileIndex] == -1 { result[tileIndex] = cost }
            let col = tileIndex % width
            let row = tileIndex / width

            for outDir in 0..<4 {
                let direction = Direction.allCases[outDir]
                let nc = col + direction.delta.col
                let nr = row + direction.delta.row
                guard nc >= 0, nc < width, nr >= 0, nr < height else { continue }
                let neighbor = Tile(col: nc, row: nr)
                // Traversability is a property of the tile being entered.
                guard state.isTraversable(neighbor) else { continue }
                let from = Direction.allCases[dirIndex]
                let turn = Direction.isTurn(from: from, to: direction) ? 2 : 0
                let newCost = cost + edgeCost(of: neighbor, in: state) + turn
                push(nr * width + nc, outDir, newCost)
            }
        }

        var out: [Tile: Int] = [:]
        out.reserveCapacity(tileCount)
        for index in 0..<tileCount where result[index] >= 0 {
            out[Tile(col: index % width, row: index / width)] = result[index]
        }
        return out
    }

    /// Edge cost of stepping ONTO `tile` (R-10). Tile must be traversable.
    public static func edgeCost(of tile: Tile, in state: GameState) -> Int {
        var cost = 10

        // Dark: no lantern within radius 3.
        let lit = state.fixtures.contains { fixture in
            guard case .lantern = fixture.kind else { return false }
            return tile.manhattanTiles(to: fixture.position) <= 3
        }
        if !lit { cost += 6 }

        // Rain without awning cover (3×3 around the awning, radius 1).
        if state.weather.isRaining {
            let covered = state.fixtures.contains { fixture in
                guard case .awning = fixture.kind else { return false }
                return tile.manhattanTiles(to: fixture.position) <= 1
            }
            if !covered { cost += 12 }
        }

        // Busker attraction within radius 2.
        let buskerNearby = state.fixtures.contains { fixture in
            guard case .busker = fixture.kind else { return false }
            return tile.manhattanTiles(to: fixture.position) <= 2
        }
        if buskerNearby { cost -= 3 }

        return max(4, cost)
    }
}
