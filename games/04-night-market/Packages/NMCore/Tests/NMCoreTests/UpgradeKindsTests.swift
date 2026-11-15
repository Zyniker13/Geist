import Testing
@testable import NMCore

/// G3: every upgrade kind has a test. The "one stall" upgrades target the
/// busiest stall (longest queue, ties by lowest id — ADR-0010).
struct UpgradeKindsTests {
    /// Builds a state with the given pending offer and queue depths.
    private func state(
        queues: [Int], stock: FixtureStock = FixtureStock(), seed: UInt64 = 42
    ) -> GameState {
        var state = GameState.initial(seed: seed)
        for (index, depth) in queues.enumerated() where index < state.stalls.count {
            for n in 0..<depth {
                state.stalls[index].queue.append(CustomerID(n + 1 + index * 100))
            }
        }
        state.fixtureStock = stock
        return state
    }

    private func choose(_ kind: UpgradeKind, id: String, on state: GameState) throws -> GameState {
        var mutable = state
        mutable.pendingOffers = [UpgradeOffer(id: id, kind: kind)]
        var rng = SeededRNG(seed: 7)
        let (next, _) = try Reducer.apply(.chooseUpgrade(id), to: mutable, rng: &rng)
        return next
    }

    @Test("budget upgrade adds walkway budget")
    func budget() throws {
        let next = try choose(.extraWalkwayBudget(20), id: "b", on: state(queues: []))
        #expect(next.walkwayBudget == 50)
    }

    @Test("lanterns upgrade grants two lantern tokens")
    func lanterns() throws {
        let next = try choose(.extraLanterns(2), id: "l", on: state(queues: []))
        #expect(next.fixtureStock.lantern == 2)
    }

    @Test("awning, busker, bridge, seating each grant one token")
    func singleTokens() throws {
        var next = try choose(.extraAwning, id: "a", on: state(queues: []))
        #expect(next.fixtureStock.awning == 1)
        next = try choose(.extraBusker, id: "b", on: state(queues: []))
        #expect(next.fixtureStock.busker == 1)
        next = try choose(.extraBridge, id: "c", on: state(queues: []))
        #expect(next.fixtureStock.bridge == 1)
        next = try choose(.extraSeating, id: "d", on: state(queues: []))
        #expect(next.fixtureStock.seating == 1)
    }

    @Test("faster cooks shortens only the busiest stall's service time")
    func fasterCooks() throws {
        // Stall 1 has the longest queue (3) → service 90 → 72 at 20%.
        let next = try choose(.fasterService(20), id: "f", on: state(queues: [1, 3, 2]))
        #expect(next.stalls[1].serviceTicks == 72)
        #expect(next.stalls[0].serviceTicks == 90)
        #expect(next.stalls[2].serviceTicks == 90)
    }

    @Test("faster cooks breaks queue ties by lowest id")
    func fasterCooksTie() throws {
        let next = try choose(.fasterService(20), id: "f", on: state(queues: [2, 2, 0]))
        #expect(next.stalls[0].serviceTicks == 72)
        #expect(next.stalls[1].serviceTicks == 90)
    }

    @Test("extra queue raises only the busiest stall's capacity")
    func extraQueue() throws {
        let next = try choose(.extraQueue(2), id: "q", on: state(queues: [0, 2, 0]))
        #expect(next.stalls[1].queueCapacityBonus == 2)
        #expect(next.stalls[0].queueCapacityBonus == 0)
        #expect(Movement.queueCapacity(for: next.stalls[1], in: next) == 8)
    }

    @Test("placement consumes a token; placement without one is rejected")
    func placementConsumesStock() throws {
        var state = state(queues: [], stock: FixtureStock(lantern: 1))
        var rng = SeededRNG(seed: 3)
        let tile = Tile(col: 12, row: 8)
        (state, _) = try Reducer.apply(.placeFixture(.lantern(radius: 3), tile), to: state, rng: &rng)
        #expect(state.fixtureStock.lantern == 0)
        #expect(state.fixtures.contains { $0.position == tile })
        #expect(throws: RuleError.self) {
            _ = try Reducer.apply(.placeFixture(.lantern(radius: 3), Tile(col: 13, row: 8)), to: state, rng: &rng)
        }
    }

    @Test("catalog covers all eight kinds")
    func catalogCoversEightKinds() {
        let kinds = Set(UpgradeCatalog.all.map(\.kind))
        #expect(kinds.count == 8)
        #expect(
            kinds.isSuperset(of: [
                UpgradeKind.extraWalkwayBudget(20), .extraLanterns(2), .extraAwning,
                .extraBusker, .extraBridge, .extraSeating, .fasterService(20), .extraQueue(2),
            ]))
    }
}
