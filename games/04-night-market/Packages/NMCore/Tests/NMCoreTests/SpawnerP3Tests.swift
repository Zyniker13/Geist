import Testing
@testable import NMCore

/// P3: distinct zone weights bias which colors customers want, and the calm
/// first night slows the spawn ramp.
struct SpawnerP3Tests {
    @Test("equal weights reproduce the unweighted draw; biased weights change it")
    func zoneWeightsBias() throws {
        var base = GameState.initial(seed: 42)
        var biased = GameState.initial(seed: 42)
        // Jump to the last hour (rate 48) so many spawns occur in one window.
        base.clock = Clock(tick: 11 * 1800)
        biased.clock = Clock(tick: 11 * 1800)
        let openColors = base.openStalls.map(\.color)
        guard let target = openColors.first, let other = openColors.dropFirst().first(where: { $0 != target })
        else { Issue.record("expected two distinct open stall colors"); return }
        biased.zoneWeights = [target.debugName: 4]

        func tally(_ state: GameState) -> (Int, Int) {
            var s = state
            var rng = SeededRNG(seed: 5)
            for _ in 0..<1800 { s = Tick.advance(state: s, rng: &rng).0 }
            var targetCount = 0
            var otherCount = 0
            for customer in s.customers where customer.color == target || customer.color == other {
                if customer.color == target { targetCount += 1 } else { otherCount += 1 }
            }
            return (targetCount, otherCount)
        }

        let unbiased = tally(base)
        let weighted = tally(biased)
        // Unbiased: both colors drawn roughly equally; biased: target dominates.
        #expect(abs(unbiased.0 - unbiased.1) <= unbiased.0 / 2)
        #expect(weighted.0 > weighted.1 * 2)
    }

    @Test("calm first night spawns fewer customers in the same window")
    func calmSlowerRamp() throws {
        var normal = GameState.initial(seed: 42)
        var calm = GameState.initial(seed: 42)
        calm.calmFirstNight = true
        var normalRng = SeededRNG(seed: 9)
        var calmRng = SeededRNG(seed: 9)
        for _ in 0..<3600 { normal = Tick.advance(state: normal, rng: &normalRng).0 }
        for _ in 0..<3600 { calm = Tick.advance(state: calm, rng: &calmRng).0 }
        #expect(calm.customers.count < normal.customers.count)
    }

    @Test("calm applies on night one only is keyed by the flag, not the clock")
    func calmIsExplicitFlag() {
        // The flag is behavior-affecting state, hashed: flipping it flips the digest.
        var a = GameState.initial(seed: 42)
        var b = GameState.initial(seed: 42)
        b.calmFirstNight = true
        #expect(StateHash.hex(a) != StateHash.hex(b))
        a.calmFirstNight = true
        #expect(StateHash.hex(a) == StateHash.hex(b))
    }
}
