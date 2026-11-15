/// Simulation tick: clock, schedules, weather, spawning, movement, service,
/// overflow, and night end (R-4 to R-13, R-17).
public enum Tick {
    /// Advance the simulation by one tick.
    public static func advance(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        var events: [Event] = []

        // Paused: nothing advances (a pending upgrade choice keeps this true).
        if s.isPaused {
            return (s, events)
        }

        // Advance clock by the speed multiplier (time compression).
        let hourBefore = s.clock.hoursElapsed
        s.clock.tick += s.speedMultiplier
        let hourAfter = s.clock.hoursElapsed

        // Weather: start scheduled showers; decay running ones (R-17).
        for shower in s.rainSchedule
        where s.clock.tick >= shower.startTick && s.clock.tick < shower.startTick + shower.durationTicks {
            if !s.weather.isRaining {
                s.weather = .rain(duration: shower.startTick + shower.durationTicks - s.clock.tick)
                events.append(.rainStarted)
                s.fieldVersion += 1  // rain changes path costs
            }
        }
        if case .rain(let remaining) = s.weather {
            if remaining <= s.speedMultiplier {
                s.weather = .clear
                events.append(.rainEnded)
                s.fieldVersion += 1
            } else {
                s.weather = .rain(duration: remaining - s.speedMultiplier)
            }
        }

        // Scheduled stall openings (R-6).
        for idx in s.stalls.indices {
            if let openTick = s.stalls[idx].scheduledOpenTick, !s.stalls[idx].isOpen, s.clock.tick >= openTick {
                s.stalls[idx].isOpen = true
                s.stalls[idx].scheduledOpenTick = nil
                events.append(.stallOpened(s.stalls[idx].id))
                s.fieldVersion += 1
            }
        }

        // Scheduled gate openings (R-6: 21:00 and 00:00 when the map has more).
        for idx in s.gates.indices {
            if let openTick = s.gates[idx].opensAtTick, !s.gates[idx].isOpen, s.clock.tick >= openTick {
                s.gates[idx].isOpen = true
                s.gates[idx].opensAtTick = nil
                events.append(.gateOpened(s.gates[idx].id))
                s.fieldVersion += 1
            }
        }

        // Night end at 06:00 (R-4): dawn bonus on survival (R-13).
        if s.clock.isNightOver {
            let finalScore = Scoring.finalScore(survived: true, score: s.score)
            s.score = finalScore
            events.append(.nightEnded(score: finalScore, survived: true))
            return (s, events)
        }

        // Hour boundary (R-5): pause and present two upgrade offers.
        if hourAfter > hourBefore {
            let offers = UpgradeCatalog.drawOffers(hour: hourAfter, rng: &rng)
            s.pendingOffers = offers
            s.isPaused = true
            events.append(.hourReached(hourAfter, offers: offers.map(\.id)))
            return (s, events)
        }

        // Spawn customers (R-7).
        let (spawned, spawnEvents) = Spawner.spawn(state: s, rng: &rng)
        s = spawned
        events.append(contentsOf: spawnEvents)

        // Move customers (R-8, R-11).
        let (moved, moveEvents) = Movement.moveAll(state: s, rng: &rng)
        s = moved
        events.append(contentsOf: moveEvents)

        // Service queues (R-12).
        let (served, serviceEvents) = Service.serviceAll(state: s, rng: &rng)
        s = served
        events.append(contentsOf: serviceEvents)

        // Check overflow (R-12).
        let (overflowed, overflowEvents) = Overflow.checkAll(state: s, rng: &rng)
        s = overflowed
        events.append(contentsOf: overflowEvents)

        // Score bookkeeping.
        s = Scoring.update(state: s)

        return (s, events)
    }
}

/// The P3 upgrade catalog: one offer per kind (G3 counts); the draw is
/// seeded (R-5). `Resources/Content/upgrades.json` mirrors these weights for
/// content-lint and the daily-challenge layer.
public enum UpgradeCatalog {
    public static let all: [UpgradeOffer] = [
        UpgradeOffer(id: "budget-20", kind: .extraWalkwayBudget(20)),
        UpgradeOffer(id: "lanterns-2", kind: .extraLanterns(2)),
        UpgradeOffer(id: "awning", kind: .extraAwning),
        UpgradeOffer(id: "busker", kind: .extraBusker),
        UpgradeOffer(id: "bridge", kind: .extraBridge),
        UpgradeOffer(id: "seating", kind: .extraSeating),
        UpgradeOffer(id: "cooks-20", kind: .fasterService(20)),
        UpgradeOffer(id: "queue-2", kind: .extraQueue(2)),
    ]

    /// Draw 2 distinct offers by seed.
    public static func drawOffers(hour: Int, rng: inout SeededRNG) -> [UpgradeOffer] {
        var pool = all
        rng.shuffle(&pool)
        return Array(pool.prefix(2))
    }
}
