// Murmuration AI — the autoplay pilot for the player flock (P2.3).
//
// Modeled on the sim's actionScript: forage the richest fields through the
// day, head to the nearest roost at dusk, condense while holding the roost.
// Decisions are deterministic functions of the observed state (integer
// arithmetic only), so the three-day autoplay UI test replays identically and
// pause/resume preserves checkpoint hashes.
//
// Paths are re-issued only when the target changes: `LeaderPath.init` places
// the leader at the first waypoint, so re-issuing the same path would
// teleport the leader and yank the flock.

import MUCore

/// The autoplay pilot for sub-flock 0. A value type: its decision state is
/// `Codable` so a save can resume mid-day without changing behavior.
public struct Autoplayer: Codable, Equatable, Sendable {
    /// Safe "never decided" sentinel: `Int.min` would overflow when the tick
    /// difference is taken, so the sentinel stays far from the edges.
    static let noTick = -1_000_000

    /// Ticks between forage re-decisions.
    public var forageInterval: Int
    /// Tick of the last issued (or deliberately skipped) forage decision.
    var lastForageTick: Int
    /// The waypoint of the last issued path, if any.
    var lastTarget: Waypoint?
    /// Whether this dusk already received its roost path.
    var issuedDuskPath: Bool

    public init(forageInterval: Int = 480) {
        self.forageInterval = forageInterval
        self.lastForageTick = Self.noTick
        self.lastTarget = nil
        self.issuedDuskPath = false
    }

    /// The action to apply this tick, or nil.
    public mutating func action(for state: GameState) -> GameAction? {
        // A fresh day's state starts at tick 0, well below duskStart; reset
        // the per-day flags whenever daytime is observed.
        if state.tick < GameState.duskStart {
            issuedDuskPath = false
            if lastForageTick > state.tick { lastForageTick = Self.noTick }
        }

        if state.isDusk {
            return duskAction(state)
        }
        return forageAction(state)
    }

    // MARK: - Daytime: forage

    private mutating func forageAction(_ state: GameState) -> GameAction? {
        guard state.tick - lastForageTick >= forageInterval else { return nil }
        let (cx, cy) = centroid(state, subFlock: 0)
        guard let field = bestField(state, nearX: cx, nearY: cy) else {
            // Every field is spent; hold the current path.
            lastForageTick = state.tick
            return nil
        }
        let target = Waypoint(x: field.centerX, y: field.centerY)
        lastForageTick = state.tick
        if target == lastTarget { return nil }
        lastTarget = target
        return .setLeaderPath(subFlock: 0, waypoints: [target])
    }

    // MARK: - Dusk: roost and condense

    private mutating func duskAction(_ state: GameState) -> GameAction? {
        if !issuedDuskPath {
            let (cx, cy) = centroid(state, subFlock: 0)
            guard let roost = nearestRoost(state, toX: cx, toY: cy) else { return nil }
            issuedDuskPath = true
            let target = Waypoint(x: roost.centerX, y: roost.centerY)
            if target == lastTarget { return nil }
            lastTarget = target
            return .setLeaderPath(subFlock: 0, waypoints: [target])
        }
        // While holding a roost, condense whenever the cooldown allows (R-4):
        // tighter flock, more birds inside the radius, stronger claim.
        if state.condenseCooldown <= 0, state.condenseActive <= 0 {
            let (cx, cy) = centroid(state, subFlock: 0)
            if isInsideRoost(state, x: cx, y: cy) {
                return .condense(subFlock: 0)
            }
        }
        return nil
    }

    // MARK: - Target selection (integer math only)

    /// The field with the most remaining food; ties break toward the flock.
    private func bestField(
        _ state: GameState, nearX: Int32, nearY: Int32
    ) -> FieldState? {
        var best: FieldState?
        var bestRemaining = -1
        var bestDist = Int64.max
        for field in state.fields {
            let remaining = field.maxDepletion - field.currentDepletion
            if remaining <= 0 { continue }
            let dx = Int64(field.centerX) - Int64(nearX)
            let dy = Int64(field.centerY) - Int64(nearY)
            let dist = dx * dx + dy * dy
            if remaining > bestRemaining || (remaining == bestRemaining && dist < bestDist) {
                best = field
                bestRemaining = remaining
                bestDist = dist
            }
        }
        return best
    }

    private func nearestRoost(
        _ state: GameState, toX: Int32, toY: Int32
    ) -> RoostState? {
        var best: RoostState?
        var bestDist = Int64.max
        for roost in state.roosts {
            let dx = Int64(roost.centerX) - Int64(toX)
            let dy = Int64(roost.centerY) - Int64(toY)
            let dist = dx * dx + dy * dy
            if dist < bestDist {
                best = roost
                bestDist = dist
            }
        }
        return best
    }

    private func isInsideRoost(_ state: GameState, x: Int32, y: Int32) -> Bool {
        for roost in state.roosts {
            let dx = x - roost.centerX
            let dy = y - roost.centerY
            if dx * dx + dy * dy <= roost.radius * roost.radius { return true }
        }
        return false
    }

    private func centroid(_ state: GameState, subFlock: UInt8) -> (x: Int32, y: Int32) {
        centroidOfFlock(
            birds: state.birds,
            assignments: state.subFlockAssignments,
            subFlock: subFlock
        )
    }
}
