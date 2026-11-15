import Foundation
import NMCore
import NMContent

/// The heuristic balance bot (NM-P4.1): on each stall opening it paints the
/// shortest walkway path from the connected gate network to the stall
/// (successive-shortest-paths Steiner approximation), places lanterns from
/// stock on the highest-traffic dark tiles, and picks upgrades by a fixed
/// priority. Used only for sims and difficulty tuning — never shipped input.
///
/// Every action it emits is pre-checked against the rules so the driver's
/// reducer never throws: the G4 check "1,000 nights without illegal actions".
public final class AutoPlanner {
    /// Grid index of a tile (row-major, matching Grid's flat storage).
    @inline(__always)
    private static func index(_ tile: Tile, in grid: Grid) -> Int {
        tile.row * grid.width + tile.col
    }

    @inline(__always)
    private static func moved(_ tile: Tile, _ direction: Direction) -> Tile {
        let delta = direction.delta
        return Tile(col: tile.col + delta.col, row: tile.row + delta.row)
    }

    private var handledStalls: Set<Int> = []
    private var bridgeBlockedStalls: Set<Int> = []
    private var heatmap: [Int]
    private var width: Int
    private var height: Int

    public init() {
        heatmap = []
        width = 0
        height = 0
    }

    /// Fixed upgrade priority (§7): growth first, then service, then capacity.
    static let priority: [UpgradeKind] = [
        .extraWalkwayBudget(20), .fasterService(20), .extraLanterns(2),
        .extraQueue(2), .extraSeating, .extraAwning, .extraBusker, .extraBridge,
    ]

    /// Returns one legal action for this tick, or nil to idle. `events` are
    /// the events from the previous tick advance; replanning (stall
    /// connection, bridges, lanterns) only runs on connection triggers —
    /// night start, stall/gate openings, and hour boundaries — so the bot
    /// stays O(1) in the common tick.
    public func nextAction(for state: GameState, events: [Event] = []) -> Action? {
        if width != state.grid.width || height != state.grid.height {
            width = state.grid.width
            height = state.grid.height
            heatmap = Array(repeating: 0, count: width * height)
        }
        trackTraffic(state)

        // 1. Upgrade choice at an hour boundary. Bridge-blocked stalls bump
        // the bridge upgrade to the front so Bangkok's east stalls connect.
        if !state.pendingOffers.isEmpty {
            let wantBridge = !bridgeBlockedStalls.isEmpty
            if wantBridge, let bridge = state.pendingOffers.first(where: { $0.kind == .extraBridge }) {
                bridgeBlockedStalls.removeAll()
                return .chooseUpgrade(bridge.id)
            }
            for kind in Self.priority {
                if let offer = state.pendingOffers.first(where: { $0.kind == kind }) {
                    return .chooseUpgrade(offer.id)
                }
            }
            if let first = state.pendingOffers.first { return .chooseUpgrade(first.id) }
        }

        let replan = state.clock.tick == 0 || events.contains(where: { event in
            switch event {
            case .stallOpened, .gateOpened, .hourReached: return true
            default: return false
            }
        })

        // 2. Connect stalls that are open but not yet reached by the network.
        if replan {
            for stall in state.stalls where stall.isOpen && !handledStalls.contains(stall.id) {
                if let action = connectStall(stall, in: state) {
                    if case .paintWalkway(let tiles) = action {
                        // Budget-blocked: retry at the next hour boundary.
                        if tiles.count > state.walkwayBudget - state.usedBudget { continue }
                    }
                    // The whole remaining path is painted in one action, so
                    // the stall's connection is complete once this applies.
                    handledStalls.insert(stall.id)
                    return action
                }
                // No land path: consider a bridge connection.
                if let bridgeTile = Self.bridgeConnection(for: stall, in: state) {
                    if state.fixtureStock.bridge > 0 {
                        // Bridge placed now; the land path beyond is painted
                        // at the next replan (the stall stays unhandled).
                        return .placeFixture(.bridge(length: 1), bridgeTile)
                    }
                    // Bridge-blocked: keep the stall unhandled and prefer
                    // the bridge upgrade at the next hour boundary.
                    bridgeBlockedStalls.insert(stall.id)
                    continue
                }
                handledStalls.insert(stall.id)
            }
        }

        // 3. Lanterns from stock onto the highest-traffic dark tile. The
        // grid scan runs on replans and every 300th tick only.
        if state.fixtureStock.lantern > 0, replan || state.clock.tick % 300 == 0,
           let tile = Self.darkestBusyTile(heatmap: heatmap, width: width, state: state)
        {
            return .placeFixture(.lantern(radius: 3), tile)
        }
        return nil
    }

