/// Replay engine: deterministic simulation from seed + actions.
public enum Replay {
    /// Run a replay deterministically.
    public static func run(_ replay: ReplayData, rng: inout SeededRNG) -> GameState {
        let stateArray = [rng.state.0, rng.state.1, rng.state.2, rng.state.3]
        precondition(replay.seed == stateArray.reduce(0) { $0 ^ $1 }, "Seed mismatch")

        var state = GameState.initial(seed: replay.seed, contentVersion: replay.contentVersion)

        for timedAction in replay.actions {
            // Skip actions before current tick
            if timedAction.tick > state.clock.tick { continue }

            do {
                let (newState, _) = try Reducer.apply(timedAction.action, to: state, rng: &rng)
                state = newState
            } catch {
                // Invalid action — skip
            }
        }

        return state
    }

    /// Record a single tick's worth of actions.
    public static func record(state: GameState, action: Action, tick: Int) -> TimedAction {
        TimedAction(tick: tick, action: action)
    }
}
