/// Victory conditions (OR-P1.4): R-15, R-16, R-17, plus GameStateHash
/// cross-checks used by INV-4.
import Testing
@testable import ORCore

@Suite("Victory Tests")
struct VictoryTests {

    private static func board(_ placements: (ring: Int, slot: Int, owner: PlayerID)...) -> GameState {
        var state = GameStateFactory.initial(seed: 0)
        for p in placements {
            state.rings[p.ring - 1].occupants[p.slot] = p.owner
        }
        state.reserve[.one] = 10 - placements.filter { $0.owner == .one }.count
        state.reserve[.two] = 10 - placements.filter { $0.owner == .two }.count
        return state
    }

    // MARK: R-15

    @Test("capturing capturesToWin planets wins (R-15)")
    func capturesWin() {
        var state = Self.board()
        state.captured[.one] = 5
        #expect(Victory.evaluate(state, variant: .standard) == .won(.one, reason: "captured 5 enemy planets"))
    }

    @Test("four captures do not win; five do (R-15 boundary)")
    func capturesBoundary() {
        var state = Self.board()
        state.captured[.one] = 4
        #expect(Victory.evaluate(state, variant: .standard) == nil)
        state.captured[.one] = 5
        #expect(Victory.evaluate(state, variant: .standard) != nil)
    }

    // MARK: R-17

    @Test("a player with no planets on board and none in reserve loses (R-17)")
    func eliminatedLoses() throws {
        var state = Self.board((1, 0, .two))      // P1 owns nothing yet
        state.reserve[.one] = 0
        #expect(Victory.evaluate(state, variant: .standard) == .won(.two, reason: "opponent has no planets left"))
        // With reserve left, the game continues.
        var alive = Self.board()
        alive.reserve[.one] = 3
        #expect(Victory.evaluate(alive, variant: .standard) == nil)
    }

    @Test("elimination by capture ends the game immediately (R-17 via reducer)")
    func eliminationByCapture() throws {
        // P1 owns exactly one planet, at +1 (ring 1 slot 0). P2 holds a
        // line-0 alignment spanning it: −4 (ring 4 a24), −3 (ring 3 a24),
        // +2 (ring 2 a0). P2 to move; any action triggers their check and
        // the capture removes P1's last planet → R-17.
        var state = GameStateFactory.initial(seed: 0)
        state.rings[0].occupants[0] = .one          // +1 (their last planet)
        state.rings[1].occupants[0] = .two          // +2
        state.rings[2].occupants[8] = .two          // a24 → −3
        state.rings[3].occupants[12] = .two         // a24 → −4
        state.captured[.two] = 0
        state.reserve[.one] = 0                     // P1 spent out: last planet in play
        state.reserve[.two] = 7
        state.toMove = .two
        let (after, events) = try Reducer.apply(.place(ring: 4, slot: 10), to: state)
        #expect(after.result != nil)
        #expect(events.contains { if case .gameOver(.two, _) = $0 { true } else { false } })
        #expect(after.rings[0].occupants[0] == nil)
        #expect((after.captured[.two] ?? 0) == 1)
    }

    // MARK: R-16

    @Test("the round limit ends the game with the on-board tie-break (R-16)")
    func roundLimitTieBreak() {
        var state = Self.board(
            (1, 0, .one), (2, 0, .one), (1, 1, .two)   // P1 2, P2 1
        )
        state.round = 21
        #expect(Victory.evaluate(state, variant: .standard) == .timeout(.one, reason: "more planets on the board after 20 rounds"))
    }

    @Test("on-board tie resolves by captures, then to Player 2 (R-16)")
    func tieBreaks() {
        var state = Self.board((1, 0, .one), (1, 1, .two))
        state.round = 21
        state.captured[.one] = 2
        state.captured[.two] = 1
        #expect(Victory.evaluate(state, variant: .standard) == .timeout(.one, reason: "more captures after the board tied"))
        var tied = Self.board((1, 0, .one), (1, 1, .two))
        tied.round = 21
        #expect(Victory.evaluate(tied, variant: .standard) == .timeout(.two, reason: "tie broken in favor of Player 2 (R-16)"))
    }

    @Test("the round limit is checked only after the round's post-rotation checks (reducer integration)")
    func roundLimitOrdering() throws {
        var state = GameStateFactory.initial(seed: 0)
        state.round = 20          // this round's completion ends the game
        state.toMove = .one
        let (afterP1, _) = try Reducer.apply(.place(ring: 1, slot: 0), to: state)
        #expect(afterP1.result == nil)             // P2 still to move in round 20
        let (afterP2, _) = try Reducer.apply(.place(ring: 1, slot: 1), to: afterP1)
        #expect(afterP2.result != nil)             // ended after the round's checks
        #expect(afterP2.round == 21)
    }

    // MARK: GameStateHash sanity (INV-4 support)

    @Test("hash distinguishes board, reserve, ko memory, and result")
    func hashDiscriminates() {
        let a = GameStateFactory.initial(seed: 0)
        var b = a
        b.rings[0].occupants[0] = .one
        var c = a
        c.nudgedLastTurn = [.one: true]
        var d = a
        d.lastNudge = .init(player: .one, ring: 1, dir: 1)
        var e = a
        e.result = .won(.one, reason: "x")
        let base = GameStateHash.digest(a)
        #expect(GameStateHash.digest(b) != base)
        #expect(GameStateHash.digest(c) != base)
        #expect(GameStateHash.digest(d) != base)
        #expect(GameStateHash.digest(e) != base)
        #expect(GameStateHash.digest(a) == base)   // stable on the same state
    }

    @Test("hash is canonical across dictionary key orders (INV-4)")
    func hashCanonical() {
        var a = GameStateFactory.initial(seed: 0)
        a.rings[1].occupants = [1: .one, 5: .two, 9: .one]
        var b = GameStateFactory.initial(seed: 0)
        b.rings[1].occupants = [9: .one, 1: .one, 5: .two]
        #expect(GameStateHash.digest(a) == GameStateHash.digest(b))
    }
}
