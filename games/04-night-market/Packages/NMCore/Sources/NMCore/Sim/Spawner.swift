/// Customer spawning logic.
public enum Spawner {
    /// Spawn new customers based on the current hour's rate.
    public static func spawn(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        let hour = s.clock.hoursElapsed

        // spawnRate per hour (from roadmap §6): 6, 9, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48
        let spawnRates: [Int] = [6, 9, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48]
        guard hour < spawnRates.count else { return (s, []) }

        let ratePerTick = Double(spawnRates[hour]) / 60.0  // per second, 1 tick = 1/30s
        let spawnChance = ratePerTick / 30.0  // probability per tick

        guard rng.nextDouble() < spawnChance else { return (s, []) }

        // Choose color proportional to open stalls
        let openColors = s.stalls.filter { $0.isOpen }.map { $0.color }
        guard !openColors.isEmpty else { return (s, []) }

        let color = rng.randomElement(from: openColors) ?? .noodles

        // Pick a random open gate
        let openGates = s.gates.filter { $0.isOpen }
        guard !openGates.isEmpty else { return (s, []) }
        let gate = rng.randomElement(from: openGates) ?? openGates.first!

        let pos = FixedPoint2(
            x: Int32(gate.position.col) * 1024,
            y: Int32(gate.position.row) * 1024
        )

        let customer = Customer(
            id: s.nextCustomerID,
            color: color,
            position: pos
        )
        s.nextCustomerID += 1
        s.customers.append(customer)

        return (s, [])
    }
}
