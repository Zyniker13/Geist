/// Integer trigonometry for deterministic rules math (INV-3, ADR-0002).
///
/// Rules-layer code must not use `Float`/`Double`; all angles go through this
/// table. The full circle is divided into 1024 "binary degrees" (a turn is
/// 1024 units, so wrapping is a mask). Values are Q16.16 read from a
/// precomputed table (worst-case angle error 0.18°, value error ~0.3%) and
/// are bit-identical on every platform.
import Foundation

public enum IntTrig {
    /// Binary degrees per full turn.
    public static let turns = 1024

    /// Precomputed Q16.16 sine over one turn, `table[i] = sin(2π·i/1024)·65536`.
    private static let table: [Int32] = {
        var t = [Int32](repeating: 0, count: turns)
        for i in 0..<turns {
            let radians = Double(i) * 2.0 * Double.pi / Double(turns)
            t[i] = Int32((Foundation.sin(radians) * 65536.0).rounded())
        }
        return t
    }()

    /// Sine of `angle` in binary degrees (0..1023 per turn), Q16.16.
    public static func sin(_ angle: Int32) -> Int32 {
        let index = Int(angle) & (turns - 1)
        return table[index]
    }

    /// Cosine of `angle` in binary degrees, Q16.16.
    public static func cos(_ angle: Int32) -> Int32 {
        let index = (Int(angle) + turns / 4) & (turns - 1)
        return table[index]
    }

    /// Both components of a unit vector, Q16.16, from binary degrees.
    public static func unitVector(_ angle: Int32) -> (x: Int32, y: Int32) {
        (cos(angle), sin(angle))
    }
}

/// Sine of `angle` in binary degrees (0..1023 per turn), Q16.16.
public func sinQ16(_ angle: Int32) -> Int32 {
    IntTrig.sin(angle)
}

/// Cosine of `angle` in binary degrees, Q16.16.
public func cosQ16(_ angle: Int32) -> Int32 {
    IntTrig.cos(angle)
}

/// Both components of a unit vector, Q16.16, from binary degrees.
public func unitVectorQ16(_ angle: Int32) -> (x: Int32, y: Int32) {
    IntTrig.unitVector(angle)
}
