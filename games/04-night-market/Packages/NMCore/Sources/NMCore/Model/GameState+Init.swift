/// Optional overrides for tests and tools that need a custom map or start set.
public struct GameStateOverrides: Sendable {
    public var grid: Grid?
    public var gates: [Gate]?
    public var stalls: [Stall]?
    public var fixtures: [Fixture]?
    public var walkwayBudget: Int?
    public var rainSchedule: [RainShower]?

    public init(
        grid: Grid? = nil, gates: [Gate]? = nil, stalls: [Stall]? = nil,
        fixtures: [Fixture]? = nil, walkwayBudget: Int? = nil,
        rainSchedule: [RainShower]? = nil
    ) {
        self.grid = grid
        self.gates = gates
        self.stalls = stalls
        self.fixtures = fixtures
        self.walkwayBudget = walkwayBudget
        self.rainSchedule = rainSchedule
    }
}

/// Game state initialisation (R-1, R-2, R-3, R-6, R-17).
///
/// R-3 start: 2 stalls open (seeded positions from zones), 1 gate active,
/// walkway budget 30 tiles, 2 lanterns, 0 awnings, 0 buskers.
public extension GameState {
    static func initial(
        seed: UInt64, contentVersion: String = "0.0.0", overrides: GameStateOverrides = .init()
    ) -> GameState {
        var rng = SeededRNG(seed: seed)

        // Build a default 32×20 grid (R-1)
        var tiles: [TileType] = Array(repeating: .ground, count: 32 * 20)
        // Plaza first; canals are applied after so they cut through it (R-1).
        for row in 8..<13 {
            for col in 12..<20 {
                tiles[row * 32 + col] = .plaza
            }
        }
        // Canals are 3 tiles wide so a single R-15 bridge (1–3 tiles) can cross.
        for row in [7, 12] {
            for col in 14..<17 {
                tiles[row * 32 + col] = .water(.canal)
            }
        }
        let grid = Grid(tiles: tiles)

        // Gates: gate 0 active at 18:00; gate 1 opens at 21:00 (R-6).
        let gates: [Gate] = [
            Gate(id: 0, position: Tile(col: 0, row: 9)),
            Gate(id: 1, position: Tile(col: 0, row: 10), opensAtTick: 3 * 1800),
        ]

        // Stall candidates on the plaza, seeded shuffle for positions from zones (R-3, R-6).
        var candidatePositions: [Tile] = []
        for row in [9, 11] {
            for col in stride(from: 13, through: 17, by: 2) {
                candidatePositions.append(Tile(col: col, row: row))
            }
        }
        rng.shuffle(&candidatePositions)

        // Two stalls open at start; the rest scheduled across hours 2–5 with
        // seeded jitter of up to 300 ticks (R-6).
        var stalls: [Stall] = []
        for (idx, color) in StallColor.allCases.enumerated() {
            let position = candidatePositions[idx]
            if idx < 2 {
                stalls.append(Stall(id: idx, color: color, position: position, serviceTicks: 90))
            } else {
                let base = (idx) * 1800  // hour boundaries for idx 2..5
                let jitter = Int(rng.next(upperBound: 601)) - 300
                let openTick = max(1, base + jitter)
                stalls.append(
                    Stall(
                        id: idx, color: color, position: position, serviceTicks: 90,
                        scheduledOpenTick: openTick
                    )
                )
            }
        }

        // Two starting lanterns on plaza tiles (R-3).
        let lanternSpots = [Tile(col: 14, row: 10), Tile(col: 17, row: 10)]
        var fixtures: [Fixture] = []
        for (i, spot) in lanternSpots.enumerated() {
            fixtures.append(
                Fixture(id: i, kind: .lantern(radius: 3), position: spot, radius: 3)
            )
        }

        // Rain schedule: 0–3 showers, 90–180 s each (2700–5400 ticks), never
        // before 19:00 (tick 3600); showers are sequential with a gap (R-17).
        let showerCount = Int(rng.next(upperBound: 4))
        var rainSchedule: [RainShower] = []
        var cursor = 3600 + Int(rng.next(upperBound: 1801))
        for _ in 0..<showerCount {
            let duration = 2700 + Int(rng.next(upperBound: 2701))
            rainSchedule.append(RainShower(startTick: cursor, durationTicks: duration))
            cursor += duration + Int(rng.next(upperBound: 1801))
        }

        let finalGrid = overrides.grid ?? grid
        let finalGates = overrides.gates ?? gates
        let finalStalls = overrides.stalls ?? stalls
        let finalFixtures = overrides.fixtures ?? fixtures
        let finalBudget = overrides.walkwayBudget ?? 30
        let finalRain = overrides.rainSchedule ?? rainSchedule

        return GameState(
            grid: finalGrid,
            stalls: finalStalls,
            gates: finalGates,
            fixtures: finalFixtures,
            customers: [],
            weather: .clear,
            clock: Clock(tick: 0),
            walkwayTiles: [],
            walkwayBudget: finalBudget,
            usedBudget: 0,
            score: 0,
            nextCustomerID: 0,
            nextFixtureID: finalFixtures.count,
            contentVersion: contentVersion,
            speedMultiplier: 1,
            isPaused: false,
            rainSchedule: finalRain,
            pendingOffers: [],
            fieldVersion: 0,
            pathFields: PathFields()
        )
    }

