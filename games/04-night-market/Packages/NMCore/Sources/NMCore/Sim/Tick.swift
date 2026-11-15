/// Simulation tick: advance customer positions, spawning, service, overflow.
public enum Tick {
    /// Advance the simulation by one tick.
    public static func advance(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        var events: [Event] = []

        // Paused: nothing advances.
        if s.isPaused {
            return (s, events)
        }

        // Advance clock (speed multiplier compresses time).
        s.clock.tick += s.speedMultiplier

        // Weather updates
        if case .rain(let duration) = s.weather {
            if duration <= 1 {
                s.weather = .clear
                events.append(.rainEnded)
            } else {
                s.weather = .rain(duration: duration - 1)
            }
        }

        // Check night end
        if s.clock.isNightOver {
            let survived = true
            events.append(.nightEnded(score: s.score, survived: survived))
            return (s, events)
        }

        // Spawn customers
        (s, events) = Spawner.spawn(state: s, rng: &rng)

        // Move customers
        (s, events) = Movement.moveAll(state: s, rng: &rng)

        // Service queues
        (s, events) = Service.serviceAll(state: s, rng: &rng)

        // Check overflow
        (s, events) = Overflow.checkAll(state: s, rng: &rng)

        // Check score
        s = Scoring.update(state: s)

        return (s, events)
    }
}
