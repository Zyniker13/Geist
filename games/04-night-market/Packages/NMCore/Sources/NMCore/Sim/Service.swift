/// Queue service and overflow logic.
public enum Service {
    /// Advance service timers for all stalls.
    public static func serviceAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        var events: [Event] = []

        for idx in s.stalls.indices {
            var stall = s.stalls[idx]
            guard stall.isOpen && !stall.queue.isEmpty else { continue }

            stall.serviceProgress += 1
            if stall.serviceProgress >= stall.serviceTicks {
                // Serve the first customer in queue
                let servedID = stall.queue.removeFirst()
                events.append(.served(servedID, stall.color))
                stall.serviceProgress = 0
            }

            s.stalls[idx] = stall
        }

        return (s, events)
    }
}

/// Overflow checking.
public enum Overflow {
    /// Check all stalls for overflow conditions.
    public static func checkAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        var events: [Event] = []

        for idx in s.stalls.indices {
            var stall = s.stalls[idx]
            guard stall.isOpen else { continue }

            let queueCapacity = 6 + stall.queue.count  // base 6 + waiting gate customers
            let actualQueueLength = stall.queue.count

            if actualQueueLength > queueCapacity {
                stall.overflowTimer += 1
                if stall.overflowTimer <= 100 {
                    events.append(.overflowWarning(stall.id, progress: stall.overflowTimer))
                }
            } else {
                stall.overflowTimer = 0
            }

            // Check game-ending overflow (600 ticks)
            if stall.overflowTimer >= 600 {
                events.append(.nightEnded(score: s.score, survived: false))
            }

            s.stalls[idx] = stall
        }

        return (s, events)
    }
}
