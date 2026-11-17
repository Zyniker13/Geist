/// Leader paths (R-3, R-4): the leader point a sub-flock is attracted to.
///
/// The leader point traverses the waypoint sequence in order, moving at the
/// flock's max speed each tick (R-3). When every waypoint has been reached —
/// equivalently, when the player lifts all fingers — the leader point circles
/// its last position (R-4). All motion is integer Q16.16 (INV-3).
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

/// A leader path: an ordered sequence of waypoints plus a moving leader point.
public struct LeaderPath: Codable, Sendable, Equatable, Hashable {
    public var points: [Waypoint]
    /// The index of the current target waypoint.
    public var currentTarget: Int

    /// The leader's current position (the attractor birds steer toward).
    public var currentX: Int32
    public var currentY: Int32

    /// Circling phase after the path completes (R-4), in binary degrees.
    public var circleAngle: Int32

    /// Radius of the post-path circle (R-4: "circling its last position").
    public static let circleRadius = 24

    /// Circle advance per tick in binary degrees: 1024/128 = a full circle
    /// every 128 ticks (~4.3 s), a slow deliberate orbit.
    public static let circleStep = 8

    public init(points: [Waypoint]) {
        self.points = points
        self.currentTarget = 0
        self.currentX = points.first?.x ?? 0
        self.currentY = points.first?.y ?? 0
        self.circleAngle = 0
    }

    /// Whether this path is complete (all waypoints visited).
    public var isComplete: Bool {
        currentTarget >= points.count
    }

    /// Move the leader point one tick along its path at `speed` world units
    /// per tick (R-3). Returns true when a waypoint was just reached.
    /// After the final waypoint the leader circles its last position (R-4).
    public mutating func advance(speed: Int32) -> Bool {
        if isComplete {
            // Circle the last reached position deterministically.
            circleAngle = (circleAngle &+ Int32(LeaderPath.circleStep)) & Int32(IntTrig.turns - 1)
            guard let last = points.last else { return false }
            let unit = unitVectorQ16(circleAngle)
            currentX = last.x + Int32((Int64(unit.x) * Int64(LeaderPath.circleRadius)) >> 16)
            currentY = last.y + Int32((Int64(unit.y) * Int64(LeaderPath.circleRadius)) >> 16)
            return false
        }
        let next = points[currentTarget]
        let dx = Int64(next.x) - Int64(currentX)
        let dy = Int64(next.y) - Int64(currentY)
        let dist = Int32(isqrt64(UInt64(dx * dx + dy * dy)))
        if dist <= speed {
            currentX = next.x
            currentY = next.y
            currentTarget += 1
            return true
        }
        // Interpolate toward the waypoint at exactly `speed` per tick.
        if dist > 0 {
            currentX += Int32((dx * Int64(speed)) / Int64(dist))
            currentY += Int32((dy * Int64(speed)) / Int64(dist))
        }
        return false
    }

    /// The attractor position birds steer toward: the leader point itself.
    public func attractor() -> (x: Int32, y: Int32) {
        (currentX, currentY)
    }
}
