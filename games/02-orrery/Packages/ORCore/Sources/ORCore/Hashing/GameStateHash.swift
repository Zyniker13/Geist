/// Canonical FNV-1a digest of the full GameState (INV-4 checkpoints).
///
/// The encoding is versioned (`encodingVersion` bumps on field-set changes).
/// All collections are walked in canonical order (sorted slots, sorted planet
/// lists) so the digest never depends on dictionary iteration order.
public enum GameStateHash {
    public static func digest(_ state: GameState) -> UInt64 {
        var hasher = FNV1a()
        hasher.byte(StateHash.gameStateEncodingVersion)
        hasher.string(state.variantID)
        hasher.string(state.contentVersion)
        hasher.int(state.round)
        hasher.int(state.turnInRound)
        hasher.int(state.toMove.rawValue)
        hasher.bool(state.lastNudge != nil)
        if let last = state.lastNudge {
            hasher.int(last.player.rawValue)
            hasher.int(last.ring)
            hasher.int(last.dir)
        }

        for ring in state.rings {
            hasher.int(ring.slots)
            hasher.int(ring.offset)
            hasher.int(ring.speed)
            hasher.int(ring.occupants.count)
            for slot in ring.occupants.keys.sorted() {
                hasher.int(slot)
                hasher.int(ring.occupants[slot]!.rawValue)
            }
        }

        for player in PlayerID.allCases {
            hasher.int(state.reserve[player] ?? 0)
            hasher.int(state.captured[player] ?? 0)
            hasher.bool(state.nudgedLastTurn[player] ?? false)
        }

        if let result = state.result {
            hasher.byte(1)
            switch result {
            case .won(let player, _):
                hasher.byte(0)
                hasher.int(player.rawValue)
            case .timeout(let player, _):
                hasher.byte(1)
                hasher.int(player.rawValue)
            }
        } else {
            hasher.byte(0)
        }

        return hasher.finish()
    }

    /// Hex form of the digest.
    public static func hex(_ state: GameState) -> String {
        StateHash.hexDigest(digest(state))
    }
}
