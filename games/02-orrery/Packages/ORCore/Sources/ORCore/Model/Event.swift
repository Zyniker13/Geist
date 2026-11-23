/// Events emitted by the reducer; render and audio subscribe to these
/// (§4.2.6) and never infer rules.
public enum Event: Sendable, Codable, Hashable {
    /// A planet was placed.
    case placed(PlayerID, ring: Int, slot: Int)
    /// A ring was nudged by one slot (dir ±1).
    case nudged(ring: Int, dir: Int)
    /// The end-of-round rotation applied (per-ring deltas).
    case rotated([Int])
    /// An alignment was found on line `line` (0…23) for `player`; `planets`
    /// lists the aligned planets, `captured` the enemy planets removed.
    case aligned(PlayerID, line: Int, planets: [PlanetRef])
    /// Enemy planets captured.
    case captured(PlayerID, planets: [PlanetRef])
    /// Grand Alignment: one planet per ring on the same ray.
    case grandAlignment(PlayerID)
    /// The game ended; `winner == nil` never occurs (ties resolve per R-16).
    case gameOver(PlayerID, reason: String)
}
