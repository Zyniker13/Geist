/// Stable, deterministic state hashing (INV-4/INV-5 checkpoints).
///
/// Swift's `Hashable` is seed-randomized per process, so checkpoints use an
/// explicit FNV-1a digest over a canonical byte encoding of the state. The
/// encoding is versioned: `ENCODING_VERSION` bumps whenever the field set
/// changes, invalidating old golden hashes on purpose.
public enum StateHash {
    /// Bumped when the encoded state changes shape (v1: P0 trivial state).
    public static let encodingVersion: UInt8 = 1

    /// Human-readable 16-hex-digit form of a digest.
    public static func hexDigest(_ digest: UInt64) -> String {
        var value = digest
        var chars: [Character] = []
        let digits: [Character] = Array("0123456789abcdef")
        for _ in 0..<16 {
            chars.append(digits[Int(value & 0xF)])
            value >>= 4
        }
        return String(chars.reversed())
    }
}

/// FNV-1a 64-bit byte-stream hasher. Game states append their canonical
/// encoding through this builder; the final value is the checkpoint hash.
public struct FNV1a {
    private var hash: UInt64 = 0xcbf29ce484222325

    public init() {}

    public mutating func byte(_ value: UInt8) {
        hash ^= UInt64(value)
        hash = hash &* 0x100000001b3
    }

    public mutating func int(_ value: Int) {
        var v = UInt64(bitPattern: Int64(value))
        for _ in 0..<8 {
            byte(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
    }

    public mutating func uint(_ value: UInt64) {
        var v = value
        for _ in 0..<8 {
            byte(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
    }

    public mutating func bool(_ value: Bool) {
        byte(value ? 1 : 0)
    }

    public mutating func optionalInt(_ value: Int?) {
        switch value {
        case .none:
            byte(0)
        case .some(let v):
            byte(1)
            int(v)
        }
    }

    public mutating func string(_ value: String) {
        for scalar in value.unicodeScalars {
            byte(UInt8(truncatingIfNeeded: scalar.value))
            byte(UInt8(truncatingIfNeeded: scalar.value >> 8))
        }
        byte(0)
    }

    public func finish() -> UInt64 {
        hash
    }
}
