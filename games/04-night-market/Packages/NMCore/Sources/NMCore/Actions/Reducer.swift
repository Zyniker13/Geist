/// The pure reducer: applies an action to a GameState, returning a new state and any events.
/// All actions are legal while paused or running (R-16); the reducer validates each.
public enum RuleError: Error, Sendable {
    case illegalAction(String)
    case budgetExceeded
    case invalidPosition
    case invalidFixture(String)
    case stallNotFound(Int)
    case invalidSpeed(Int)
    case upgradeNotOffered(String)
}

public enum Reducer {
    /// Apply an action to the current state.
    public static func apply(_ action: Action, to state: GameState, rng: inout SeededRNG) throws(RuleError) -> (
        GameState, [Event]
    ) {
        var newState = state

        switch action {
        case .paintWalkway(let tiles):
            return try applyPaint(tiles, to: &newState)

        case .eraseWalkway(let tiles):
            return applyErase(tiles, to: &newState)

        case .placeFixture(let kind, let tile):
            return try applyPlace(kind, at: tile, to: &newState)

        case .moveFixture(let id, let tile):
            return try applyMove(id, to: tile, in: &newState)

        case .chooseUpgrade(let id):
            return try applyUpgrade(id, to: &newState)

        case .setSpeed(let speed):
            guard [1, 2, 3].contains(speed) else {
                throw .invalidSpeed(speed)
            }
            newState.speedMultiplier = speed
            return (newState, [])

        case .pause:
            newState.isPaused = true
            return (newState, [])

        case .resume:
            // A pending upgrade choice holds the pause (R-5): resume is illegal
            // until the player chooses.
            if !newState.pendingOffers.isEmpty {
                throw .illegalAction("choose an upgrade first")
            }
            newState.isPaused = false
            return (newState, [])
        }
    }

    // MARK: - Walkway painting (R-14)

    private static func applyPaint(_ tiles: [Tile], to state: inout GameState) throws(RuleError) -> (GameState, [Event])
    {
        let newTiles = tiles.filter { tile in
            guard state.grid.boundsContain(tile) else { return false }
            switch state.grid.tile(at: tile) {
            case .ground, .plaza: return !state.walkwayTiles.contains(tile)
            case .water, .building: return false
            }
        }
        guard state.usedBudget + newTiles.count <= state.walkwayBudget else {
            throw .budgetExceeded
        }
        for tile in newTiles {
            state.walkwayTiles.insert(tile)
        }
        state.usedBudget += newTiles.count
        state.fieldVersion += 1
        return (state, [])
    }

    // MARK: - Walkway erasure (R-14)

    private static func applyErase(_ tiles: [Tile], to state: inout GameState) -> (GameState, [Event]) {
        let existing = tiles.filter { state.walkwayTiles.contains($0) }
        guard !existing.isEmpty else { return (state, []) }
        state.walkwayTiles.subtract(existing)
        state.usedBudget -= existing.count
        state.fieldVersion += 1

        // Customers standing on erased tiles move to the nearest walkway (R-14).
        relocateStranded(off: Set(existing), in: &state)
        return (state, [])
    }

    /// Moves customers stranded on non-traversable tiles of `affected` to the
    /// nearest traversable tile (R-14; the same rule applies to bridge moves so
    /// no customer is ever left standing on open water). Seat-seekers whose
    /// target seat became unreachable give up and walk to the exit instead.
    private static func relocateStranded(off affected: Set<Tile>, in state: inout GameState) {
        for idx in state.customers.indices {
            let tile = state.tileOf(state.customers[idx].position)
            guard affected.contains(tile), !state.isTraversable(tile) else { continue }
            if let relocated = nearestTraversableTile(from: tile, in: state) {
                state.customers[idx].position = GameState.center(of: relocated)
                // Reset in-flight walks; the next tick re-targets.
                if state.customers[idx].state == .walkingToStall {
                    state.customers[idx].state = .atGateWaiting
                    state.customers[idx].targetStall = nil
                }
            }
        }
        for idx in state.customers.indices {
            guard state.customers[idx].state == .walkingToSeat,
                let seatID = state.customers[idx].targetSeatID,
                let fixture = state.fixtures.first(where: { $0.id == seatID })
            else { continue }
            if !state.isTraversable(fixture.position) {
                state.customers[idx].state = .walkingToExit
                state.customers[idx].targetSeatID = nil
            }
        }
    }

    /// Nearest traversable tile by BFS (used when walkways are erased).
    static func nearestTraversableTile(from tile: Tile, in state: GameState) -> Tile? {
        if state.isTraversable(tile) { return tile }
        var visited: Set<Tile> = [tile]
        var frontier = [tile]
        while !frontier.isEmpty {
            var next: [Tile] = []
            for current in frontier {
                for neighbor in current.neighbors(in: state.grid) where !visited.contains(neighbor) {
                    if state.isTraversable(neighbor) { return neighbor }
                    visited.insert(neighbor)
                    next.append(neighbor)
                }
            }
            frontier = next
        }
        return nil
    }

    // MARK: - Fixture placement (R-15)

