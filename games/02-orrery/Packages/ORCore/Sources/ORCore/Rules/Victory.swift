/// Victory conditions (R-15…R-17) and the R-16 tie-break.
public enum Victory {
    /// Evaluate terminal conditions on `state`. Order matters: R-14 Grand
    /// Alignment and R-15 captures-to-win are checked by the reducer at their
    /// trigger points; this evaluates a finished board consistently.
    ///
    /// Returns nil while the game continues.
    public static func evaluate(_ state: GameState, variant: Variant) -> GameState.Result? {
        // R-15: captures-to-win.
        for player in PlayerID.allCases where (state.captured[player] ?? 0) >= variant.capturesToWin {
            return .won(player, reason: "captured \(variant.capturesToWin) enemy planets")
        }
        // R-17: a player with no planets on the board and none in reserve loses.
        for player in PlayerID.allCases
        where state.planetsOnBoard(player) == 0 && (state.reserve[player] ?? 0) == 0 {
            return .won(player.opponent, reason: "opponent has no planets left")
        }
        // R-16: round limit.
        guard state.round > variant.maxRounds else { return nil }
        return timeoutResult(state)
    }

    /// R-16 tie-break: more planets on the board wins; tie → more captures;
    /// tie → Player 2 wins.
    public static func timeoutResult(_ state: GameState) -> GameState.Result {
        let p1 = state.planetsOnBoard(.one)
        let p2 = state.planetsOnBoard(.two)
        if p1 != p2 {
            return .timeout(p1 > p2 ? .one : .two, reason: "more planets on the board after \(state.round - 1) rounds")
        }
        let c1 = state.captured[.one] ?? 0
        let c2 = state.captured[.two] ?? 0
        if c1 != c2 {
            return .timeout(c1 > c2 ? .one : .two, reason: "more captures after the board tied")
        }
        return .timeout(.two, reason: "tie broken in favor of Player 2 (R-16)")
    }
}
