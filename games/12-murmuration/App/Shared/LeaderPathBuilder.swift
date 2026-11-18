// Murmuration app — leader-path input builder (P2.2 / P2.5).
//
// One-finger (iOS) or click-drag (Mac) draws the leader path. The engine's
// `setLeaderPath` REPLACES a flock's path and teleports its leader to the
// first waypoint, so a live drag always starts the list at the leader's
// current position and re-issues the accumulated list as it grows.

import MUCore

/// Accumulates drag samples into leader-path actions.
struct LeaderPathBuilder {
    /// Minimum spacing between waypoints, world units.
    var spacing: Float = 24
    /// Safety cap on path length.
    var maxWaypoints = 240

    private(set) var waypoints: [Waypoint] = []
    private var subFlock: UInt8 = 0

    /// Start a drag: seed the path with the leader's current position so the
    /// re-issue does not teleport it.
    mutating func begin(leaderX: Int32, leaderY: Int32, subFlock: UInt8) -> GameAction? {
        self.subFlock = subFlock
        waypoints = [Waypoint(x: leaderX, y: leaderY)]
        return .setLeaderPath(subFlock: subFlock, waypoints: waypoints)
    }

    /// Extend with a drag sample (world units). Returns the action when a new
    /// waypoint was added, else nil.
    mutating func extend(to world: SIMD2<Float>) -> GameAction? {
        guard let last = waypoints.last else { return nil }
        let dx = Float(last.x) - world.x
        let dy = Float(last.y) - world.y
        guard dx * dx + dy * dy >= spacing * spacing else { return nil }
        guard waypoints.count < maxWaypoints else { return nil }
        let clamped = SIMD2(
            min(max(world.x, 8), 8190), min(max(world.y, 8), 8190)
        )
        waypoints.append(Waypoint(x: Int32(clamped.x), y: Int32(clamped.y)))
        return .setLeaderPath(subFlock: subFlock, waypoints: waypoints)
    }
}