    /// Content-driven initialisation from a `MapDefinition` (P3). Applies the
    /// same R-3/R-6 semantics: seeded stall shuffle inside the zone rects
    /// (deduplicated, colour-major), two stalls open, the rest opening across
    /// hours 2–5 with seeded jitter, starting lanterns from the map, and the
    /// seeded R-17 rain schedule. For the Taipei map this must reproduce the
    /// built-in layout byte-for-byte (see MapRoundTripTests).
    public static func initial(
        seed: UInt64, map: MapDefinition, contentVersion: String = "0.0.0",
        overrides: GameStateOverrides = .init()
    ) throws -> GameState {
        var rng = SeededRNG(seed: seed)
        let grid = try map.grid()

        let gates: [Gate] = map.gates.enumerated().map { index, position in
            let tick = index < map.gateOpenTicks.count ? map.gateOpenTicks[index] : 0
            return Gate(
                id: index, position: Tile(col: position[0], row: position[1]),
                opensAtTick: tick == 0 ? nil : tick)
        }

        // Stall candidates: union of zone rects, colour-major, stride-filtered,
        // walkable tiles only, deduplicated preserving order.
        var candidatePositions: [Tile] = []
        var seen = Set<Tile>()
        for color in StallColor.allCases {
            for rect in map.zones[color.debugName] ?? [] {
                guard rect.count >= 4 else { continue }
                for row in stride(from: rect[1], to: rect[1] + rect[3], by: max(1, map.stallStride)) {
                    for col in stride(from: rect[0], to: rect[0] + rect[2], by: max(1, map.stallStride)) {
                        let tile = Tile(col: col, row: row)
                        guard seen.insert(tile).inserted else { continue }
                        switch grid.tile(at: tile) {
                        case .ground, .plaza:
                            candidatePositions.append(tile)
                        case .water, .building:
                            continue
                        }
                    }
                }
            }
        }
        guard candidatePositions.count >= StallColor.allCases.count else {
            throw ContentError.invalidField("zones: only \(candidatePositions.count) candidates")
        }
        rng.shuffle(&candidatePositions)

        var stalls: [Stall] = []
        for (idx, color) in StallColor.allCases.enumerated() {
            let position = candidatePositions[idx]
            if idx < 2 {
                stalls.append(Stall(id: idx, color: color, position: position, serviceTicks: 90))
            } else {
                let base = idx * 1800
                let jitter = Int(rng.next(upperBound: 601)) - 300
                let openTick = max(1, base + jitter)
                stalls.append(
                    Stall(
                        id: idx, color: color, position: position, serviceTicks: 90,
                        scheduledOpenTick: openTick))
            }
        }

        let fixtures: [Fixture] = map.lanternSpots.enumerated().map { index, spot in
            Fixture(id: index, kind: .lantern(radius: 3), position: Tile(col: spot[0], row: spot[1]), radius: 3)
        }

        let showerCount = Int(rng.next(upperBound: 4))
        var rainSchedule: [RainShower] = []
        var cursor = 3600 + Int(rng.next(upperBound: 1801))
        for _ in 0..<showerCount {
            let duration = 2700 + Int(rng.next(upperBound: 2701))
            rainSchedule.append(RainShower(startTick: cursor, durationTicks: duration))
            cursor += duration + Int(rng.next(upperBound: 1801))
        }

        let finalGrid = overrides.grid ?? grid
        let finalGates = overrides.gates ?? gates
        let finalStalls = overrides.stalls ?? stalls
        let finalFixtures = overrides.fixtures ?? fixtures
        let finalRain = overrides.rainSchedule ?? rainSchedule

        return GameState(
            grid: finalGrid,
            stalls: finalStalls,
            gates: finalGates,
            fixtures: finalFixtures,
            customers: [],
            weather: .clear,
            clock: Clock(tick: 0),
            walkwayTiles: [],
            walkwayBudget: overrides.walkwayBudget ?? 30,
            usedBudget: 0,
            score: 0,
            nextCustomerID: 0,
            nextFixtureID: finalFixtures.count,
            contentVersion: contentVersion,
            speedMultiplier: 1,
            isPaused: false,
            rainSchedule: finalRain,
            pendingOffers: [],
            fieldVersion: 0,
            pathFields: PathFields()
        )
    }
}
