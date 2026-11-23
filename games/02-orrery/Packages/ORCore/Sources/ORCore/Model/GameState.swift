/// The full game state (roadmap §5 schema).
public struct GameState: Sendable, Codable, Hashable {
    /// The four rings, index 0 = ring 1 (inner) … index 3 = ring 4 (outer).
    public var rings: [RingState]

    /// Planets left to place, per player (R-4: 10 at start).
    public var reserve: [PlayerID: Int]
    /// Enemy planets captured by this player, per player (R-15: 5 wins).
    public var captured: [PlayerID: Int]

    /// Player to move.
    public var toMove: PlayerID
    /// Round number, 1-based (a round = both players moved; R-7 rotation lands
    /// at the end of a round).
    public var round: Int
    /// Turn within the round: 0 = player 1 to move, 1 = player 2 to move.
    public var turnInRound: Int

    /// The last nudge taken by *either* player — the R-6 ko memory. A nudge
    /// sets it; the next action of any kind (place, nudge, pass) replaces or
    /// clears it, so it binds exactly the immediately following turn. The
    /// end-of-round rotation is not a turn and does not clear it.
    public var lastNudge: Nudge?
    /// Whether each player's immediately preceding own action was a nudge
    /// (R-6: a player may not nudge on two consecutive own turns unless
    /// their reserve is empty — they must place in between).
    public var nudgedLastTurn: [PlayerID: Bool]
    /// Variant identifier (e.g. "standard").
    public var variantID: String
    /// Content version stamped for replay compatibility.
    public var contentVersion: String

    /// Terminal result, set when the game ends.
    public var result: Result?

    /// A recorded nudge for ko tracking.
    public struct Nudge: Sendable, Codable, Hashable {
        public var player: PlayerID
        public var ring: Int
        public var dir: Int

        public init(player: PlayerID, ring: Int, dir: Int) {
            self.player = player
            self.ring = ring
            self.dir = dir
        }
    }

    /// How the game ended.
    public enum Result: Sendable, Codable, Hashable {
        /// `winner == nil` is not produced (ties resolve per R-16).
        case won(PlayerID, reason: String)
        case timeout(PlayerID, reason: String)
    }

    public init(
        rings: [RingState],
        reserve: [PlayerID: Int],
        captured: [PlayerID: Int],
        toMove: PlayerID,
        round: Int,
        turnInRound: Int,
        lastNudge: Nudge?,
        nudgedLastTurn: [PlayerID: Bool] = [:],
        variantID: String,
        contentVersion: String = Replay.contentVersion,
        result: Result? = nil
    ) {
        self.rings = rings
        self.reserve = reserve
        self.captured = captured
        self.toMove = toMove
        self.round = round
        self.turnInRound = turnInRound
        self.lastNudge = lastNudge
        self.nudgedLastTurn = nudgedLastTurn
        self.variantID = variantID
        self.contentVersion = contentVersion
        self.result = result
    }

    /// Planets on the board for a player.
    public func planetsOnBoard(_ player: PlayerID) -> Int {
        rings.reduce(0) { total, ring in
            total + ring.occupants.values.filter { $0 == player }.count
        }
    }

    /// All of a player's planets as PlanetRefs, ring-major in slot order.
    public func planets(of player: PlayerID) -> [PlanetRef] {
        var result: [PlanetRef] = []
        for (index, ring) in rings.enumerated() {
            for slot in ring.occupants.keys.sorted() where ring.occupants[slot] == player {
                result.append(PlanetRef(ring: index + 1, slot: slot, owner: player))
            }
        }
        return result
    }

    /// The angle of a planet right now.
    public func angle(of planet: PlanetRef) -> Angle48 {
        rings[planet.ring - 1].angle(ofSlot: planet.slot)
    }
}
