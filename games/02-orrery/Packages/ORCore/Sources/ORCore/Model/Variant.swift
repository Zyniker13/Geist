/// A playable variant definition (roadmap §5).
///
/// P1 uses the built-in Standard variant; the JSON catalog arrives in P3.
public struct Variant: Sendable, Codable, Hashable {
    public var id: String
    public var name: String
    /// Per-ring (slotCount, speed) from ring 1 (inner) to ring 4 (outer).
    public var rings: [RingSpec]
    public var reserve: Int
    public var maxRounds: Int
    public var capturesToWin: Int

    public struct RingSpec: Sendable, Codable, Hashable {
        public var slots: Int
        public var speed: Int

        public init(slots: Int, speed: Int) {
            self.slots = slots
            self.speed = speed
        }
    }

    public init(id: String, name: String, rings: [RingSpec], reserve: Int, maxRounds: Int, capturesToWin: Int) {
        self.id = id
        self.name = name
        self.rings = rings
        self.reserve = reserve
        self.maxRounds = maxRounds
        self.capturesToWin = capturesToWin
    }

    /// The Standard variant (R-1…R-4).
    public static let standard = Variant(
        id: "standard",
        name: "Standard",
        rings: [
            RingSpec(slots: 8, speed: 12),
            RingSpec(slots: 12, speed: 8),
            RingSpec(slots: 16, speed: -3),
            RingSpec(slots: 24, speed: 2),
        ],
        reserve: 10,
        maxRounds: 20,
        capturesToWin: 5
    )
}
