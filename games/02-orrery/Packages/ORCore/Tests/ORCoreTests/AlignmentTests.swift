/// Alignment, capture, and Grand Alignment (OR-P1.3): R-9…R-14.
///
/// Hand-built positions (25 enumerated in comments, several tests carry
/// extra sub-positions): every board is built by placing planets at exact
/// *angles* through `placeAt`, so the geometry reads directly. Rotation
/// effects are asserted through full reducer plays where R-13b applies.
import Testing
@testable import ORCore

@Suite("Alignment Tests")
struct AlignmentTests {

    /// Place a planet of `owner` on `ring` (1-based) at the exact angle
    /// `angle` (mod 48), given the ring's current offset. Requires the
    /// angle to land on a slot of that ring.
    private static func placeAt(_ state: inout GameState, ring: Int, angle: Int, _ owner: PlayerID) {
        let r = state.rings[ring - 1]
        let relative = ((angle - r.offset) % 48 + 48) % 48
        precondition(r.slotStep > 0 && relative % r.slotStep == 0, "angle \(angle) not on ring \(ring)")
        let slot = relative / r.slotStep
        precondition(r.occupants[slot] == nil, "slot occupied")
        state.rings[ring - 1].occupants[slot] = owner
    }

    /// A board with planets at exact angles on Standard rings at offset 0.
    private static func board(
        _ placements: (ring: Int, angle: Int, owner: PlayerID)...,
        toMove: PlayerID = .one
    ) -> GameState {
        var state = GameStateFactory.initial(seed: 0)
        for p in placements {
            Self.placeAt(&state, ring: p.ring, angle: p.angle, p.owner)
        }
        state.toMove = toMove
        return state
    }

    // MARK: R-9/R-10 line geometry

    @Test("line index maps angle a to its unordered pair index (R-9)")
    func lineGeometry() {
        #expect(Angle48(0).lineIndex == 0)
        #expect(Angle48(24).lineIndex == 0)
        #expect(Angle48(30).lineIndex == 6)  // pair {6, 30}
        #expect(Angle48(6).lineIndex == 6)
        #expect(Angle48(47).lineIndex == 23)  // pair {23, 47}
    }

    @Test("signed position is +ring at angle a, −ring at angle a+24 (R-10)")
    func signedPositions() {
        let state = Self.board((1, 0, .one), (2, 24, .one), (3, 0, .two), (4, 24, .two))
        let p1 = state.planets(of: .one)
        #expect(state.angle(of: p1[0]).lineSign * p1[0].ring == 1)  // +1
        #expect(state.angle(of: p1[1]).lineSign * p1[1].ring == -2)  // −2
        let p2 = state.planets(of: .two)
        #expect(state.angle(of: p2[0]).lineSign * p2[0].ring == 3)  // +3
        #expect(state.angle(of: p2[1]).lineSign * p2[1].ring == -4)  // −4
    }

    // MARK: R-11 alignment threshold

    @Test("alignment requires three or more planets on one line (R-11)")
    func threshold() {
        let two = Self.board((1, 0, .one), (3, 0, .one))
        #expect(Alignment.alignments(for: .one, in: two).isEmpty)

        let three = Self.board((1, 0, .one), (3, 0, .one), (4, 24, .one))
        let found = Alignment.alignments(for: .one, in: three)
        #expect(found.count == 1)
        #expect(found[0].line == 0)
        #expect(found[0].planets.count == 3)

        let mixed = Self.board((1, 0, .one), (2, 24, .one), (4, 24, .one))
        #expect(Alignment.alignments(for: .one, in: mixed).count == 1)
    }

    // MARK: R-12 capture span

