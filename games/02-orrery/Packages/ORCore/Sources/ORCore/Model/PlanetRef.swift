/// A planet reference: which ring, which slot. Angles are derived from the
/// ring's current offset, so a PlanetRef always describes the planet's *current*
/// position, and survives rotation.
public struct PlanetRef: Sendable, Codable, Hashable {
    /// Ring index 1…4 (R-1).
    public var ring: Int
    /// Slot index on that ring.
    public var slot: Int
    /// Owner of the planet.
    public var owner: PlayerID

    public init(ring: Int, slot: Int, owner: PlayerID) {
        self.ring = ring
        self.slot = slot
        self.owner = owner
    }
}
