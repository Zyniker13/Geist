// Murmuration AI — the Gentle rival pilot (P2.3).
//
// "Gentle" means the rival plays to survive, not to fight: it forages fields
// away from the player's leader point, claims a roost the player is not
// heading to, and otherwise holds a standoff. The hard constraint is R-5:
// two sub-flocks whose centroids stay within `mergeProximity` for 30
// consecutive ticks merge into flock 0 — a merged rival disappears, so the
// pilot keeps the flocks separated by a comfortable margin and flees when
// the player closes in.
//
// Deterministic (integer arithmetic only), like the Autoplayer.

import MUCore

/// The rival pilot for sub-flock 1. Value type, `Codable` for save/resume.
public struct GentleRival: Codable, Equatable, Sendable {
    /// Ticks between forage re-decisions.
    public var forageInterval: Int
    /// Ticks between centroid-proximity checks (flee decisions).
    public var fleeInterval: Int
    /// Centroid distance (squared Euclidean) that triggers a flee. R-5 merges
    /// under 200 for 30 consecutive ticks; 320 gives the pilot time to open
    /// the gap before the streak can complete.
    public var fleeRadius: Int
    /// Distance the rival keeps from the player's leader point when picking
    /// fields and roosts.
    public var standoffDistance: Int

    var lastForageTick: Int
    var lastFleeCheckTick: Int
    /// The waypoint of the last issued path, if any.
    var lastTarget: Waypoint?
    /// Whether this dusk already received its roost or standoff plan.
    var issuedDuskPlan: Bool

    public init(
        forageInterval: Int = 480,
        fleeInterval: Int = 60,
        fleeRadius: Int = 320,
        standoffDistance: Int = 640
    ) {
        self.forageInterval = forageInterval
        self.fleeInterval = fleeInterval
        self.fleeRadius = fleeRadius
        self.standoffDistance = standoffDistance
        self.lastForageTick = Autoplayer.noTick
        self.lastFleeCheckTick = Autoplayer.noTick
        self.lastTarget = nil
        self.issuedDuskPlan = false
    }