    @Test("capture: enemy strictly between min and max signed position (R-12)")
    func captureStrictlyBetween() {
        // P1 +1, +2, +4 on line 0; enemy at +3 captured, enemy at −3 outside.
        let state = Self.board(
            (1, 0, .one), (2, 0, .one), (4, 0, .one),
            (3, 0, .two), (3, 24, .two)
        )
        let captured = Alignment.captures(for: .one, in: state)
        #expect(captured.map { [$0.ring, $0.slot] } == [[3, 0]])
    }

    @Test("capture across the sun: a span from −4 to +1 takes both sides (R-12/R-10)")
    func captureAcrossSun() {
        // P1 at −4, −2, +1. Enemy at −3 and −1 inside; +4 outside.
        let state = Self.board(
            (4, 24, .one), (2, 24, .one), (1, 0, .one),
            (3, 24, .two), (1, 24, .two),
            (4, 0, .two)
        )
        let captured = Alignment.captures(for: .one, in: state)
        #expect(captured.map { [$0.ring, $0.slot] } == [[1, 4], [3, 8]])
    }

    @Test("an enemy exactly at an aligned position cannot exist (INV-1); the outside case pins strictness")
    func endpointSharingImpossible() {
        // P1 +1, +2, +3; enemy at +4 is outside the span [1, 3].
        let state = Self.board(
            (1, 0, .one), (2, 0, .one), (3, 0, .one),
            (4, 0, .two)
        )
        #expect(Alignment.captures(for: .one, in: state).isEmpty)
    }

    @Test("capture uses the opponent's planets on the SAME line only")
    func captureSameLineOnly() {
        // P1 aligned on line 0; enemies on line 12 (angle 12 sits on both
        // ring 2 and ring 3 slot grids) untouched.
        let state = Self.board(
            (1, 0, .one), (2, 0, .one), (4, 0, .one),
            (3, 12, .two), (2, 12, .two)
        )
        #expect(Alignment.captures(for: .one, in: state).isEmpty)
    }

    @Test("enemy inside the span on the opposite ray is captured (R-10 sign span)")
    func captureOppositeRayInside() {
        // P1 at −1, −2, +3; enemy at +1 strictly inside [−2, +3].
        let state = Self.board(
            (1, 24, .one), (2, 24, .one), (3, 0, .one),
            (1, 0, .two)
        )
        #expect(Alignment.captures(for: .one, in: state).map { [$0.ring, $0.slot] } == [[1, 0]])
    }

    @Test("two aligned planets on different lines never combine (R-11 per-line)")
    func perLineIsolation() {
        // P1 has +1, +2 on line 0 and +3 on line 12 — no line holds three.
        let state = Self.board(
            (1, 0, .one), (2, 0, .one),
            (3, 12, .one)
        )
        #expect(Alignment.alignments(for: .one, in: state).isEmpty)
        #expect(Alignment.captures(for: .one, in: state).isEmpty)
    }

    // MARK: R-13a action-time checks

