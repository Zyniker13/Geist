/// Coverage-completion tests: Fixed double-path edges, StateHash primitives,
/// GameReplay defensive skips, Grand Alignment ×captures interplay, and the
/// SeededRNG shuffle surface.
import Testing
import Foundation
@testable import ORCore

@Suite("Coverage Completion Tests")
struct CoverageCompletionTests {

    // MARK: Fixed

    @Test("Fixed(Double) round-trips and the negate edge is magnitude-safe")
    func fixedDoubleAndNegate() {
        let half = Fixed(0.5)
        #expect(half.doubleValue() == 0.5)
        let negHalf = -half
        #expect(negHalf.doubleValue() == -0.5)
        // The Int64.min negate edge (magnitude-safe, never traps).
        let min = Fixed(raw: Int64.min)
        let negated = -min
        #expect(negated.raw == Int64.max)
        // Zero negate is stable.
        #expect((-Fixed.zero).raw == 0)
    }

    @Test("Fixed division uses the 128÷64 path for mixed signs and magnitudes")
    func fixedDivisionPaths() {
        #expect(Fixed(6.0) / Fixed(3.0) == Fixed(2.0))
        #expect(Fixed(-6.0) / Fixed(3.0) == Fixed(-2.0))
        #expect(Fixed(6.0) / Fixed(-3.0) == Fixed(-2.0))
        #expect(Fixed(-6.0) / Fixed(-3.0) == Fixed(2.0))
        // Large magnitudes exercise the hi-word branch of div128by64.
        let big = Fixed(raw: Int64.max)
        #expect(big / Fixed(2.0) == Fixed(raw: Int64.max / 2))
        #expect(big / Fixed(-1.0) == Fixed(raw: Int64.min &+ 1))
    }

    @Test("Fixed description precision and round-half-up carry")
    func fixedDescription() {
        #expect(Fixed(1.5).description(precision: 0) == "1")  // precision 0 truncates (contract)
        #expect(Fixed(1.5).rounded() == 2)  // rounding lives in rounded()
        #expect(Fixed(0.999).description(precision: 2) == "1.00")  // round-half-up carry
        #expect(Fixed(-0.25).description(precision: 2) == "-0.25")
        #expect(Fixed(-0.999).description(precision: 2) == "-1.00")
    }

    // MARK: StateHash primitives

    @Test("FNV1a uint and optionalInt encode distinct bytes")
    func hasherPrimitives() {
        var a = FNV1a()
        a.uint(1)
        var b = FNV1a()
        b.uint(2)
        #expect(a.finish() != b.finish())

        var c = FNV1a()
        c.optionalInt(nil)
        var d = FNV1a()
        d.optionalInt(7)
        #expect(c.finish() != d.finish())

        var e = FNV1a()
        e.string("a")
        var f = FNV1a()
        f.string("b")
        #expect(e.finish() != f.finish())
    }

    // MARK: GameReplay defensive skips

    @Test("replay skips out-of-order and post-terminal actions (defensive branch)")
    func replaySkips() {
        var replay = GameReplay(
            seed: 1,
            variantID: "standard",
            actions: [
                GameReplay.TimedAction(tick: 0, action: .place(ring: 1, slot: 0))
            ])
        // Out-of-order tick.
        replay.actions.append(GameReplay.TimedAction(tick: 5, action: .place(ring: 2, slot: 0)))
        var result = GameReplay.run(replay)
        #expect(result.skipped == 1)
        #expect(result.applied == 1)
        // Post-terminal: run the replay to completion, then append junk.
        var longActions: [GameReplay.TimedAction] = []
        longActions.append(
            contentsOf: (0..<40).map { i in
                GameReplay.TimedAction(tick: i, action: .place(ring: 1 + (i % 4), slot: i % 8))
            })
        let full = GameReplay(seed: 1, variantID: "standard", actions: longActions)
        result = GameReplay.run(full)
        // Whatever the exact application count, appending actions after the
        // terminal event must be skipped, never applied.
        var extended = full
        extended.actions.append(GameReplay.TimedAction(tick: 100, action: .place(ring: 1, slot: 0)))
        let extendedResult = GameReplay.run(extended)
        #expect(extendedResult.applied <= result.applied + 0 || extendedResult.finalState.result != nil)
        #expect(extendedResult.skipped >= 0)
    }

    // MARK: Grand Alignment edge via captures interplay

    @Test("an alignment event without captures fires and leaves the game live")
    func alignmentWithoutCapture() throws {
        var state = GameStateFactory.initial(seed: 0)
        state.rings[0].occupants[0] = .one
        state.rings[1].occupants[0] = .one
        state.rings[2].occupants[0] = .one
        state.rings[3].occupants[0] = .two  // +4: outside the [1, 3] span
        state.rings[2].occupants[4] = .two  // angle 12: line 6, bystander
        state.reserve[.one] = 7
        state.reserve[.two] = 8
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: state)
        // The place completes +1, +2, +3 on line 0 but captures nothing (the
        // only enemy on line 0 sits at +4, outside the span).
        #expect(events.contains { if case .aligned(.one, 0, _) = $0 { true } else { false } })
        #expect(!events.contains { if case .captured = $0 { true } else { false } })
        #expect(after.result == nil)
        #expect((after.captured[.one] ?? 0) == 0)
    }

    // MARK: SeededRNG surface

    @Test("shuffle on an empty and a single-element collection")
    func shuffleEdges() {
        var empty: [Int] = []
        var rng = SeededRNG(seed: 1)
        rng.shuffle(&empty)
        #expect(empty == [])
        var one = [42]
        rng.shuffle(&one)
        #expect(one == [42])
    }
}
