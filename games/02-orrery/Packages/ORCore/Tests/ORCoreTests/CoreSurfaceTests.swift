/// Remaining core-surface tests: RingState convenience accessors,
/// Alignment.signedPositions, and the defensive forced-pass path (R-8).
import Testing
@testable import ORCore

@Suite("Core Surface Tests")
struct CoreSurfaceTests {

    // MARK: RingState accessors

    @Test("owner(at:) resolves the occupant of an exact angle")
    func ownerAtAngle() {
        var ring = RingState(slots: 8, offset: 0, speed: 12)
        #expect(ring.owner(at: Angle48(0)) == nil)
        ring.occupants[2] = .one          // angle 12
        #expect(ring.owner(at: Angle48(12)) == .one)
        #expect(ring.owner(at: Angle48(13)) == nil)   // not a slot angle
        ring.rotate(by: 6)
        #expect(ring.owner(at: Angle48(18)) == .one)  // rides the rotation
    }

    @Test("occupiedSlots and planetsByAngle list in canonical order")
    func accessorOrder() {
        var ring = RingState(slots: 12, offset: 0, speed: 8)
        ring.occupants = [7: .two, 2: .one, 0: .one]
        #expect(ring.occupiedSlots.map(\.slot) == [0, 2, 7])
        let byAngle = ring.planetsByAngle
        #expect(byAngle.map { $0.angle.value } == [0, 8, 28])
        #expect(byAngle[0].owner == .one)
        #expect(byAngle[1].owner == .one)
        #expect(byAngle[2].owner == .two)
    }

    // MARK: Alignment.signedPositions

    @Test("signedPositions groups by line, sorted, signed by ring (R-10)")
    func signedPositionsGrouped() {
        var state = GameStateFactory.initial(seed: 0)
        state.rings[0].occupants[0] = .one          // ring 1, a0 → line 0, +1
        state.rings[1].occupants[6] = .one          // ring 2, a24 → line 0, −2
        state.rings[3].occupants[5] = .one          // ring 4, a10 → line 10, +4 (odd angles live on ring 4 too)
        state.rings[2].occupants[4] = .two          // ring 3, a12 → line 12, +3
        let p1 = Alignment.signedPositions(of: .one, in: state)
        #expect(p1[0] == [-2, 1] as [Int])       // sorted ascending (R-10 signed values)
        #expect(p1[10] == [4] as [Int])
        #expect(p1[12] == nil)
        let p2 = Alignment.signedPositions(of: .two, in: state)
        #expect(p2[12] == [3] as [Int])
        #expect(p2[0] == nil)
    }

    // MARK: R-8 forced pass (defensive path)

    @Test("a synthetic fully-blocked position offers and accepts only pass (R-8)")
    func forcedPass() throws {
        var state = GameStateFactory.initial(seed: 0)
        // Fill every slot of a minimal synthetic layout (4 single-slot
        // rings, all occupied) so no place exists, and pin clause 2 with a
        // non-empty reserve for the mover so no nudge is legal either.
        // This state is outside real play (INV-1 does not balance) — it
        // exercises the defensive branch that future variants may reach.
        for index in state.rings.indices {
            state.rings[index].slots = 1
            state.rings[index].occupants = [0: state.toMove.opponent]
        }
        state.reserve[state.toMove] = 1                     // non-empty: clause 2 blocks nudges
        state.reserve[state.toMove.opponent] = 0
        state.nudgedLastTurn[state.toMove] = true
        let moves = LegalMoves.all(in: state)
        #expect(moves == [.pass])
        let (after, events) = try Reducer.apply(.pass, to: state)
        #expect(after.toMove == state.toMove.opponent)
        #expect(events.isEmpty)                             // a pass emits no events of its own
        #expect(LegalMoves.maxEnumerated == 68)
    }

    @Test("a pass consumes the turn and the round rotation still fires (R-8/R-7)")
    func passAdvancesRound() throws {
        var state = GameStateFactory.initial(seed: 0)
        // Two P1 planets (rings 1, 2) and two P2 planets (rings 3, 4), all
        // at angle 0 on single-slot rings — every slot occupied (no places),
        // no alignment for either player (two each on line 0), no Grand.
        for (index, owner) in [(0, PlayerID.one), (1, PlayerID.one), (2, PlayerID.two), (3, PlayerID.two)] {
            state.rings[index].slots = 1
            state.rings[index].occupants = [0: owner]
        }
        state.reserve[.one] = 1                     // non-empty: clause 2 blocks P1's nudges → forced pass
        state.reserve[.two] = 0
        state.nudgedLastTurn[.one] = true
        state.toMove = .one
        let (after, _) = try Reducer.apply(.pass, to: state)
        #expect(after.toMove == .two)
        #expect(after.turnInRound == 1)
        // P2 has reserve 0 (empty-reserve exception) and no ko memory;
        // their nudge on ring 1 completes the round and fires the rotation.
        let (afterP2, events) = try Reducer.apply(.nudge(ring: 1, dir: 1), to: after)
        #expect(afterP2.round == 2)
        #expect(events.contains(.rotated([12, 8, -3, 2])))
    }
}
