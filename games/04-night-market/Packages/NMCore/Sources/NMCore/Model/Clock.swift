/// A gate where customers enter.
public struct Gate: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public var position: Tile
    public var isOpen: Bool
    /// Tick at which this gate opens (R-6: 21:00 and 00:00 when the map has more gates).
    public var opensAtTick: Int?

    public init(id: Int, position: Tile, isOpen: Bool = true, opensAtTick: Int? = nil) {
        self.id = id
        self.position = position
        self.isOpen = opensAtTick == nil
        self.opensAtTick = opensAtTick
    }
}

/// Weather state.
public enum Weather: Codable, Sendable, Equatable, Hashable {
    case clear
    case rain(duration: Int)  // remaining ticks

    public var isRaining: Bool {
        if case .rain = self { return true }
        return false
    }
}

/// The game clock.
public struct Clock: Codable, Sendable, Equatable, Hashable {
    public var tick: Int
    public var ticksPerHour: Int
    public var startHour: Int
    public var endHour: Int
    /// Night length in hours (shortened to 9 by the early-close modifier).
    public var nightHours: Int = 12

    public init(
        tick: Int = 0, ticksPerHour: Int = 1800, startHour: Int = 18, endHour: Int = 6,
        nightHours: Int = 12
    ) {
        self.tick = tick
        self.ticksPerHour = ticksPerHour
        self.startHour = startHour
        self.endHour = endHour
        self.nightHours = nightHours
    }

    public var currentHour: Int {
        let totalTicks = tick
        let hourIndex = totalTicks / ticksPerHour
        return (startHour + hourIndex) % 24
    }

    public var hoursElapsed: Int {
        tick / ticksPerHour
    }

    public var isNightOver: Bool {
        tick >= ticksPerHour * nightHours  // default 12 hours = 06:00
    }
}
