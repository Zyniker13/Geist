/// Actions that can change game state.
public enum Action: Codable, Sendable, Equatable, Hashable {
    case paintWalkway([Tile])
    case eraseWalkway([Tile])
    case placeFixture(FixtureKind, Tile)
    case moveFixture(Int, Tile)
    case chooseUpgrade(String)
    case setSpeed(Int)
    case pause
    case resume
}

/// Events emitted by the reducer (pure, no side effects).
public enum Event: Codable, Sendable, Equatable, Hashable {
    case stallOpened(Int)
    case gateOpened(Int)
    case served(CustomerID, StallColor)
    case overflowWarning(Int, progress: Int)
    case rainStarted
    case rainEnded
    case hourReached(Int, offers: [String])
    case nightEnded(score: Int, survived: Bool)
}

/// A timed action for replay.
public struct TimedAction: Codable, Sendable, Equatable, Hashable {
    public let tick: Int
    public let action: Action

    public init(tick: Int, action: Action) {
        self.tick = tick
        self.action = action
    }
}

/// A replay: seed + content version + list of timed actions.
public struct ReplayData: Codable, Sendable, Equatable, Hashable {
    public let seed: UInt64
    public let contentVersion: String
    public let actions: [TimedAction]

    public init(seed: UInt64, contentVersion: String, actions: [TimedAction]) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.actions = actions
    }
}