    private func trackTraffic(_ state: GameState) {
        for customer in state.customers {
            let tile = Self.index(state.tileOf(customer.position), in: state.grid)
            if heatmap.indices.contains(tile) { heatmap[tile] += 1 }
        }
    }

    /// Shortest land path from the stall's front tile to the walkway network
    /// connected to an open gate (or to a gate tile itself); paints the new
    /// tiles. Returns nil when no land path exists.
    private func connectStall(_ stall: Stall, in state: GameState) -> Action? {
        // Try each neighbor of the stall as the path start (fixed order):
        // the tile "below" may be a building wall in the bazaar maps.
        for direction in [Direction.south, .north, .east, .west] {
            let delta = direction.delta
            let start = Tile(col: stall.position.col + delta.col, row: stall.position.row + delta.row)
            guard state.grid.boundsContain(start), Self.paintable(start, in: state) else { continue }
            if let action = paintPath(from: start, in: state) { return action }
        }
        return nil
    }

    private func paintPath(from start: Tile, in state: GameState) -> Action? {
        let path = Self.shortestPath(from: start, to: Self.networkTiles(state), in: state)
        guard let path, !path.isEmpty else { return nil }
        let fresh = path.filter { !state.walkwayTiles.contains($0) }
        guard !fresh.isEmpty else { return nil }
        // Paint the whole remaining path in one action: the stall connects
        // the moment it applies (R-14 has no per-action tile cap, only
        // budget).
        return .paintWalkway(Array(fresh.prefix(state.walkwayBudget - state.usedBudget)))
    }

