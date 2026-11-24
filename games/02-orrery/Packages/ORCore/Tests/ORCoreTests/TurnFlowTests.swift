/// Turn-flow tests (OR-P1.2): R-4, R-5, R-6, R-8.
import Testing
@testable import ORCore

@Suite("Turn Flow Tests")
struct TurnFlowTests {

    // MARK: R-4 / initial state

    @Test("initial state: 10 planets in reserve each, player 1 moves first, empty rings at offset 0 (R-4)")
    func initialState() {
        let state = GameStateFactory.initial(seed: 42)
        #expect(state.reserve[.one] == 10)
        #expect(state.reserve[.two] == 10)
        #expect(state.toMove == .one)
        #expect(state.round == 1)
        #expect(state.turnInRound == 0)
        #expect(state.lastNudge == nil)
        #expect(state.planetsOnBoard(.one) == 0)
        #expect(state.planetsOnBoard(.two) == 0)
        for ring in state.rings {
            #expect(ring.offset == 0)
            #expect(ring.occupants.isEmpty)
        }
    }

    // MARK: R-5 place

    @Test("place consumes reserve, occupies the slot, and passes the turn (R-5)")
    func placeBasics() throws {
        var state = GameStateFactory.initial(seed: 1)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 0), to: state)
        #expect(after.reserve[.one] == 9)
        #expect(after.rings[0].occupants[0] == .one)
        #expect(after.toMove == .two)
        #expect(after.turnInRound == 1)
        #expect(events.contains(.placed(.one, ring: 1, slot: 0)))
        state = after
    }

    @Test("placing into an occupied slot is illegal (INV-1)")
    func placeOccupied() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.place(ring: 2, slot: 3), to: state).0
        #expect(throws: RuleError.slotOccupied(ring: 2, slot: 3)) {
            _ = try Reducer.apply(.place(ring: 2, slot: 3), to: state)
        }
    }

    @Test("placing into an out-of-range slot is illegal")
    func placeOutOfRange() {
        let state = GameStateFactory.initial(seed: 1)
        #expect(throws: RuleError.slotOutOfRange(ring: 1, slot: 8)) {
            _ = try Reducer.apply(.place(ring: 1, slot: 8), to: state)
        }
        #expect(throws: RuleError.slotOutOfRange(ring: 1, slot: -1)) {
            _ = try Reducer.apply(.place(ring: 1, slot: -1), to: state)
        }
        #expect(throws: RuleError.unknownRing(5)) {
            _ = try Reducer.apply(.place(ring: 5, slot: 0), to: state)
        }
    }

    @Test("placing with an empty reserve is illegal (R-5)")
    func placeEmptyReserve() {
        var state = GameStateFactory.initial(seed: 1)
        state.reserve[.one] = 0
        #expect(throws: RuleError.reserveEmpty(.one)) {
            _ = try Reducer.apply(.place(ring: 1, slot: 0), to: state)
        }
    }

    @Test("acting on a finished game is illegal")
    func gameOver() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.place(ring: 1, slot: 0), to: state).0
        state = try Reducer.apply(.place(ring: 1, slot: 1), to: state).0
        state.result = .won(.one, reason: "test")
        #expect(throws: RuleError.gameAlreadyOver) {
            _ = try Reducer.apply(.place(ring: 1, slot: 2), to: state)
        }
        #expect(LegalMoves.all(in: state).isEmpty)
    }

    // MARK: R-5 nudge

    @Test("nudge rotates the ring one slot step and passes the turn (R-5)")
    func nudgeBasics() throws {
        var state = GameStateFactory.initial(seed: 1)
        let (after, events) = try Reducer.apply(.nudge(ring: 1, dir: 1), to: state)
        #expect(after.rings[0].offset == 6)  // step of an 8-slot ring
        #expect(after.lastNudge == GameState.Nudge(player: .one, ring: 1, dir: 1))
        #expect(events.contains(.nudged(ring: 1, dir: 1)))
        state = after
    }

    @Test("nudge with dir 0 or 2 is illegal")
    func nudgeBadDir() {
        let state = GameStateFactory.initial(seed: 1)
        #expect(throws: RuleError.unknownRing(1)) {
            _ = try Reducer.apply(.nudge(ring: 1, dir: 0), to: state)
        }
        #expect(throws: RuleError.unknownRing(1)) {
            _ = try Reducer.apply(.nudge(ring: 1, dir: 2), to: state)
        }
    }

    // MARK: R-6 ko

    @Test("immediate undo: may not nudge the opponent's just-nudged ring the opposite way (R-6)")
    func koImmediateUndo() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.place(ring: 1, slot: 0), to: state).0   // P1 places
        // P2 nudges ring 3 +; the round ends, rotation fires.
        state = try Reducer.apply(.nudge(ring: 3, dir: 1), to: state).0
        // Round 2, P1 to move: the ko binds (survives the rotation, which is
        // not a turn), and P1's own last action was a place, so clause 2 is
        // clear — the rejection is purely clause 1.
        #expect(throws: RuleError.nudgeKo(ring: 3, dir: -1)) {
            _ = try Reducer.apply(.nudge(ring: 3, dir: -1), to: state)
        }
        // Same direction is legal (undo loop needs the reversal).
        let (after, events) = try Reducer.apply(.nudge(ring: 3, dir: 1), to: state)
        #expect(after.rings[2].offset == 3)
        #expect(events.contains(.nudged(ring: 3, dir: 1)))
    }

    @Test("ko binds only the immediately following turn: an intervening place expires it (R-6)")
    func koExpiresAfterInterveningAction() throws {
        var state = GameStateFactory.initial(seed: 1)
        // P1 nudges ring 2 +.
        state = try Reducer.apply(.nudge(ring: 2, dir: 1), to: state).0
        // P2's next turn is a place; the ko memory expires.
        state = try Reducer.apply(.place(ring: 1, slot: 0), to: state).0
        // P1 places; clause 2 clears too.
        state = try Reducer.apply(.place(ring: 3, slot: 2), to: state).0
        // P2 answers on ring 2, opposite direction: no ko (memory expired),
        // and P2's own last action was a place, so clause 2 is clear.
        let (_, events) = try Reducer.apply(.nudge(ring: 2, dir: -1), to: state)
        #expect(events.contains(.nudged(ring: 2, dir: -1)))
    }

    @Test("opponent same-direction nudge is never ko (R-6)")
    func koSameDirectionAllowed() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.nudge(ring: 4, dir: 1), to: state).0
        let (_, events) = try Reducer.apply(.nudge(ring: 4, dir: 1), to: state)
        #expect(events.contains(.nudged(ring: 4, dir: 1)))
    }

    @Test("nudging a different ring than the ko ring is legal (R-6)")
    func koOtherRingAllowed() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.nudge(ring: 2, dir: 1), to: state).0
        let (_, events) = try Reducer.apply(.nudge(ring: 3, dir: -1), to: state)
        #expect(events.contains(.nudged(ring: 3, dir: -1)))
    }

    @Test("may not nudge on two consecutive own turns with reserve left (R-6 clause 2)")
    func noTwoNudgesInARow() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.nudge(ring: 1, dir: 1), to: state).0  // P1 nudge
        state = try Reducer.apply(.place(ring: 2, slot: 0), to: state).0  // P2 place
        // P1's turn again: their own last action was a nudge and they still
        // hold reserve, so another nudge is illegal — the intervening
        // opponent move does NOT reset the clause.
        #expect(throws: RuleError.nudgeTwoTurnsInARow) {
            _ = try Reducer.apply(.nudge(ring: 2, dir: 1), to: state)
        }
        // But a place is legal, and after it the clause clears.
        state = try Reducer.apply(.place(ring: 2, slot: 1), to: state).0
        let (_, events) = try Reducer.apply(.nudge(ring: 3, dir: 1), to: state)
        #expect(events.contains(.nudged(ring: 3, dir: 1)))
    }

    @Test("may nudge on consecutive own turns once reserve is empty (R-6 exception)")
    func twoNudgesAllowedWithEmptyReserve() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.place(ring: 1, slot: 0), to: state).0  // P1 on board
        state = try Reducer.apply(.place(ring: 1, slot: 1), to: state).0  // P2 on board
        state.reserve[.one] = 0  // spent out (board not empty)
        state = try Reducer.apply(.nudge(ring: 1, dir: 1), to: state).0
        state = try Reducer.apply(.place(ring: 2, slot: 0), to: state).0  // P2 places
        let (_, events) = try Reducer.apply(.nudge(ring: 2, dir: 1), to: state)
        #expect(events.contains(.nudged(ring: 2, dir: 1)))
    }

    @Test("the ko survives the end-of-round rotation: R-6 binds turns, not rounds")
    func koSurvivesRotation() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.place(ring: 1, slot: 0), to: state).0  // P1 places
        // P2 nudges ring 3 +; the round ends, rotation fires.
        state = try Reducer.apply(.nudge(ring: 3, dir: 1), to: state).0
        // Round 2, P1 to move. The rotation is not a turn: ring 3 − is still
        // ko (immediate undo of P2's nudge).
        #expect(throws: RuleError.nudgeKo(ring: 3, dir: -1)) {
            _ = try Reducer.apply(.nudge(ring: 3, dir: -1), to: state)
        }
        // Ring 3 + is legal (same direction), other rings are legal.
        let (_, events) = try Reducer.apply(.nudge(ring: 3, dir: 1), to: state)
        #expect(events.contains(.nudged(ring: 3, dir: 1)))
    }

    @Test("two own nudges across a round boundary are consecutive own turns (R-6 clause 2)")
    func twoNudgesAcrossRoundBoundary() throws {
        var state = GameStateFactory.initial(seed: 1)
        state = try Reducer.apply(.nudge(ring: 1, dir: 1), to: state).0  // P1 nudge (turn 0)
        state = try Reducer.apply(.nudge(ring: 2, dir: -1), to: state).0  // P2 nudge — rotation fires
        // Round 2, P1's turn: their own last action was a nudge and they hold
        // reserve — still illegal even though a round turned in between.
        #expect(throws: RuleError.nudgeTwoTurnsInARow) {
            _ = try Reducer.apply(.nudge(ring: 1, dir: -1), to: state)
        }
    }

    // MARK: R-8 pass

    @Test("pass is illegal while any other action exists (R-8)")
    func passIllegalOtherwise() {
        let state = GameStateFactory.initial(seed: 1)
        #expect(throws: RuleError.illegalPass) {
            _ = try Reducer.apply(.pass, to: state)
        }
    }

    @Test("LegalMoves never offers pass while a place or nudge exists (R-8)")
    func legalMovesNoPassEarly() {
        let state = GameStateFactory.initial(seed: 1)
        let moves = LegalMoves.all(in: state)
        #expect(!moves.contains(.pass))
        #expect(!moves.isEmpty)
    }

    @Test("LegalMoves and the reducer agree exactly on legality (both directions)")
    func legalMovesAllAcceptable() throws {
        var state = GameStateFactory.initial(seed: 1)
        // Play a scripted mid-game with mixed ko state, ending with the
        // mover's own last action a nudge, then check the legal set both ways.
        let script: [Action] = [
            .nudge(ring: 1, dir: 1),  // P1
            .place(ring: 2, slot: 0),  // P2
            .place(ring: 3, slot: 2),  // P1 (clause 2 clears for P1)
            .nudge(ring: 4, dir: -1),  // P2 — round 1 ends, rotation fires
            .nudge(ring: 1, dir: -1),  // P1 (ring ≠ ko ring; own last was a place)
            .place(ring: 2, slot: 4),  // P2 — round 2 ends, rotation fires
        ]
        for action in script {
            state = try Reducer.apply(action, to: state).0
        }
        // Round 3, player 1 to move, own last action was a nudge, reserve
        // non-empty: the legal set is places only, every nudge rejected.
        let moves = LegalMoves.all(in: state)
        #expect(!moves.isEmpty)
        #expect(!moves.contains { if case .nudge = $0 { true } else { false } })
        for move in moves {
            _ = try Reducer.apply(move, to: state)
        }
        // And the converse: every nudge NOT offered must be rejected.
        for ring in 1...4 {
            for dir in [-1, 1] where !moves.contains(.nudge(ring: ring, dir: dir)) {
                #expect(throws: Error.self) {
                    _ = try Reducer.apply(.nudge(ring: ring, dir: dir), to: state)
                }
            }
        }
    }
}
