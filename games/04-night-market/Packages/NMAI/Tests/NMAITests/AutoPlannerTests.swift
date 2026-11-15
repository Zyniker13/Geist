import Testing
@testable import NMCore
@testable import NMAI

/// NM-P4.1: the AutoPlanner only issues legal actions and plays a full
/// Taipei night end-to-end without the reducer ever throwing.
struct AutoPlannerTests {
    @Test("planner plays a full night without illegal actions")
    func fullNightNoIllegalActions() throws {
        var state = GameState.initial(seed: 42)
        var rng = SeededRNG(seed: 42)
        let planner = AutoPlanner()
        var illegal = 0
        var applied = 0
        while !state.clock.isNightOver {
            if !state.pendingOffers.isEmpty || !state.isPaused {
                if let action = planner.nextAction(for: state) {
                    do {
                        let (next, _) = try Reducer.apply(action, to: state, rng: &rng)
                        state = next
                        applied += 1
                    } catch {
                        illegal += 1
                        Issue.record("illegal action \(action): \(error)")
                        break
                    }
                }
            }
            let (next, events) = Tick.advance(state: state, rng: &rng)
            state = next
            for event in events {
                if case .hourReached = event {
                    // The reducer pauses at hour boundaries; the planner
                    // chooses on the next call (state.pendingOffers non-empty).
                }
            }
            if case .nightEnded = events.first(where: { if case .nightEnded = $0 { return true } else { return false } }) {
                break
            }
        }
        #expect(illegal == 0)
        #expect(applied > 0)
    }

    @Test("upgrade priority prefers budget over the rest")
    func upgradePriority() {
        var state = GameState.initial(seed: 7)
        state.pendingOffers = [
            UpgradeOffer(id: "q", kind: .extraQueue(2)),
            UpgradeOffer(id: "b", kind: .extraWalkwayBudget(20)),
        ]
        let planner = AutoPlanner()
        guard case .chooseUpgrade(let id) = planner.nextAction(for: state) else {
            Issue.record("expected an upgrade choice")
            return
        }
        #expect(id == "b")
    }

    @Test("shortest path BFS finds a straight corridor")
    func shortestPath() {
        let state = GameState.initial(seed: 42)
        let network = AutoPlanner.networkTiles(state)
        #expect(!network.isEmpty)
        let start = Tile(col: 6, row: 9)
        let path = AutoPlanner.shortestPath(from: start, to: network, in: state)
        #expect(path != nil)
    }
}