    /// The action to apply this tick, or nil.
    public mutating func action(for state: GameState) -> GameAction? {
        // No rival flock until the day-start split creates one; a wiped-out
        // flock has no centroid (centroidOfFlock would report the corner).
        guard countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 1) > 0,
            countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 0) > 0
        else { return nil }

        // A fresh day's state starts at tick 0; reset the per-day flags.
        if state.tick < GameState.duskStart {
            issuedDuskPlan = false
            if lastForageTick > state.tick { lastForageTick = Autoplayer.noTick }
            if lastFleeCheckTick > state.tick { lastFleeCheckTick = Autoplayer.noTick }
        }

        if state.isDusk {
            return duskAction(state)
        }
        return dayAction(state)
    }

    // MARK: - Daytime

    private mutating func dayAction(_ state: GameState) -> GameAction? {
        if let flee = fleeIfNeeded(state) { return flee }
        return forageIfNeeded(state)
    }

    // MARK: - Dusk

    private mutating func duskAction(_ state: GameState) -> GameAction? {
        // The dusk plan is decided first: on the first dusk tick the clouds
        // can still sit near-coincident after the day-start split, and both
        // plan outcomes (a far roost, or a held standoff) open distance
        // anyway. The flee check keeps guarding the later dusk ticks.
        if !issuedDuskPlan {
            issuedDuskPlan = true
            // The roost farthest from the player's leader point (their dusk
            // target), taken only when it keeps the standoff margin.
            let (lx, ly) = playerLeaderPoint(state)
            var best: RoostState?
            var bestDist = Int64(-1)
            for roost in state.roosts {
                let dx = Int64(roost.centerX) - Int64(lx)
                let dy = Int64(roost.centerY) - Int64(ly)
                let dist = dx * dx + dy * dy
                if dist > bestDist {
                    best = roost
                    bestDist = dist
                }
            }
            if let roost = best,
                bestDist >= Int64(standoffDistance) * Int64(standoffDistance) {
                let target = Waypoint(x: roost.centerX, y: roost.centerY)
                if target != lastTarget {
                    lastTarget = target
                    return .setLeaderPath(subFlock: 1, waypoints: [target])
                }
                return nil
            }
            // No roost far enough (e.g. a single-roost region the player is
            // claiming): hold a standoff instead of contesting and risking a
            // merge (R-5).
            let (rx, ry) = centroid(state, subFlock: 1)
            let (px, py) = centroid(state, subFlock: 0)
            let target = standoffPoint(
                state, fromX: rx, fromY: ry, awayFromX: px, awayFromY: py
            )
            if target != lastTarget {
                lastTarget = target
                return .setLeaderPath(subFlock: 1, waypoints: [target])
            }
            return nil
        }

        if let flee = fleeIfNeeded(state) { return flee }

        // While holding a roost it can win, condense on cooldown (R-4).
        if state.condenseCooldown <= 0, state.condenseActive <= 0 {
            let (rx, ry) = centroid(state, subFlock: 1)
            for roost in state.roosts {
                let dx = rx - roost.centerX
                let dy = ry - roost.centerY
                if dx * dx + dy * dy <= roost.radius * roost.radius {
                    return .condense(subFlock: 1)
                }
            }
        }
        return nil
    }

    // MARK: - Shared decisions

    /// Flee when the flock centroids drift too close (checked every
    /// `fleeInterval` ticks). Returns the action to apply, or nil.
    private mutating func fleeIfNeeded(_ state: GameState) -> GameAction? {
        guard state.tick - lastFleeCheckTick >= fleeInterval else { return nil }
        lastFleeCheckTick = state.tick
        let (rcx, rcy) = centroid(state, subFlock: 1)
        let (pcx, pcy) = centroid(state, subFlock: 0)
        let dx = Int64(rcx) - Int64(pcx)
        let dy = Int64(rcy) - Int64(pcy)
        guard dx * dx + dy * dy < Int64(fleeRadius) * Int64(fleeRadius) else {
            return nil
        }
        let target = standoffPoint(
            state, fromX: rcx, fromY: rcy, awayFromX: pcx, awayFromY: pcy
        )
        if target == lastTarget { return nil }
        lastTarget = target
        return .setLeaderPath(subFlock: 1, waypoints: [target])
    }

    private mutating func forageIfNeeded(_ state: GameState) -> GameAction? {
        guard state.tick - lastForageTick >= forageInterval else { return nil }
        lastForageTick = state.tick
        guard let field = fieldAwayFromPlayer(state) else { return nil }
        let target = Waypoint(x: field.centerX, y: field.centerY)
        if target == lastTarget { return nil }
        lastTarget = target
        return .setLeaderPath(subFlock: 1, waypoints: [target])
    }

    /// The field with the most remaining food among those at least
    /// `standoffDistance` from the player's leader point; when every field is
    /// closer than that, the farthest one.
    private func fieldAwayFromPlayer(_ state: GameState) -> FieldState? {
        let (lx, ly) = playerLeaderPoint(state)
        var best: FieldState?
        var bestScore = -1
        var bestDist = Int64(-1)
        for field in state.fields {
            let remaining = field.maxDepletion - field.currentDepletion
            if remaining <= 0 { continue }
            let dx = Int64(field.centerX) - Int64(lx)
            let dy = Int64(field.centerY) - Int64(ly)
            let dist = dx * dx + dy * dy
            let clear = dist >= Int64(standoffDistance) * Int64(standoffDistance)
            // Prefer clear fields, then food, then distance.
            let score = (clear ? 2 : 0) * 1_000_000_000 + remaining
            if score > bestScore || (score == bestScore && dist > bestDist) {
                best = field
                bestScore = score
                bestDist = dist
            }
        }
        return best
    }

    /// A point `standoffDistance` (Chebyshev) away from the player centroid,
    /// in the direction from the player through the rival, clamped into the
    /// world with a margin. Q16.16 fixed-point intermediate math.
    private func standoffPoint(
        _ state: GameState, fromX: Int32, fromY: Int32,
        awayFromX: Int32, awayFromY: Int32
    ) -> Waypoint {
        var dx = Int64(fromX) - Int64(awayFromX)
        var dy = Int64(fromY) - Int64(awayFromY)
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

    private func playerLeaderPoint(_ state: GameState) -> (x: Int32, y: Int32) {
        let path = state.leaderPaths[0]
        return (path.currentX, path.currentY)
    }

    private func centroid(_ state: GameState, subFlock: UInt8) -> (x: Int32, y: Int32) {
        centroidOfFlock(
            birds: state.birds,
            assignments: state.subFlockAssignments,
            subFlock: subFlock
        )
    }
}