    private static func applyPlace(_ kind: FixtureKind, at tile: Tile, to state: inout GameState) throws(RuleError) -> (
        GameState, [Event]
    ) {
        let canonical = FixtureKind.canonical(kind)
        guard state.grid.boundsContain(tile) else { throw .invalidPosition }

        if case .bridge(let length) = canonical {
            guard (1...3).contains(length) else {
                throw .invalidFixture("bridges span exactly 1–3 water tiles")
            }
            guard let direction = bridgeDirection(from: tile, length: length, in: state) else {
                throw .invalidFixture("bridge must span 1–3 water tiles in a straight line")
            }
            guard state.fixtureStock.bridge > 0 else {
                throw .illegalAction("no bridge token; earn one from an upgrade")
            }
            state.fixtureStock.bridge -= 1
            let fixture = Fixture(
                id: state.nextFixtureID, kind: canonical, position: tile,
                radius: canonical.defaultRadius, direction: direction
            )
            state.fixtures.append(fixture)
            state.nextFixtureID += 1
            state.fieldVersion += 1
            return (state, [])
        }

        // Non-bridge fixtures stand on traversable tiles and consume a token
        // of their kind (ADR-0010); R-3's starting lanterns bypass this by
        // being created directly in initialisation.
        guard state.isTraversable(tile) else { throw .invalidPosition }
        switch canonical {
        case .lantern:
            guard state.fixtureStock.lantern > 0 else {
                throw .illegalAction("no lantern token; earn one from an upgrade")
            }
            state.fixtureStock.lantern -= 1
        case .awning:
            guard state.fixtureStock.awning > 0 else {
                throw .illegalAction("no awning token; earn one from an upgrade")
            }
            state.fixtureStock.awning -= 1
        case .busker:
            guard state.fixtureStock.busker > 0 else {
                throw .illegalAction("no busker token; earn one from an upgrade")
            }
            state.fixtureStock.busker -= 1
        case .seat:
            guard state.fixtureStock.seating > 0 else {
                throw .illegalAction("no seating token; earn one from an upgrade")
            }
            state.fixtureStock.seating -= 1
        case .bridge:
            break
        }
        let fixture = Fixture(
            id: state.nextFixtureID, kind: canonical, position: tile, radius: canonical.defaultRadius
        )
        state.fixtures.append(fixture)
        state.nextFixtureID += 1
        state.fieldVersion += 1
        return (state, [])
    }

    /// Find a direction whose adjacent run of water tiles is exactly 1–3 long.
    public static func bridgeDirection(from tile: Tile, length: Int, in state: GameState) -> Direction? {
        for direction in Direction.allCases {
            var col = tile.col + direction.delta.col
            var row = tile.row + direction.delta.row
            var waterRun = 0
            while waterRun < length {
                let t = Tile(col: col, row: row)
                guard state.grid.boundsContain(t), case .water = state.grid.tile(at: t) else { break }
                waterRun += 1
                col += direction.delta.col
                row += direction.delta.row
            }
            if waterRun == length {
                // The far side must be walkable land so the bridge connects.
                let landing = Tile(col: col, row: row)
                if state.grid.boundsContain(landing) {
                    switch state.grid.tile(at: landing) {
                    case .ground, .plaza:
                        return direction
                    case .water, .building:
                        continue
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Fixture movement (R-15)

    private static func applyMove(_ id: Int, to tile: Tile, in state: inout GameState) throws(RuleError) -> (
        GameState, [Event]
    ) {
        guard let idx = state.fixtures.firstIndex(where: { $0.id == id }) else {
            throw .stallNotFound(id)
        }
        guard state.grid.boundsContain(tile) else { throw .invalidPosition }
        let kind = state.fixtures[idx].kind

        if case .bridge(let length) = kind {
            guard let direction = bridgeDirection(from: tile, length: length, in: state) else {
                throw .invalidFixture("bridge must span 1–3 water tiles in a straight line")
            }
            // Tiles the old span covered can strand customers when the bridge
            // leaves them (R-14 analog: same relocation as erased walkways).
            let oldSpan = state.fixtures[idx].coveredTiles()
            state.fixtures[idx].position = tile
            state.fixtures[idx].direction = direction
            relocateStranded(off: oldSpan.union(state.fixtures[idx].coveredTiles()), in: &state)
        } else {
            guard state.isTraversable(tile) else { throw .invalidPosition }
            state.fixtures[idx].position = tile
        }
        state.fieldVersion += 1
        return (state, [])
    }

    // MARK: - Upgrades (R-5, R-16)

    private static func applyUpgrade(_ id: String, to state: inout GameState) throws(RuleError) -> (GameState, [Event])
    {
        guard let index = state.pendingOffers.firstIndex(where: { $0.id == id }) else {
            throw .upgradeNotOffered(id)
        }
        let offer = state.pendingOffers.remove(at: index)
        state.pendingOffers = []  // choosing one offer dismisses both (1 of 2)
        state.isPaused = false

        // Effects (P3: all eight kinds are real; ADR-0010).
        switch offer.kind {
        case .extraWalkwayBudget(let amount):
            state.walkwayBudget += amount
        case .extraLanterns(let count):
            state.fixtureStock.lantern += count
        case .extraAwning:
            state.fixtureStock.awning += 1
        case .extraBusker:
            state.fixtureStock.busker += 1
        case .extraBridge:
            state.fixtureStock.bridge += 1
        case .extraSeating:
            state.fixtureStock.seating += 1
        case .fasterService(let percent):
            let target = Reducer.busiestStall(in: state)
            let ticks = state.stalls[target].serviceTicks
            state.stalls[target].serviceTicks = max(30, ticks - ticks * percent / 100)
        case .extraQueue(let capacity):
            let target = Reducer.busiestStall(in: state)
            state.stalls[target].queueCapacityBonus += capacity
        }
        return (state, [])
    }

    /// The busiest stall: longest queue, ties broken by lowest id. Targets the
    /// "one stall" upgrades (faster cooks, extra queue).
    static func busiestStall(in state: GameState) -> Int {
        var best = 0
        for (index, stall) in state.stalls.enumerated()
        where stall.queue.count > state.stalls[best].queue.count {
            best = index
        }
        return best
    }
}
