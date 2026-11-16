/// A market stall.
public struct Stall: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let color: StallColor
    public var position: Tile
    public var isOpen: Bool
    /// Tick at which this stall opens (R-6 schedule, jitter already applied).
    public var scheduledOpenTick: Int?
    public var queue: [CustomerID]
    public var serviceProgress: Int  // ticks until next service
    public var overflowTimer: Int
    public var serviceTicks: Int  // default 90
    /// Extra queue capacity granted by the extra-queue upgrade (ADR-0010).
    public var queueCapacityBonus: Int = 0

    public init(
        id: Int, color: StallColor, position: Tile, serviceTicks: Int = 90,
        scheduledOpenTick: Int? = nil
    ) {
        self.id = id
        self.color = color
        self.position = position
        self.isOpen = scheduledOpenTick == nil
        self.queue = []
        self.serviceProgress = 0
        self.overflowTimer = 0
        self.serviceTicks = serviceTicks
        self.scheduledOpenTick = scheduledOpenTick
    }
}

/// Customer colors (stall colors) — color-blind-safe set.
public enum StallColor: Codable, Sendable, Equatable, Hashable, CaseIterable {
    case noodles  // circle, #FF5A5F
    case tea  // triangle, #3DDC97
    case skewers  // square, #FFD23F
    case dumplings  // diamond, #2E7FFF
    case sweets  // star, #F062C8
    case seafood  // hexagon, #FF8C42

    public var shape: Shape {
        switch self {
        case .noodles: return .circle
        case .tea: return .triangle
        case .skewers: return .square
        case .dumplings: return .diamond
        case .sweets: return .star
        case .seafood: return .hexagon
        }
    }

    public var debugName: String {
        switch self {
        case .noodles: return "noodles"
        case .tea: return "tea"
        case .skewers: return "skewers"
        case .dumplings: return "dumplings"
        case .sweets: return "sweets"
        case .seafood: return "seafood"
        }
    }
}

public enum Shape: Codable, Sendable, Equatable, Hashable {
    case circle, triangle, square, diamond, star, hexagon
}

public typealias CustomerID = Int
