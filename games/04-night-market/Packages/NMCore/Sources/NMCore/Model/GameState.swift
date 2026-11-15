/// The complete game state. Immutable (struct, Codable, Equatable, Hashable, Sendable).
public struct GameState: Codable, Sendable, Equatable, Hashable {
    public let grid: Grid
    public var stalls: [Stall]
    public var gates: [Gate]
    public var fixtures: [Fixture]
    public var customers: [Customer]
    public var weather: Weather
    public var clock: Clock
    public var walkwayTiles: Set<Tile>
    public var walkwayBudget: Int
    public var usedBudget: Int
    public var score: Int
    public var nextCustomerID: CustomerID
    public var nextFixtureID: Int
    public var contentVersion: String
    public var speedMultiplier: Int  // 1, 2, or 3
    public var isPaused: Bool

    public init(
        grid: Grid,
        stalls: [Stall],
        gates: [Gate],
        fixtures: [Fixture],
        customers: [Customer],
        weather: Weather,
        clock: Clock,
        walkwayTiles: Set<Tile>,
        walkwayBudget: Int,
        usedBudget: Int,
        score: Int,
        nextCustomerID: CustomerID,
        nextFixtureID: Int,
        contentVersion: String,
        speedMultiplier: Int,
        isPaused: Bool
    ) {
        self.grid = grid
        self.stalls = stalls
        self.gates = gates
        self.fixtures = fixtures
        self.customers = customers
        self.weather = weather
        self.clock = clock
        self.walkwayTiles = walkwayTiles
        self.walkwayBudget = walkwayBudget
        self.usedBudget = usedBudget
        self.score = score
        self.nextCustomerID = nextCustomerID
        self.nextFixtureID = nextFixtureID
        self.contentVersion = contentVersion
        self.speedMultiplier = speedMultiplier
        self.isPaused = isPaused
    }
}
