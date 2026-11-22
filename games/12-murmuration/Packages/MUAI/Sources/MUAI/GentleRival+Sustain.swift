// Murmuration AI — the rival pilot's sustainability split and shared
// helpers (ADR-0035).
//
// The sustainability split fights a structural AI-quality bug: the pilot
// only ever planned flock 1, so a split-off flock 2 had no forage directive
// at all and starved via R-8 (zero energy kills birdCount/100 per event).
// On two-field regions the side starved as a whole. The fix is two-part:
// at dawn, a fat single flock splits once per day onto two different
// forage destinations (here), and every rival flock plans its own forage
// with the other flocks' centroids and the player's leader point in its
// avoid set (see ForageScoring).
//
// Deterministic (integer arithmetic only), like the Autoplayer.

import MUCore

extension GentleRival {
    // MARK: - Shared decisions

    /// The rival flocks this pilot steers: flock 1 always, flock 2 when a
    /// split (dusk or sustainability) created one.
    func rivalFlocks(of state: GameState) -> [UInt8] {
        state.subFlockCount >= 3 ? [1, 2] : [1]
    }

    // MARK: - Sustainability split (ADR-0035)

    /// ADR-0035 sustainability split: at the day's start, a fat single
    /// flock splits into two halves that strip different fields, so the
    /// side's growth is limited by the fields rather than by its own
    /// flocking. Runs in the daytime (where the dusk-split per-side cap has
    /// no say) and fires at most once per day (`sustainSplitDone`, reset at
    /// each dawn).
    mutating func sustainIfNeeded(_ state: GameState) -> GameAction? {
        guard sustainSplit > 0,
            !sustainSplitDone,
            state.subFlockCount < 3,
            countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 1)
                >= sustainSplit
        else { return nil }
        sustainSplitDone = true
        splitStage = 1
        splitTargetA = nil
        splitTargetB = nil
        return .splitFlock(from: 1, ratio: 0.5)
    }

    /// Daytime routing for the sustainability split: flock 1 to its best
    /// field, flock 2 to a different one (flock 1's target joins its avoid
    /// set), one path per call.
    mutating func continueSustainRouting(_ state: GameState) -> GameAction? {
        let (lx, ly) = playerLeaderPoint(state)
        switch splitStage {
        case 1:
            splitStage = 2
            guard countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 2) > 0
            else { splitStage = 0; return nil }
            let (cx, cy) = centroid(state, subFlock: 1)
            let birds = countBirdsInFlock(
                assignments: state.subFlockAssignments, subFlock: 1
            )
            let avoid = [AvoidPoint(x: Int32(lx), y: Int32(ly), distance: standoffDistance)]
            guard let field = ForageScoring.bestField(
                state, nearX: cx, nearY: cy, birds: birds,
                current: lastTargetByFlock[1], avoid: avoid
            ) else { splitStage = 0; return nil }
            let target = Waypoint(x: field.centerX, y: field.centerY)
            lastTargetByFlock[1] = target
            lastForageTickByFlock[1] = state.tick
            return .setLeaderPath(subFlock: 1, waypoints: [target])
        case 2:
            splitStage = 0
            guard countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 2) > 0
            else { return nil }
            let (cx, cy) = centroid(state, subFlock: 2)
            let birds = countBirdsInFlock(
                assignments: state.subFlockAssignments, subFlock: 2
            )
            var avoid = [AvoidPoint(x: Int32(lx), y: Int32(ly), distance: standoffDistance)]
            if let t1 = lastTargetByFlock[1] {
                avoid.append(AvoidPoint(x: t1.x, y: t1.y, distance: standoffDistance))
            }
            guard let field = ForageScoring.bestField(
                state, nearX: cx, nearY: cy, birds: birds,
                current: lastTargetByFlock[2], avoid: avoid
            ) else { return nil }
            let target = Waypoint(x: field.centerX, y: field.centerY)
            lastTargetByFlock[2] = target
            lastForageTickByFlock[2] = state.tick
            return .setLeaderPath(subFlock: 2, waypoints: [target])
        default:
            splitStage = 0
            return nil
        }
    }

    // MARK: - Shared geometry

    /// A point `standoffDistance` (Chebyshev) away from the player centroid,
    /// in the direction from the player through the rival, clamped into the
    /// world with a margin. Q16.16 fixed-point intermediate math.
    func standoffPoint(
        _ state: GameState, fromX: Int32, fromY: Int32,
        awayFromX: Int32, awayFromY: Int32
    ) -> Waypoint {
        let dx = Int64(fromX) - Int64(awayFromX)
        let dy = Int64(fromY) - Int64(awayFromY)
        let mag = max(abs(dx), abs(dy))
        if mag < 64 {
            // Near-coincident centroids (the day-start split leaves the
            // clouds interleaved, so the centroid gap is scatter noise): the
            // player-to-rival direction is meaningless, so stand off +x from
            // the world center — where the day-start clouds are centered —
            // deterministically for every seed.
            let margin: Int32 = 64
            return Waypoint(
                x: min(max(state.worldWidth / 2 + Int32(standoffDistance), margin), state.worldWidth - margin),
                y: min(max(state.worldHeight / 2, margin), state.worldHeight - margin)
            )
        }
        let scale = (Int64(standoffDistance) << 16) / mag
        var tx = awayFromX + Int32(truncatingIfNeeded: (dx * scale) >> 16)
        var ty = awayFromY + Int32(truncatingIfNeeded: (dy * scale) >> 16)
        let margin: Int32 = 64
        tx = min(max(tx, margin), state.worldWidth - margin)
        ty = min(max(ty, margin), state.worldHeight - margin)
        return Waypoint(x: tx, y: ty)
    }

    /// The player flock's leader point, for standoff and avoid scoring.
    func playerLeaderPoint(_ state: GameState) -> (x: Int32, y: Int32) {
        let path = state.leaderPaths[0]
        return (path.currentX, path.currentY)
    }

    /// The flock's centroid in world coordinates.
    func centroid(_ state: GameState, subFlock: UInt8) -> (x: Int32, y: Int32) {
        centroidOfFlock(
            birds: state.birds,
            assignments: state.subFlockAssignments,
            subFlock: subFlock
        )
    }
}
