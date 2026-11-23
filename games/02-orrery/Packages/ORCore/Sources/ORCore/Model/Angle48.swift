/// An angle on the orrery board, stored as an integer in `0...47` (R-1).
///
/// Angles are integers mod 48: one "turn" is 48 units, so a full ring rotation
/// is +48. All arithmetic normalizes back into `0...47`. `Angle48` is the
/// canonical angular unit for every rules path (slot positions, rotation,
/// lines, Grand Alignment); rendering converts to radians only at the edge.
public struct Angle48: Sendable, Codable, Hashable, Comparable, CustomStringConvertible {
    /// The normalized angle value, always in `0...47`.
    public let value: Int

    /// Create from any Int, normalizing mod 48 (negative and overshooting values wrap).
    public init(_ raw: Int) {
        // Swift's % keeps the sign of the dividend, so fold negatives up.
        self.value = ((raw % 48) + 48) % 48
    }

    /// The canonical constant angles.
    public static let zero = Angle48(0)

    /// Number of distinct angles in a turn.
    public static let count = 48

    /// The angle a quarter turn (12 units) ahead.
    public static let quarter = Angle48(12)

    /// The angle half a turn (24 units) ahead — the opposite point.
    public static let half = Angle48(24)

    // MARK: - Arithmetic

    /// Advance by `delta` angle units (wraps mod 48; negative deltas rewind).
    public func advanced(by delta: Int) -> Angle48 {
        Angle48(value + delta)
    }

    /// Retreat by `delta` angle units (wraps mod 48).
    public func rewound(by delta: Int) -> Angle48 {
        Angle48(value - delta)
    }

    /// The signed difference `self - other` reduced to `-23...24`, the shortest
    /// way around the dial. Useful for comparing two angles' separation.
    public func difference(from other: Angle48) -> Int {
        let d = euclidMod(value - other.value, 48)
        return d <= 24 ? d : d - 48
    }

    /// The opposite angle (`self + 24`), the far end of this angle's line (R-9).
    public var opposite: Angle48 {
        Angle48(value + 24)
    }

    /// The line this angle belongs to (R-9): the unordered pair `{a, a+24}` is
    /// indexed by its smaller endpoint, so every angle maps to `0...23`.
    public var lineIndex: Int {
        min(value, opposite.value)
    }

    /// The sign of this angle on its line (R-10): `+1` at the line's smaller
    /// endpoint, `-1` at the opposite endpoint.
    public var lineSign: Int {
        value <= 23 ? 1 : -1
    }

    /// True when the two angles are on the same line (equal or opposite).
    public func isOnSameLine(as other: Angle48) -> Bool {
        lineIndex == other.lineIndex
    }

    /// Clock-face label for UI strings: 0 is 12 o'clock, 12 is 3 o'clock.
    public var clockLabel: String {
        let hour = value / 4
        let minutes = (value % 4) * 15
        let hourName = hour == 0 ? 12 : hour
        if minutes == 0 {
            return "\(hourName) o'clock"
        }
        let minutesName = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hourName):\(minutesName)"
    }

    public var description: String { "\(value)" }

    public static func < (lhs: Angle48, rhs: Angle48) -> Bool {
        lhs.value < rhs.value
    }
}

/// Euclidean modulo that always returns a value in `0..<rhs` (Swift's `%`
/// can return negatives).
private func euclidMod(_ lhs: Int, _ rhs: Int) -> Int {
    ((lhs % rhs) + rhs) % rhs
}
