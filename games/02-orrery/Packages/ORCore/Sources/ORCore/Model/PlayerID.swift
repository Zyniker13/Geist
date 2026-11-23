/// Player identity on the orrery board.
public enum PlayerID: Int, Sendable, Codable, Hashable, CaseIterable {
    /// Player 1 — cobalt enamel, moves first (R-4).
    case one = 1
    /// Player 2 — ivory enamel.
    case two = 2

    /// The other player.
    public var opponent: PlayerID {
        self == .one ? .two : .one
    }
}
