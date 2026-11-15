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
    /// Scheduled rain showers for the night (R-17).
    public var rainSchedule: [RainShower]
    /// Placeable-fixture tokens granted by upgrades, consumed on placement (ADR-0010).
    public var fixtureStock: FixtureStock = FixtureStock()
    /// Per-color demand weights for spawning (P3: distinct per map; keyed by
    /// `StallColor.debugName`, missing colors default to 1).
    public var zoneWeights: [String: Int] = [:]
    /// Calm first-night mode (NM-P3.4): slower spawn ramp on night 1 only.
    public var calmFirstNight: Bool = false
    /// Hourly spawn rates in effect (DirectorTuner sweeps these; default is
    /// R-7's standard ramp).
    public var spawnRates: [Int] = Spawner.hourlyRates
    /// Active challenge modifiers (NM-P5.2); behavior-affecting, hashed.
    public var challengeModifiers: [ChallengeModifier] = []
    /// Queue-capacity offset from the small-queues modifier (can be negative).
    public var queueCapacityMod: Int = 0
    /// Score per served customer (2 under double-serves; R-13 default 1).
    public var scorePerServe: Int = 1
    /// Upgrade offers waiting at an hour boundary (R-5); non-empty implies paused-for-choice.
    public var pendingOffers: [UpgradeOffer]
    /// Bumped whenever geometry changes (walkways, fixtures, stall/gate opens, rain).
    /// Cached flow fields in `pathFields` are valid only at this version.
    public var fieldVersion: Int
    /// Cached flow-field distances.
    public var pathFields: PathFields

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
        isPaused: Bool,
        rainSchedule: [RainShower] = [],
        fixtureStock: FixtureStock = FixtureStock(),
        zoneWeights: [String: Int] = [:],
        calmFirstNight: Bool = false,
        spawnRates: [Int] = Spawner.hourlyRates,
        challengeModifiers: [ChallengeModifier] = [],
        queueCapacityMod: Int = 0,
        scorePerServe: Int = 1,
        pendingOffers: [UpgradeOffer] = [],
        fieldVersion: Int = 0,
        pathFields: PathFields = PathFields()
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
        self.rainSchedule = rainSchedule
        self.fixtureStock = fixtureStock
        self.zoneWeights = zoneWeights
        self.calmFirstNight = calmFirstNight
        self.spawnRates = spawnRates
        self.challengeModifiers = challengeModifiers
        self.queueCapacityMod = queueCapacityMod
        self.scorePerServe = scorePerServe
        self.pendingOffers = pendingOffers
        self.fieldVersion = fieldVersion
        self.pathFields = pathFields
    }
}

// MARK: - Traversability (R-10)

public extension GameState {
    /// Water tiles physically covered by a bridge fixture.
    var bridgeTiles: Set<Tile> {
        var tiles: Set<Tile> = []
        for fixture in fixtures where fixture.direction != nil {
            if case .bridge = fixture.kind {
                tiles.formUnion(fixture.coveredTiles())
            }
        }
        return tiles
    }

    /// Movement is only on walkway, plaza, and bridge tiles (R-10).
    /// Gate and stall tiles are always enterable (entry/exit and service points).
    func isTraversable(_ tile: Tile) -> Bool {
        if gates.contains(where: { $0.position == tile }) { return true }
        if stalls.contains(where: { $0.position == tile }) { return true }
        switch grid.tile(at: tile) {
        case .plaza:
            return true
        case .ground:
            return walkwayTiles.contains(tile)
        case .water, .building:
            return bridgeTiles.contains(tile)
        }
    }
}

// MARK: - Lookup helpers

public extension GameState {
    func stall(id: Int) -> Stall? {
        stalls.first { $0.id == id }
    }

    func stallTile(_ stall: Stall) -> FixedPoint2 {
        FixedPoint2(x: Int32(stall.position.col) * 1024, y: Int32(stall.position.row) * 1024)
    }

    func gateTile(_ gate: Gate) -> FixedPoint2 {
        FixedPoint2(x: Int32(gate.position.col) * 1024, y: Int32(gate.position.row) * 1024)
    }

    /// The tile a position sits on.
    public func tileOf(_ position: FixedPoint2) -> Tile {
        Tile(col: Int(position.x) / 1024, row: Int(position.y) / 1024)
    }

    /// Center of a tile in sub-tile units.
    static func center(of tile: Tile) -> FixedPoint2 {
        FixedPoint2(x: Int32(tile.col) * 1024 + 512, y: Int32(tile.row) * 1024 + 512)
    }

    var openGates: [Gate] {
        gates.filter { $0.isOpen }
    }

    var openStalls: [Stall] {
        stalls.filter { $0.isOpen }
    }
}
