/// A 2D fixed-point position in sub-tile units.
///
/// 1 tile = 1,024 units. All positions are `Int32` to fit in 64 bits total.
public struct FixedPoint2: Sendable, Codable, Hashable, Equatable, Comparable {
    public var x: Int32
    public var y: Int32

    public static let origin = FixedPoint2(x: 0, y: 0)

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }

    /// Distance squared to another point (in sub-tile units squared).
    public func distanceSquared(to other: FixedPoint2) -> Int64 {
        let dx = Int64(other.x) - Int64(self.x)
        let dy = Int64(other.y) - Int64(self.y)
        return dx * dx + dy * dy
    }

    /// Manhattan distance in tile units.
    public func manhattanTiles(to other: FixedPoint2) -> Int {
        abs(Int(other.x) - Int(self.x)) / 1024 + abs(Int(other.y) - Int(self.y)) / 1024
    }

    public static func < (lhs: FixedPoint2, rhs: FixedPoint2) -> Bool {
        (lhs.x, lhs.y) < (rhs.x, rhs.y)
    }

    public static func + (lhs: FixedPoint2, rhs: FixedPoint2) -> FixedPoint2 {
        FixedPoint2(x: lhs.x &+ rhs.x, y: lhs.y &+ rhs.y)
    }

    public static func - (lhs: FixedPoint2, rhs: FixedPoint2) -> FixedPoint2 {
        FixedPoint2(x: lhs.x &- rhs.x, y: lhs.y &- rhs.y)
    }
}