    /// Walkway tiles already connected to an open (or opening-at-0) gate,
    /// plus those gate tiles. Painting before the first tick is legal play,
    /// so gates scheduled for tick 0 count as network seeds.
    static func networkTiles(_ state: GameState) -> Set<Tile> {
        var seeds: Set<Tile> = []
        for gate in state.gates where gate.isOpen || (gate.opensAtTick ?? 1) <= 0 {
            seeds.insert(gate.position)
        }
        guard !seeds.isEmpty else { return [] }
        // Flood the walkway graph from the gates through walkway tiles.
        var seen = seeds
        var queue = Array(seeds)
        while let tile = queue.popLast() {
            tile.forEachNeighbor(in: state.grid) { neighbor in
                if state.walkwayTiles.contains(neighbor), !seen.contains(neighbor) {
                    seen.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        return seen
    }

    /// The tile in front of a stall (the tile customers stand on): the
    /// traversable neighbor closest to the gate row; falls back to below.
    static func frontTile(of position: Tile, in grid: Grid) -> Tile {
        let below = Tile(col: position.col, row: position.row + 1)
        if grid.boundsContain(below) { return below }
        return position
    }

    /// A tile the planner may walk through while planning a paint: paintable
    /// ground/plaza, existing walkways, gate and stall positions. Ground is
    /// only traversable once painted (R-14), so painting paths are planned
    /// over paintable tiles, not traversable ones.
    static func paintable(_ tile: Tile, in state: GameState) -> Bool {
        if state.gates.contains(where: { $0.position == tile }) { return true }
        if state.stalls.contains(where: { $0.position == tile }) { return true }
        if state.walkwayTiles.contains(tile) { return true }
        if state.bridgeTiles.contains(tile) { return true }
        switch state.grid.tile(at: tile) {
        case .ground, .plaza: return true
        case .water, .building: return false
        }
    }

    /// BFS shortest path over paintable land from `start` to any target.
    static func shortestPath(from start: Tile, to targets: Set<Tile>, in state: GameState) -> [Tile]? {
        guard !targets.isEmpty else { return nil }
        if targets.contains(start) { return [] }
        var parent: [Int: Int] = [:]
        var queue = [start]
        var head = 0
        parent[Self.index(start, in: state.grid)] = Self.index(start, in: state.grid)
        while head < queue.count {
            let tile = queue[head]
            head += 1
            var found = false
            tile.forEachNeighbor(in: state.grid) { neighbor in
                guard !found, Self.paintable(neighbor, in: state) else { return }
                let index = Self.index(neighbor, in: state.grid)
                guard parent[index] == nil else { return }
                parent[index] = Self.index(tile, in: state.grid)
                if targets.contains(neighbor) { found = true }
                queue.append(neighbor)
            }
            if found {
                var path: [Tile] = []
                var cursor = Self.index(tile, in: state.grid)
                let startIndex = Self.index(start, in: state.grid)
                while cursor != startIndex {
                    path.append(Tile(col: cursor % state.grid.width, row: cursor / state.grid.width))
                    cursor = parent[cursor] ?? startIndex
                }
                // Include the start tile: it is the tile adjacent to the
                // stall, and without it the painted path never touches the
                // stall (invisible on plaza maps, fatal on ground lanes).
                path.append(start)
                return path.reversed()
            }
        }
        return nil
    }

    /// A water tile whose bridging would connect the stall's land component
    /// to the gate network: water with land on both sides within a 3-run.
    static func bridgeConnection(for stall: Stall, in state: GameState) -> Tile? {
        let start = frontTile(of: stall.position, in: state.grid)
        guard state.isTraversable(start) else { return nil }
        var component: Set<Tile> = [start]
        var queue = [start]
        while let tile = queue.popLast() {
            tile.forEachNeighbor(in: state.grid) { neighbor in
                if state.isTraversable(neighbor), !component.contains(neighbor) {
                    component.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        let network = networkTiles(state)
        for tile in component {
            for direction in [Direction.east, .west, .north, .south] {
                var run: [Tile] = []
                var cursor = tile
                for _ in 0..<3 {
                    cursor = Self.moved(cursor, direction)
                    guard state.grid.boundsContain(cursor), !state.isTraversable(cursor) else { break }
                    run.append(cursor)
                }
                guard (1...3).contains(run.count) else { continue }
                let far = Self.moved(run[run.count - 1], direction)
                if state.grid.boundsContain(far),
                   component.contains(far) || network.contains(far),
                   run.contains(where: { networkTiles(state).contains($0) == false })
                {
                    // Bridge the run only if the far side leaves the stall's
                    // component (otherwise it changes nothing).
                    if !component.contains(far) { return run[0] }
                }
            }
        }
        return nil
    }

    /// The highest-traffic tile that is traversable, unwalkway-priority (not
    /// under a stall), and not already lit by a lantern.
    static func darkestBusyTile(heatmap: [Int], width: Int, state: GameState) -> Tile? {
        var lit: Set<Int> = []
        for fixture in state.fixtures {
            guard case .lantern = fixture.kind else { continue }
            let center = fixture.position
            for dy in -3...3 {
                for dx in -3...3 {
                    let tile = Tile(col: center.col + dx, row: center.row + dy)
                    if state.grid.boundsContain(tile) { lit.insert(Self.index(tile, in: state.grid)) }
                }
            }
        }
        var best: (Int, Tile)?
        for row in 0..<state.grid.height {
            for col in 0..<state.grid.width {
                let tile = Tile(col: col, row: row)
                guard state.isTraversable(tile), !state.walkwayTiles.contains(tile) else { continue }
                let index = Self.index(tile, in: state.grid)
                guard !lit.contains(index), heatmap[index] >= 5 else { continue }
                if best == nil || heatmap[index] > best!.0 {
                    best = (heatmap[index], tile)
                }
            }
        }
        return best?.1
    }
}
