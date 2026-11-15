/// Q32.32 fixed-point type (Int64 backing).
///
/// All rules math uses `Int` or `Fixed`. `Float`/`Double` are banned in Core except debug
/// formatting and the lossy `init(_: Double)` for non-core paths.
public struct Fixed: Sendable, Codable, Hashable, Comparable {
    public let raw: Int64

    public static let one = Fixed(raw: 0x1_0000_0000)
    public static let zero = Fixed(raw: 0)

    public init(raw: Int64) {
        self.raw = raw
    }

    public init(_ value: Int) {
        self.raw = Int64(value) &<< 32
    }

    /// Construct from a Double (lossy; only for non-core paths).
    public init(_ value: Double) {
        self.raw = Int64(value * 4294967296.0)
    }

    // MARK: - Arithmetic

    public static func + (lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed(raw: lhs.raw &+ rhs.raw)
    }

    public static func - (lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed(raw: lhs.raw &- rhs.raw)
    }

    public static func * (lhs: Fixed, rhs: Fixed) -> Fixed {
        // 128-bit product, then take the Q32.32 result: (a * b) >> 32.
        let product = Int128(lhs.raw) * Int128(rhs.raw)
        return Fixed(raw: Int64(truncatingIfNeeded: product >> 32))
    }

    public static func / (lhs: Fixed, rhs: Fixed) -> Fixed {
        precondition(rhs.raw != 0)
        // (lhs << 32) / rhs, computed in 128 bits so the shifted numerator cannot overflow.
        let numerator = Int128(lhs.raw) << 32
        return Fixed(raw: Int64(truncatingIfNeeded: numerator / Int128(rhs.raw)))
    }

    public static prefix func - (x: Fixed) -> Fixed {
        Fixed(raw: x.raw == Int64.min ? Int64.max : -x.raw)
    }

    // MARK: - Comparison

    public static func < (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw < rhs.raw
    }

    // MARK: - Conversion

    /// Round half away from zero.
    public func rounded() -> Int {
        let m = (raw.magnitude &+ 0x8000_0000) >> 32
        return raw < 0 ? -Int(m) : Int(m)
    }

    public func doubleValue() -> Double {
        Double(raw) / 4294967296.0
    }

    /// Human-readable decimal string with `precision` fraction digits (round half up).
    public func description(precision: Int = 2) -> String {
        precondition(precision >= 0 && precision <= 9, "precision must be in 0...9")
        let sign = raw < 0 ? "-" : ""
        let magnitude = raw == Int64.min ? (~UInt64(Int64.max)) + 1 : UInt64(raw.magnitude)
        let intPart = magnitude >> 32
        let fracPart = magnitude & 0xFFFF_FFFF
        let scale = pow10(precision)
        let scaled = (fracPart * scale + 0x8000_0000) >> 32
        if precision == 0 {
            return "\(sign)\(intPart)"
        }
        if scaled >= scale {
            // Fraction rounded up to a whole: carry into the integer part.
            return "\(sign)\(intPart + 1)." + String(repeating: "0", count: precision)
        }
        var fracStr = String(scaled)
        while fracStr.count < precision { fracStr = "0" + fracStr }
        return "\(sign)\(intPart).\(fracStr)"
    }

    private func pow10(_ n: Int) -> UInt64 {
        var result: UInt64 = 1
        for _ in 0..<n { result &*= 10 }
        return result
    }
}
