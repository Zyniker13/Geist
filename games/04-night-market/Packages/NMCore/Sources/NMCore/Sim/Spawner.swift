/// Customer spawning logic (R-7).
public enum Spawner {
    /// Hourly spawn rates (roadmap §6): customers per in-game minute.
    public static let hourlyRates: [Int] = [6, 9, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48]

    /// Spawn new customers based on the current hour's rate.
    ///
    /// One in-game hour is 1,800 ticks (R-4), so a rate of r customers per
    /// minute is r customers per 1,800 ticks: spawn on a tick when
    /// `rng.next(upperBound: 1800) < r` — exact integer math, no floats.
    public static func spawn(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        let hour = s.clock.hoursElapsed
        guard hour >= 0 else { return (s, []) }

        // Open gates only.
        let openGates = s.openGates
        guard !openGates.isEmpty else { return (s, []) }

        // Color chosen proportionally to OPEN stalls of each color times the
        // map's zone weight for that color (R-7, P3 distinct zone weights).
        // Built in canonical color order — Dictionary iteration order is
        // process-random and must never influence simulation outcomes.
        var weightedColors: [StallColor] = []
        for color in StallColor.allCases {
            let count = s.openStalls.filter { $0.color == color }.count
            let weight = s.zoneWeights[color.debugName] ?? 1
            weightedColors.append(contentsOf: Array(repeating: color, count: count * max(1, weight)))
        }
        guard !weightedColors.isEmpty else { return (s, []) }

        // Calm first night (NM-P3.4): two thirds of the normal rate, minimum 1.
        let rates = s.spawnRates.isEmpty ? hourlyRates : s.spawnRates
        guard hour < rates.count, rates[hour] > 0 else { return (s, []) }
        var rate = rates[hour]
        if s.calmFirstNight {
            rate = max(1, rate * 2 / 3)
        }
        if rng.next(upperBound: 1800) >= rate { return (s, []) }

        let color = weightedColors[Int(rng.next(upperBound: weightedColors.count))]
        let gate = openGates[Int(rng.next(upperBound: openGates.count))]

        let customer = Customer(id: s.nextCustomerID, color: color, position: GameState.center(of: gate.position))
        s.nextCustomerID += 1
        s.customers.append(customer)

        return (s, [])
    }
}
