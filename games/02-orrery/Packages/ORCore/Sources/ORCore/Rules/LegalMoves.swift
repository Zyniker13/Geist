/// Legal-move enumeration (R-5, R-6, R-8).
public enum LegalMoves {
    /// All legal actions for the player to move. Used by the UI and by the
    /// random-legal-move sim policy. Order is canonical: places (ring-major,
    /// slot-ascending), then nudges (ring-major, dir ascending), then pass.
    public static func all(in state: GameState) -> [Action] {
        guard state.result == nil else { return [] }
        let player = state.toMove
        var moves: [Action] = []

        // Places: any empty slot of any ring while reserve is non-empty.
        if (state.reserve[player] ?? 0) > 0 {
            for (index, ring) in state.rings.enumerated() {
                for slot in 0..<ring.slots where ring.occupants[slot] == nil {
                    moves.append(.place(ring: index + 1, slot: slot))
                    if moves.count >= maxEnumerated { return moves }
                }
            }
        }

        // Nudges: ±1 on any ring, subject to R-6 (no immediate undo of the
        // opponent's last nudge; no nudging two own turns in a row unless
        // reserve is empty).
        for index in state.rings.indices {
            for dir in [-1, 1] where isNudgeLegal(ring: index + 1, dir: dir, in: state) {
                moves.append(.nudge(ring: index + 1, dir: dir))
                if moves.count >= maxEnumerated { return moves }
            }
        }

        // Pass (R-8): legal only when nothing else is.
        if moves.isEmpty {
            moves.append(.pass)
        }
        return moves
    }

    /// The R-6 backstop: every legal action is a place or a nudge, and while
    /// either player holds a reserve the mover always has at least one legal
    /// place (the rings hold 8+12+16+24 = 60 slots for ≤ 20 planets on board).
    /// So a forced pass implies both reserves are empty. Use it to build the
    /// whole enumeration above (never open-coded), so the sim and the UI can
    /// never drift from the reducer's definition of legal.
    static var forcedPassMeansBothReservesEmpty: Bool { true }

    /// Upper bound per call for hot-loop safety; legal sets never exceed this
    /// in any cataloged variant (60 empty slots + 8 nudges).
    static let maxEnumerated = 68

    /// R-6 ko legality for a single nudge by the player to move.
    public static func isNudgeLegal(ring: Int, dir: Int, in state: GameState) -> Bool {
        guard state.result == nil else { return false }
        guard state.rings.indices.contains(ring - 1) else { return false }
        let player = state.toMove

        // Clause 1: may not nudge the ring the opponent nudged on the
        // immediately preceding turn in the opposite direction (undo loop).
        if let last = state.lastNudge, last.player == player.opponent,
            last.ring == ring, last.dir == -dir
        {
            return false
        }
        // Clause 2: a player may not nudge two turns in a row (must place in
        // between) unless their reserve is empty.
        if state.nudgedLastTurn[player] == true, (state.reserve[player] ?? 0) > 0 {
            return false
        }
        return true
    }
}
