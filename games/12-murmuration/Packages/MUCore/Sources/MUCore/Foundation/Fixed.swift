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

    /// Construct from an `Int` (integer part, Q32.32).
    public init(_ value: Int) {
        self.raw = Int64(value) &<< 32
    }

    /// Construct from an `Int32` (integer part, Q32.32).
    public init(_ value: Int32) {
        self.raw = Int64(value) &<< 32
    }

    /// Construct from a `Double` (lossy; only for non-core paths).
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
        // Signed 64×64→128 product; result = middle 64 bits (Q32.32).
        let (high, low) = lhs.raw.multipliedFullWidth(by: rhs.raw)
        // Middle 64 bits: (high & 0xFFFFFFFF) << 32 | (low >> 32)
        let raw = UInt64(high & 0xFFFFFFFF) &<< 32 | UInt64(low >> 32)
        return Fixed(raw: Int64(bitPattern: raw))
    }

    public static func / (lhs: Fixed, rhs: Fixed) -> Fixed {
        precondition(rhs.raw != 0)
        // Q32.32 division: (lhs << 32) / rhs
        // Build 128-bit dividend = lhsAbs * 2^32, divisor = rhsAbs
        let lhsAbs = lhs.raw < 0 ? (~UInt64(bitPattern: lhs.raw)) &+ 1 : UInt64(bitPattern: lhs.raw)
        let rhsAbs = rhs.raw < 0 ? (~UInt64(bitPattern: rhs.raw)) &+ 1 : UInt64(bitPattern: rhs.raw)
        // 128-bit dividend: hi = lhsAbs >> 32, lo = (lhsAbs & 0xFFFF_FFFF) << 32
        let divHi = lhsAbs >> 32
        let divLo = (lhsAbs & 0xFFFF_FFFF) << 32
        let (quotient, _) = _div128_64(divHi, divLo, rhsAbs)
        let sign = (lhs.raw < 0) != (rhs.raw < 0)
        if sign {
            return Fixed(raw: Int64(bitPattern: ~quotient &+ UInt64(1)))
        }
        return Fixed(raw: Int64(bitPattern: quotient))
    }

    private static func _div128_64(_ hi: UInt64, _ lo: UInt64, _ divisor: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        // 128÷64 unsigned division via bit-by-bit long division.
        // dividend = (hi << 64) | lo, result quotient fits in 64 bits.
        var r: UInt64 = 0
        var q: UInt64 = 0
        for i in 0..<128 {
            r = r << 1
            let bitIdx = 127 - i
            let isSet = bitIdx >= 64
                ? (hi & (UInt64(1) << UInt(bitIdx - 64))) != 0
                : (lo & (UInt64(1) << UInt(bitIdx))) != 0
            if isSet { r |= 1 }
            if r >= divisor {
                r -= divisor
                // Quotient bit at position (127-i), but only store low 64 bits.
                let qPos = 127 - i
                if qPos < 64 {
                    q |= (UInt64(1) << UInt(qPos))
                }
            }
        }
        return (q, r)
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
        let absVal = raw < 0 ? (~UInt64(bitPattern: raw)) &+ 1 : UInt64(bitPattern: raw)
        let m = (absVal &+ 0x8000_0000) >> 32
        return raw < 0 ? -Int(m) : Int(m)
    }

    public func doubleValue() -> Double {
        Double(raw) / 4294967296.0
    }

    /// Human-readable decimal string with `precision` fraction digits (round half up).
    public func description(precision: Int = 2) -> String {
        precondition(precision >= 0 && precision <= 9, "precision must be in 0...9")
        let sign = raw < 0 ? "-" : ""
        let absVal = raw < 0 ? (~UInt64(bitPattern: raw)) &+ 1 : UInt64(bitPattern: raw)
        let intPart = absVal >> 32
        let fracPart = absVal & 0xFFFF_FFFF
        let scale = pow10(precision)
        let scaled = (fracPart * scale + 0x8000_0000) >> 32
        if precision == 0 {
            return "\(sign)\(intPart)"
        }
        if scaled >= scale {
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
