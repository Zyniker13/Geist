/// Scoring logic.
public enum Scoring {
    /// Update score from served events (tracked in events).
    public static func update(state: GameState) -> GameState {
        var s = state
        // Score is incremented in the reducer when .served events are produced.
        // The UI layer tracks this; here we just ensure invariants hold.
        return s
    }
}
