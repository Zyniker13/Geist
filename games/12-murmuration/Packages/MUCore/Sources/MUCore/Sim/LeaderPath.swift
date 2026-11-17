/// Leader paths (R-3): a sequence of waypoints that sub-flocks follow.
///
/// The leader path is a list of (x, y) world positions. Birds in a sub-flock
/// are attracted to the next waypoint on their leader's path. The leader advances
/// through waypoints at a fixed speed.
import Foundation

/// A single waypoint in a leader path.
public struct Waypoint: Codable, Sendable, Equatable, Hashable {
    public let x: Int32
    public let y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

/// A leader path: an ordered sequence of waypoints.
public struct LeaderPath: Codable, Sendable, Equatable, Hashable {
    public var points: [Waypoint]
    /// The index of the current target waypoint.
    public var currentTarget: Int

    /// The leader's current position (for interpolation).
    public var currentX: Int32
    public var currentY: Int32

    public init(points: [Waypoint]) {
        self.points = points
        self.currentTarget = points.isEmpty ? 0 : 0
        self.currentX = points.first?.x ?? 0
        self.currentY = points.first?.y ?? 0
    }

    /// Whether this path is complete (all waypoints visited).
    public var isComplete: Bool {
        currentTarget >= points.count
    }

    /// Advance to the next waypoint if the leader is close enough.
    /// Returns true if a new waypoint was reached.
    public mutating func advance(targetX: Int32, targetY: Int32, speed: Int32) -> Bool {
        guard !isComplete, currentTarget < points.count else { return false }
        let next = points[currentTarget]
        let dx = targetX - currentX
        let dy = targetY - currentY
        let dist = Int32(sqrt(Double(dx * dx + dy * dy)))
        if dist <= speed {
            currentX = next.x
            currentY = next.y
            currentTarget += 1
            return true
        }
        // Interpolate toward target.
        if dist > 0 {
            currentX = currentX + (dx * speed) / dist
            currentY = currentY + (dy * speed) / dist
        }
        return false
    }

    /// Compute the attractor position for a sub-flock's leader.
    /// If the leader is between waypoints, interpolate.
    public func attractor(for subFlock: UInt8, at tick: Int) -> (x: Int32, y: Int32) {
        guard !isComplete, currentTarget < points.count else {
            return (currentX, currentY)
        }
        // Use the current waypoint as the attractor.
        let wp = points[currentTarget]
        return (wp.x, wp.y)
    }
}
