/// Player actions (roadmap §5 schema; R-5).
public enum Action: Sendable, Codable, Hashable {
    /// Place a planet from reserve into an empty slot of `ring` (1-based).
    case place(ring: Int, slot: Int)
    /// Nudge `ring` (1-based) by `dir` slots (±1): an immediate one-slot
    /// rotation of that ring.
    case nudge(ring: Int, dir: Int)
    /// Pass (only legal when no other action is legal, R-8).
    case pass
}

/// Errors the reducer throws.
public enum RuleError: Error, Equatable, Sendable {
    case gameAlreadyOver
    case notPlayersTurn(PlayerID, expected: PlayerID)
    case unknownRing(Int)
    case slotOutOfRange(ring: Int, slot: Int)
    case slotOccupied(ring: Int, slot: Int)
    case reserveEmpty(PlayerID)
    case nudgeTwoTurnsInARow
    case nudgeKo(ring: Int, dir: Int)
    case illegalPass
}
