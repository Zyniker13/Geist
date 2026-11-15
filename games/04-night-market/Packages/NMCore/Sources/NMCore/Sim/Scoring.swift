/// Scoring logic (R-13).
public enum Scoring {
    /// Apply the dawn bonus when the night is survived: +25% of the score.
    public static func dawnBonus(for score: Int) -> Int {
        score / 4
    }

    /// Final score after a survived night.
    public static func finalScore(survived: Bool, score: Int) -> Int {
        survived ? score + dawnBonus(for: score) : score
    }

    /// Update hook kept for the tick pipeline; per-serve scoring happens in Service.
    public static func update(state: GameState) -> GameState {
        state
    }
}