    @Test("R-13a: the acting player's new alignment captures immediately, with events")
    func captureOnPlace() throws {
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 0, .one)
        Self.placeAt(&state, ring: 2, angle: 0, .one)
        Self.placeAt(&state, ring: 3, angle: 0, .two)  // +3: inside the span [1, 4]
        Self.placeAt(&state, ring: 3, angle: 12, .two)  // angle 12 → line 6: untouched
        state.reserve[.one] = 8
        state.reserve[.two] = 9
        state.toMove = .one
        // P1 places ring 4 slot 0 (angle 0 → +4): span [1, 4] captures +3.
        let (after, events) = try Reducer.apply(.place(ring: 4, slot: 0), to: state)
        #expect((after.captured[.one] ?? 0) == 1)
        #expect(
            events.contains(
                .aligned(
                    .one, line: 0,
                    planets: [
                        PlanetRef(ring: 1, slot: 0, owner: .one),
                        PlanetRef(ring: 2, slot: 0, owner: .one),
                        PlanetRef(ring: 4, slot: 0, owner: .one),
                    ])))
        #expect(events.contains(.captured(.one, planets: [PlanetRef(ring: 3, slot: 0, owner: .two)])))
        #expect(after.rings[2].occupants[4] == .two)  // the line-6 enemy untouched
    }

    @Test("R-13a: only the acting player is checked for alignments")
    func onlyActingPlayerChecked() throws {
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 0, .two)
        Self.placeAt(&state, ring: 2, angle: 0, .two)
        Self.placeAt(&state, ring: 3, angle: 0, .two)
        Self.placeAt(&state, ring: 4, angle: 6, .one)
        state.toMove = .one
        let (after, events) = try Reducer.apply(.nudge(ring: 4, dir: 1), to: state)
        #expect((after.captured[.one] ?? 0) == 0)
        #expect(after.rings[0].occupants[0] == .two)  // P2's alignment untouched
        #expect(!events.contains { if case .aligned(.two, _, _) = $0 { true } else { false } })
    }

    @Test("R-13a: a capture that reaches capturesToWin ends the game (R-15)")
    func captureCanEndGame() throws {
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 0, .one)  // +1
        Self.placeAt(&state, ring: 2, angle: 0, .one)  // +2
        Self.placeAt(&state, ring: 3, angle: 0, .two)  // +3: captured by the span [1, 4]
        state.captured[.one] = 4
        state.captured[.two] = 0
        state.reserve[.one] = 8
        state.reserve[.two] = 9
        let (after, events) = try Reducer.apply(.place(ring: 4, slot: 0), to: state)
        #expect(after.result != nil)
        #expect(events.contains { if case .gameOver(.one, _) = $0 { true } else { false } })
    }

    // MARK: R-13b post-rotation checks

    @Test("R-13b: post-rotation alignment captures before the opponent's check — sequencing pinned")
    func postRotationSequencing() throws {
        // Pre-round (offsets 0) angles chosen so the post-rotation offsets
        // (+12, +8, −3, +2) put P1 on line 0 at +1, −2, +3, +4 and P2 on
        // line 0 at −1 (ring1 a12), +2 (ring2 a40 → post 48≡0), −4 (ring4
        // a22 → post 24). P1's span [−2, +4] captures −1 and +2; P2 is left
        // with −4 alone → no P2 alignment.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .one)  // post a0 → +1
        Self.placeAt(&state, ring: 2, angle: 16, .one)  // post a24 → −2
        Self.placeAt(&state, ring: 3, angle: 3, .one)  // post a0 → +3
        Self.placeAt(&state, ring: 4, angle: 46, .one)  // post a0 → +4
        Self.placeAt(&state, ring: 1, angle: 12, .two)  // post a24 → −1
        Self.placeAt(&state, ring: 2, angle: 40, .two)  // post a0 → +2
        Self.placeAt(&state, ring: 4, angle: 22, .two)  // post a24 → −4
        #expect(Alignment.alignments(for: .one, in: state).isEmpty)  // pre-round: scattered
        #expect(Alignment.alignments(for: .two, in: state).isEmpty)
        state.toMove = .one
        let (first, _) = try Reducer.apply(.place(ring: 4, slot: 6), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: first)
        #expect(after.round == 2)
        #expect((after.captured[.one] ?? 0) == 2)
        #expect(events.contains { if case .aligned(.one, 0, _) = $0 { true } else { false } })
        #expect(
            events.contains { if case .captured(.one, let planets) = $0, planets.count == 2 { true } else { false } })
        #expect(!events.contains { if case .aligned(.two, _, _) = $0 { true } else { false } })
        #expect(after.rings[0].occupants[2] == nil)  // (1, a12 → slot 2) captured
        #expect(after.rings[1].occupants[10] == nil)  // (2, a40 → slot 10) captured
    }

    @Test("R-13b: simultaneous post-rotation alignments — both fire, mover's first")
    func postRotationSimultaneous() throws {
        // P1 post-rotation line 0: ring1 a36→a0 +1, ring2 a40→a0 +2,
        // ring3 a3→a0 +3. P2 post-rotation line 6: ring1 a42→a6 +1,
        // ring3 a9→a6 +3, ring4 a4→a6 +4. No enemies on either line →
        // both alignments fire with zero captures.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .one)
        Self.placeAt(&state, ring: 2, angle: 40, .one)
        Self.placeAt(&state, ring: 3, angle: 3, .one)
        Self.placeAt(&state, ring: 1, angle: 42, .two)
        Self.placeAt(&state, ring: 3, angle: 9, .two)
        Self.placeAt(&state, ring: 4, angle: 4, .two)
        #expect(Alignment.alignments(for: .one, in: state).isEmpty)
        #expect(Alignment.alignments(for: .two, in: state).isEmpty)
        state.toMove = .one
        let (first, _) = try Reducer.apply(.place(ring: 4, slot: 0), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: first)
        let alignedEvents = events.filter { if case .aligned = $0 { true } else { false } }
        #expect(alignedEvents.count == 2)
        guard case .aligned(.one, 0, _)? = alignedEvents.first else {
            Issue.record("P1's alignment must be checked first (R-13b)")
            return
        }
        guard case .aligned(.two, 6, _)? = alignedEvents.last else {
            Issue.record("P2's line-6 alignment must fire second")
            return
        }
        #expect((after.captured[.one] ?? 0) == 0)
        #expect((after.captured[.two] ?? 0) == 0)
    }

    @Test("R-13b: the second player's intact alignment still fires after the mover's empty check")
    func postRotationOtherPlayerStillChecked() throws {
        // P1 has only +1, +2 on line 0 post-rotation (no alignment); P2
        // holds a full line-6 alignment → fires second, game continues.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .one)
        Self.placeAt(&state, ring: 2, angle: 40, .one)
        Self.placeAt(&state, ring: 1, angle: 42, .two)
        Self.placeAt(&state, ring: 3, angle: 9, .two)
        Self.placeAt(&state, ring: 4, angle: 4, .two)
        state.toMove = .one
        let (first, _) = try Reducer.apply(.place(ring: 3, slot: 0), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: first)
        let alignedEvents = events.filter { if case .aligned = $0 { true } else { false } }
        #expect(alignedEvents.count == 1)
        guard case .aligned(.two, 6, _)? = alignedEvents.first else {
            Issue.record("P2's alignment should be the only one")
            return
        }
        #expect(after.result == nil)
    }

    // MARK: R-14 Grand Alignment

    @Test("R-14: one planet per ring on the same angle wins immediately")
    func grandAlignmentWins() throws {
        let state = Self.board((1, 0, .one), (2, 0, .one), (3, 0, .one), (4, 0, .one), toMove: .one)
        #expect(Alignment.grandAlignment(for: .one, in: state))
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: state)
        #expect(after.result == .won(.one, reason: "Grand Alignment"))
        #expect(events.contains(.grandAlignment(.one)))
        #expect(events.contains { if case .gameOver(.one, "Grand Alignment") = $0 { true } else { false } })
    }

    @Test("R-14: opposite sides of the same line are not one ray")
    func grandAlignmentNeedsSameRay() {
        let split = Self.board((1, 0, .one), (2, 0, .one), (3, 24, .one), (4, 24, .one))
        #expect(!Alignment.grandAlignment(for: .one, in: split))
        let same24 = Self.board((1, 24, .one), (2, 24, .one), (3, 24, .one), (4, 24, .one))
        #expect(Alignment.grandAlignment(for: .one, in: same24))
    }

    @Test("R-14: Grand Alignment is checked before the opponent's captures (R-13b order)")
    func grandAlignmentBeforeCaptures() throws {
        // Post-rotation: P1 holds all four rings at angle 0 (Grand) AND a
        // lone planet at (3, slot 3) → post a6, +3 on line 6. P2 holds a
        // line-6 alignment (rings 1, 3, 4 at a6: span [+1, +4]) that would
        // capture P1's +3 if P2's check ran first. P1's Grand check runs
        // first (mover) → P1 wins, no captures, the +3 planet survives.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .one)  // post a0
        Self.placeAt(&state, ring: 2, angle: 40, .one)  // post a0
        Self.placeAt(&state, ring: 3, angle: 3, .one)  // post a0
        Self.placeAt(&state, ring: 4, angle: 46, .one)  // post a0
        Self.placeAt(&state, ring: 3, angle: 9, .one)  // post a6 → +3 (the sacrificial planet)
        Self.placeAt(&state, ring: 1, angle: 42, .two)  // post a6 → +1
        Self.placeAt(&state, ring: 3, angle: 33, .two)  // slot 11 → post a30 → −3 on line 6
        Self.placeAt(&state, ring: 4, angle: 4, .two)  // post a6 → +4
        #expect(!Alignment.grandAlignment(for: .one, in: state))
        #expect(Alignment.alignments(for: .two, in: state).isEmpty)  // pre-round: scattered
        state.reserve[.one] = 8
        state.reserve[.two] = 9
        state.toMove = .one
        // P1 places harmlessly (ring 1 slot 2 → a12), P2 answers, round ends.
        let (p1Move, _) = try Reducer.apply(.place(ring: 1, slot: 2), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 4, slot: 10), to: p1Move)
        #expect(after.result == .won(.one, reason: "Grand Alignment"))
        #expect(!events.contains { if case .captured = $0 { true } else { false } })
        // The planet P2's alignment would have captured is still on board.
        #expect(after.rings[2].occupants[3] == .one)
    }

    @Test("R-14: Grand Alignment fires after the rotation for the mover (R-13b)")
    func grandAlignmentAfterRotation() throws {
        // Pre angles: ring1 a36 (post 48≡0), ring2 a40 (post 48≡0),
        // ring3 a3 (post 0), ring4 a46 (post 48≡0) — one ray after rotation.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .one)
        Self.placeAt(&state, ring: 2, angle: 40, .one)
        Self.placeAt(&state, ring: 3, angle: 3, .one)
        Self.placeAt(&state, ring: 4, angle: 46, .one)
        Self.placeAt(&state, ring: 4, angle: 14, .two)  // bystander (ring 4 is even-angle)
        #expect(!Alignment.grandAlignment(for: .one, in: state))  // pre-round angles differ
        state.toMove = .one
        let (first, _) = try Reducer.apply(.place(ring: 4, slot: 6), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: first)
        #expect(after.result == .won(.one, reason: "Grand Alignment"))
        #expect(events.contains(.grandAlignment(.one)))
    }

    @Test("R-14: Grand Alignment for the player who moves second also fires post-rotation (R-13b order)")
    func grandAlignmentSecondPlayer() throws {
        // P2's four planets share angle 0 only post-rotation. P1 has
        // nothing aligned. Order: P1's check finds nothing, P2's finds the
        // Grand Alignment → P2 wins after the round.
        var state = GameStateFactory.initial(seed: 0)
        Self.placeAt(&state, ring: 1, angle: 36, .two)
        Self.placeAt(&state, ring: 2, angle: 40, .two)
        Self.placeAt(&state, ring: 3, angle: 3, .two)
        Self.placeAt(&state, ring: 4, angle: 46, .two)
        Self.placeAt(&state, ring: 4, angle: 14, .one)  // bystander (ring 4 is even-angle)
        #expect(!Alignment.grandAlignment(for: .two, in: state))
        state.toMove = .one
        let (first, _) = try Reducer.apply(.place(ring: 4, slot: 6), to: state)
        let (after, events) = try Reducer.apply(.place(ring: 1, slot: 4), to: first)
        #expect(after.result == .won(.two, reason: "Grand Alignment"))
        #expect(events.contains(.grandAlignment(.two)))
    }
}
