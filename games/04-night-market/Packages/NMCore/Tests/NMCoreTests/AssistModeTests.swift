/// NM-P8.2 — the assist setting: an accessibility option that lengthens the
/// overflow grace window by 50% (R-12 threshold 600 ticks → 900).
import Testing
@testable import NMCore

@Suite("Assist Mode Tests")
struct AssistModeTests {
    /// Build a night with one stalled-over-capacity queue.
    private func overloaded(assist: Bool) throws -> GameState {
        var state = try GameState.initial(seed: 42, contentVersion: "0.0.0")
        state.assistMode = assist
        // Stuff the first open stall's queue past capacity (6 + mod).
        guard let idx = state.stalls.firstIndex(where: { $0.isOpen }) else {
            Issue.record("no open stall")
            return state
        }
        for i in 0..<10 {
            state.stalls[idx].queue.append(CustomerID(900 + i))
        }
        return state
    }

    /// True when the events list ends the night.
    private static func endsNight(_ events: [Event]) -> Bool {
        events.contains { event in
            if case .nightEnded = event { return true }; return false
        }
    }

    @Test("the standard night ends at the 600-tick grace window")
    func standardGrace() throws {
        var state = try overloaded(assist: false)
        var ended = false
        for _ in 0..<620 {
            var rng = SeededRNG(seed: 1)
            let (next, events) = Overflow.checkAll(state: state, rng: &rng)
            state = next
            if Self.endsNight(events) {
                ended = true
                break
            }
        }
        #expect(ended, "600 ticks over capacity must end the night without assist")
    }

    @Test("assist lengthens the grace window by 50 percent")
    func assistGrace() throws {
        var state = try overloaded(assist: true)
        // Past the standard window the night must still be running.
        var endedEarly = false
        for _ in 0..<620 {
            var rng = SeededRNG(seed: 1)
            let (next, events) = Overflow.checkAll(state: state, rng: &rng)
            state = next
            if Self.endsNight(events) {
                endedEarly = true
                break
            }
        }
        #expect(!endedEarly, "assist must keep the night alive past the 600-tick window")
        var ended = false
        for _ in 0..<400 {
            var rng = SeededRNG(seed: 1)
            let (next, events) = Overflow.checkAll(state: state, rng: &rng)
            state = next
            if Self.endsNight(events) {
                ended = true
                break
            }
        }
        #expect(ended, "the assist grace window (900 ticks) must still end the night")
    }

    @Test("assist mode is part of the state hash")
    func assistIsHashed() throws {
        #expect(StateHash.hex(try overloaded(assist: false)) != StateHash.hex(try overloaded(assist: true)))
    }
}
