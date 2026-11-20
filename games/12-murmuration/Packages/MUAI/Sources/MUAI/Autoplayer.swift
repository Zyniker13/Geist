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

    /// The waypoint of the last issued path, if any.
    var lastTarget: Waypoint?
    /// The flock's standoff waypoint while it waits for fields to re-arm,
    /// if any.
    var lastStandoff: Waypoint?
    /// Whether this dusk already received its roost path.
    var issuedDuskPath: Bool

    public init() {
        self.lastTarget = nil
        self.lastStandoff = nil
        self.issuedDuskPath = false
    }

    /// The action to apply this tick, or nil.
    public mutating func action(for state: GameState) -> GameAction? {
        // A fresh day's state starts at tick 0, well below duskStart; reset
        // the per-day flags whenever daytime is observed.
        if state.tick < GameState.duskStart {
            issuedDuskPath = false
        }

        if state.isDusk {
            return duskAction(state)
        }
        return forageAction(state)
    }

    // MARK: - Daytime: forage

    /// Re-decides the forage target every tick. The 480-tick interval this
    /// once used let the flock sit on a field its last gulp had emptied:
    /// each trickle of regrowth was eaten immediately, restarting the
    /// field's 100-tick regrowth ramp, so the flock starved on a trickle.
    /// Every-tick re-decision leaves a spent field at once; the hysteresis
    /// bonus in `ForageScoring` keeps the choice stable while food lasts.
    private mutating func forageAction(_ state: GameState) -> GameAction? {
        let (cx, cy) = centroid(state, subFlock: 0)
        let birds = countBirdsInFlock(
            assignments: state.subFlockAssignments, subFlock: 0
        )
        switch ForageScoring.directive(
            state,
            bank: state.energy[0],
            flock: (x: cx, y: cy, birds: birds),
            pilot: .init(current: lastTarget, standoff: lastStandoff)
        ) {
        case .hold:
            // No fields at all; hold the current path.
            return condenseIfAvailable(state)
        case .standoff(let point):
            // Stand clear of regrowing fields so no straggler grazes one
            // and restarts its ramp. Re-issuing the same path would
            // teleport the leader, so only a new standoff point issues.
            lastStandoff = point
            if point == lastTarget { return condenseIfAvailable(state) }
            lastTarget = point
            return .setLeaderPath(subFlock: 0, waypoints: [point])
        case .forage(let point):
            lastStandoff = nil
            if point == lastTarget { return condenseIfAvailable(state) }
            lastTarget = point
            return .setLeaderPath(subFlock: 0, waypoints: [point])
        }
    }

    /// A condense while none is active or cooling down. The day cloud
    /// stretches as it flies and grazes fields it passes, restarting
    /// their regrowth ramps; doubling cohesion keeps it compact so
    /// travel is faster and standing off actually stands clear
    /// (ADR-0030). Only issued when no path change is due, so it never
    /// delays steering.
    private func condenseIfAvailable(_ state: GameState) -> GameAction? {
        guard state.condenseActive == 0, state.condenseCooldown == 0 else {
            return nil
        }
        return .condense(subFlock: 0)
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
