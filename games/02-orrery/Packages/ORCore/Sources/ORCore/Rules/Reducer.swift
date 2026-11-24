/// The pure rules reducer (§4.2.2): one entry point, state in → (state, events) out.
///
/// Turn flow:
/// 1. Validate + apply the action (R-5, R-6) — place, nudge, or pass.
/// 2. Check alignments for the acting player only (R-13a), Grand Alignment
///    first (R-14), then captures (R-12). Grand Alignment wins immediately.
/// 3. Evaluate victory (R-15/R-17). If terminal, stop.
/// 4. Advance the turn. If both players have moved (R-7), rotate all rings by
///    their speeds, then check alignments (R-13b): the player who moves next
///    first, then the other, each on the board state after the previous
///    player's captures. Grand Alignment wins immediately; captures apply
///    before the second player's check.
/// 5. Evaluate victory again; the R-16 round limit ends the game after the
///    post-rotation checks of the round that just completed.
public enum Reducer {

    /// Apply `action` to `state`. Throws `RuleError` on any illegal action;
    /// state is never partially mutated (all validation precedes mutation).
    public static func apply(
        _ action: Action,
        to state: GameState,
        variant: Variant = .standard
    ) throws -> (GameState, [Event]) {
        if state.result != nil { throw RuleError.gameAlreadyOver }
        let player = state.toMove

        var events: [Event] = []
        var next = state

        switch action {
        case .place(let ringIndex, let slot):
            guard state.rings.indices.contains(ringIndex - 1) else { throw RuleError.unknownRing(ringIndex) }
            guard (state.reserve[player] ?? 0) > 0 else { throw RuleError.reserveEmpty(player) }
            guard next.rings[ringIndex - 1].place(owner: player, slot: slot) else {
                if !(0..<state.rings[ringIndex - 1].slots).contains(slot) {
                    throw RuleError.slotOutOfRange(ring: ringIndex, slot: slot)
                }
                throw RuleError.slotOccupied(ring: ringIndex, slot: slot)
            }
            next.reserve[player] = (state.reserve[player] ?? 0) - 1
            events.append(.placed(player, ring: ringIndex, slot: slot))
            // The ko memory binds the immediately following turn: this place
            // clears it. Clause-2 memory is per player's OWN last action, so
            // only the acting player's flips (the opponent's own-last-action
            // record is untouched — it governs the opponent's next turn).
            next.lastNudge = nil
            next.nudgedLastTurn[player] = false

        case .nudge(let ringIndex, let dir):
            guard dir == 1 || dir == -1 else { throw RuleError.unknownRing(ringIndex) }
            guard state.rings.indices.contains(ringIndex - 1) else { throw RuleError.unknownRing(ringIndex) }
            guard LegalMoves.isNudgeLegal(ring: ringIndex, dir: dir, in: state) else {
                if let last = state.lastNudge, last.player == player.opponent,
                    last.ring == ringIndex, last.dir == -dir
                {
                    throw RuleError.nudgeKo(ring: ringIndex, dir: dir)
                }
                throw RuleError.nudgeTwoTurnsInARow
            }
            let step = state.rings[ringIndex - 1].slotStep
            next.rings[ringIndex - 1].rotate(by: dir * step)
            next.lastNudge = GameState.Nudge(player: player, ring: ringIndex, dir: dir)
            next.nudgedLastTurn[player] = true
            events.append(.nudged(ring: ringIndex, dir: dir))

        case .pass:
            // R-8: pass is legal only when no place or nudge is. Note
            // LegalMoves.all() lists the pass itself when nothing else is
            // legal, so "empty" is the wrong test — filter for the real
            // actions.
            let hasRealAction = LegalMoves.all(in: state).contains { action in
                if case .pass = action { return false }
                return true
            }
            guard !hasRealAction else { throw RuleError.illegalPass }
            // A pass consumes the turn but is not a place: both R-6 memories
            // carry across it (an opponent nudge may ko through a forced
            // pass; a player's own nudge still blocks their next nudge).
            next.nudgedLastTurn = state.nudgedLastTurn
        }

        // R-13a: acting player's checks.
        let actingChecks = checkAlignments(for: player, in: next, variant: variant, events: &events)
        next = actingChecks.state
        if actingChecks.gameOver {
            return (next, events)
        }

        // Advance the turn.
        if player == .one {
            next.toMove = .two
            next.turnInRound = 1
        } else {
            // Round completed: rotate (R-7), then post-rotation checks (R-13b).
            let (rotated, deltas) = Rotation.rotateRings(next.rings)
            next.rings = rotated
            next.round += 1
            next.turnInRound = 0
            next.toMove = .one
            // The rotation is not a turn: R-6's "immediately preceding turn"
            // memories survive it. The ko clause (immediate undo) stays live
            // across the round boundary; `nudgedLastTurn` also carries (a
            // player nudging on the last turn of a round then again on their
            // first turn of the next round has nudged on consecutive own
            // turns with only the rotation between).
            events.append(.rotated(deltas))

            // R-13b: the player who moves next (player 1) checks first, then
            // player 2, each on the state after the previous player's captures.
            let firstChecks = checkAlignments(for: .one, in: next, variant: variant, events: &events)
            next = firstChecks.state
            if firstChecks.gameOver {
                return (next, events)
            }
            let secondChecks = checkAlignments(for: .two, in: next, variant: variant, events: &events)
            next = secondChecks.state
            if secondChecks.gameOver {
                return (next, events)
            }

            // R-16: after the completed round's checks, the round limit ends
            // the game.
            if let result = Victory.evaluate(next, variant: variant) {
                next.result = result
                events.append(.gameOver(winner(of: result), reason: reason(of: result)))
                return (next, events)
            }
        }

        // R-15/R-17 evaluation after the acting player's captures (step 3).
        if let result = Victory.evaluate(next, variant: variant) {
            next.result = result
            events.append(.gameOver(winner(of: result), reason: reason(of: result)))
        }

        return (next, events)
    }

