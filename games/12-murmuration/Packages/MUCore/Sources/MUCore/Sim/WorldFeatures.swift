// World features added in P3 (P3.1): wind patterns, falcon behaviors, and the
// configuration knobs for obstacles. The obstacle circles themselves are plain
// arrays on `GameState`; the avoidance math lives in the boids kernel
// (Boids.swift) so every steering path shares one implementation.
import Foundation

/// Wind-field pattern (P3 R-1). All patterns are pure integer functions of
/// (cell, generation, seed, offset) — INV-3 holds for every one.
public enum WindPattern: String, Codable, Sendable, CaseIterable {
    /// The legacy field: every cell gets its own deterministic angle at a
    /// fixed magnitude. Reproduces the pre-P3 field bit-for-bit.
    case uniform
    /// One shared angle per row of cells (the band moves with the storm).
    case shear
    /// One shared direction per generation with per-cell magnitudes from
    /// 1/8 to a full 1.0 of the base strength (patchy gusts).
    case gusts
}

/// Falcon behavior mode (P3 R-10).
public enum FalconBehavior: String, Codable, Sendable, CaseIterable {
    /// The legacy behavior: circle the world center at radius
    /// min(width, height) / 3, dive on the lowest-density flock edge.
    case patrol
    /// Circle the largest field at radius 96 and dive on the nearest bird
    /// in engage range — an ambusher defending the food source.
    case lurk
}
