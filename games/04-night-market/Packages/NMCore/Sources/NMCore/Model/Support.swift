/// A scheduled rain shower (R-17): 0–3 per night, 90–180 s each, never before 19:00.
public struct RainShower: Codable, Sendable, Equatable, Hashable {
    public let startTick: Int
    public let durationTicks: Int

    public init(startTick: Int, durationTicks: Int) {
        self.startTick = startTick
        self.durationTicks = durationTicks
    }
}

/// One of the two upgrade offers shown at an hour boundary (R-5).
///
/// Effects land in P5; P1 carries the offer identity and the pause-until-choice rule.
public struct UpgradeOffer: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let kind: UpgradeKind

    public init(id: String, kind: UpgradeKind) {
        self.id = id
        self.kind = kind
    }
}

public enum UpgradeKind: Codable, Sendable, Equatable, Hashable {
    case extraWalkwayBudget(Int)
    case extraLanterns(Int)
    case extraAwning
    case extraBusker
    case extraBridge
    case extraSeating
    case fasterService(Int)  // percent reduction, applied to the busiest stall
    case extraQueue(Int)  // capacity added to the busiest stall
}

/// Placeable-fixture tokens granted by upgrades and consumed by placement
/// (ADR-0010). R-3's starting lanterns are placed directly, not stocked.
public struct FixtureStock: Codable, Sendable, Equatable, Hashable {
    public var lantern: Int
    public var awning: Int
    public var busker: Int
    public var bridge: Int
    public var seating: Int

    public init(lantern: Int = 0, awning: Int = 0, busker: Int = 0, bridge: Int = 0, seating: Int = 0) {
        self.lantern = lantern
        self.awning = awning
        self.busker = busker
        self.bridge = bridge
        self.seating = seating
    }
}

/// The position of a customer or a queue entry, in sub-tile units.
///
/// Kept as a small Codable wrapper so GameState can hold heterogeneous caches
/// without tuples (tuples are not Codable).
public struct QueueEntry: Codable, Sendable, Equatable, Hashable {
    public let customerID: CustomerID
    public let joinedTick: Int

    public init(customerID: CustomerID, joinedTick: Int) {
        self.customerID = customerID
        self.joinedTick = joinedTick
    }
}

/// Cached flow-field distances, keyed by the geometry version they were computed for.
///
/// Stored inside GameState so every consumer (movement, overflow attribution,
/// the headless sim) reads consistent distances without a side channel.
/// Recomputation is pure; the cache never changes results, only speed.
public struct PathFields: Codable, Sendable, Equatable, Hashable {
    public var version: Int
    /// Per stall color: tile → path-cost steps to the nearest open stall of that color.
    public var byColor: [StallColor: [Tile: Int]]
    /// Tile → path-cost steps to the nearest open gate (color-independent).
    public var toGates: [Tile: Int]

    public init(version: Int = -1, byColor: [StallColor: [Tile: Int]] = [:], toGates: [Tile: Int] = [:]) {
        self.version = version
        self.byColor = byColor
        self.toGates = toGates
    }

    public func steps(toColor color: StallColor, at tile: Tile) -> Int? {
        byColor[color]?[tile]
    }

    public func steps(toGateAt tile: Tile) -> Int? {
        toGates[tile]
    }
}