    /// Alignment checks for one player (R-14 before R-12). Returns the new
    /// state and whether the game became terminal during the checks.
    private static func checkAlignments(
        for player: PlayerID,
        in state: GameState,
        variant: Variant,
        events: inout [Event]
    ) -> (state: GameState, gameOver: Bool) {
        var next = state

        // R-14: Grand Alignment wins immediately, before captures.
        if Alignment.grandAlignment(for: player, in: next) {
            next.result = .won(player, reason: "Grand Alignment")
            events.append(.grandAlignment(player))
            events.append(.gameOver(player, reason: "Grand Alignment"))
            return (next, true)
        }

        // R-12: captures from alignments, reported per line (R-13's lines
        // process independently; one event per aligned line that captures).
        let opponent = player.opponent
        let opponentPlanets = state.planets(of: opponent)
        var capturedTotal = 0
        var removed: [PlanetRef] = []
        var seen: Set<PlanetRef> = []

        for alignment in Alignment.alignments(for: player, in: next) {
            let positions = alignment.planets.map { next.angle(of: $0).lineSign * $0.ring }
            guard let minPos = positions.min(), let maxPos = positions.max() else { continue }

            var lineCaptures: [PlanetRef] = []
            for enemy in opponentPlanets where !seen.contains(enemy) {
                let angle = next.angle(of: enemy)
                guard angle.lineIndex == alignment.line else { continue }
                let position = angle.lineSign * enemy.ring
                if position > minPos, position < maxPos {
                    seen.insert(enemy)
                    lineCaptures.append(enemy)
                }
            }
            // The alignment is reported whether or not it captures: the
            // schematic view highlights aligned lines on every check.
            events.append(.aligned(player, line: alignment.line, planets: alignment.planets))
            guard !lineCaptures.isEmpty else { continue }

            events.append(.captured(player, planets: lineCaptures))
            removed.append(contentsOf: lineCaptures)
            capturedTotal += lineCaptures.count
        }

        if !removed.isEmpty {
            for planet in removed {
                _ = next.rings[planet.ring - 1].remove(slot: planet.slot)
            }
            next.captured[player, default: 0] += capturedTotal

            if (next.captured[player] ?? 0) >= variant.capturesToWin {
                next.result = .won(player, reason: "captured \(variant.capturesToWin) enemy planets")
                events.append(.gameOver(player, reason: "captured \(variant.capturesToWin) enemy planets"))
                return (next, true)
            }

            // R-17 can trigger through captures (board emptied).
            if let result = Victory.evaluate(next, variant: variant) {
                next.result = result
                events.append(.gameOver(winner(of: result), reason: reason(of: result)))
                return (next, true)
            }
        }

        return (next, false)
    }

    private static func winner(of result: GameState.Result) -> PlayerID {
        switch result {
        case .won(let player, _): return player
        case .timeout(let player, _): return player
        }
    }

    private static func reason(of result: GameState.Result) -> String {
        switch result {
        case .won(_, let reason): return reason
        case .timeout(_, let reason): return reason
        }
    }
}
