/// The pure reducer: applies an action to a GameState, returning a new state and any events.
public enum RuleError: Error, Sendable {
    case illegalAction(String)
    case budgetExceeded
    case invalidPosition
    case stallNotFound(Int)
    case invalidSpeed(Int)
}

public enum Reducer {
    /// Apply an action to the current state.
    public static func apply(_ action: Action, to state: GameState, rng: inout SeededRNG) throws(RuleError) -> (
        GameState, [Event]
    ) {
        var newState = state

        switch action {
        case .paintWalkway(let tiles):
            let (s, events) = applyPaint(tiles, to: &newState)
            return (s, events)

        case .eraseWalkway(let tiles):
            let (s, events) = applyErase(tiles, to: &newState)
            return (s, events)

        case .placeFixture(let kind, let tile):
            let (s, events) = applyPlace(kind, at: tile, to: &newState)
            return (s, events)

        case .moveFixture(let id, let tile):
            let (s, events) = applyMove(id, to: tile, in: &newState)
            return (s, events)

        case .chooseUpgrade(let id):
            let (s, events) = applyUpgrade(id, to: &newState)
            return (s, events)

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
            newState.isPaused = false
            return (newState, [])
        }
    }

    // MARK: - Walkway painting

    private static func applyPaint(_ tiles: [Tile], to state: inout GameState) -> (GameState, [Event]) {
        let newTiles = tiles.filter { tile in
            state.grid.isWalkable(tile) && !state.walkwayTiles.contains(tile)
        }
        let canAfford = state.usedBudget + newTiles.count <= state.walkwayBudget
        guard canAfford else { return (state, []) }

        for tile in newTiles {
            state.walkwayTiles.insert(tile)
        }
        state.usedBudget += newTiles.count

        return (state, [])
    }

    // MARK: - Walkway erasure

    private static func applyErase(_ tiles: [Tile], to state: inout GameState) -> (GameState, [Event]) {
        let existing = tiles.filter { state.walkwayTiles.contains($0) }
        state.walkwayTiles.subtract(existing)
        state.usedBudget -= existing.count
        return (state, [])
    }

    // MARK: - Fixture placement

    private static func applyPlace(_ kind: FixtureKind, at tile: Tile, to state: inout GameState) -> (
        GameState, [Event]
    ) {
        guard state.grid.isWalkable(tile) else { return (state, []) }
        let fixture = Fixture(id: state.nextFixtureID, kind: kind, position: tile, radius: kind.radius())
        state.fixtures.append(fixture)
        state.nextFixtureID += 1
        return (state, [])
    }

    // MARK: - Fixture movement

    private static func applyMove(_ id: Int, to tile: Tile, in state: inout GameState) -> (GameState, [Event]) {
        guard let idx = state.fixtures.firstIndex(where: { $0.id == id }) else {
            return (state, [])
        }
        guard state.grid.isWalkable(tile) else { return (state, []) }
        state.fixtures[idx].position = tile
        return (state, [])
    }

    // MARK: - Upgrades

    private static func applyUpgrade(_ id: String, to state: inout GameState) -> (GameState, [Event]) {
        // Placeholder: actual upgrade logic in P3/P5
        return (state, [])
    }
}

// MARK: - FixtureKind radius helper

private extension FixtureKind {
    func radius() -> Int {
        switch self {
        case .lantern(let r): return r
        case .awning: return 1  // 3x3 = radius 1
        case .busker(let r): return r
        case .bridge(let len): return len
        case .seat: return 0
        }
    }
}
