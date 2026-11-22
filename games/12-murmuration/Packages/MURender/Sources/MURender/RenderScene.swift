// Murmuration Render — the per-tick scene the game model hands the renderer.

import Foundation
import MUCore

/// A leader-trace sample: world position plus a normalized age (0 fresh,
/// 1 oldest — the renderer fades the trace out at 1).
public struct TracePoint: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var age: Float

    public init(x: Float, y: Float, age: Float) {
        self.x = x
        self.y = y
        self.age = age
    }
}

/// Everything the renderer draws for one tick. Positions are world units
/// (Int32 in the engine, widened to Float here). Bird interpolation happens
/// on the GPU between `birds` (current tick) and `previousBirds` (last tick).
public struct RenderScene {
    /// Current-tick birds.
    public var birds: BirdSoA
    /// Previous-tick birds (for interpolation; may have a different count
    /// after deaths or growth — the renderer snaps frames whose count shrank).
    public var previousBirds: BirdSoA
    /// Falcon positions this tick and last, world units.
    public var falconCur: [SIMD2<Float>]
    public var falconPrev: [SIMD2<Float>]
    /// Feeding fields (world units, from the engine state).
    public var fields: [FieldState]
    /// Roosts with their current claim state (world units, engine state).
    public var roosts: [RoostState]
    /// Leader-path trace samples (newest last).
    public var trace: [TracePoint]
    /// 0 = day, 1 = full dusk (dims the sky).
    public var duskBlend: Float
    /// The engine tick this scene was built from. Drives the wingbeat
    /// phase (MU-P6.1): every bird flaps on the same deterministic clock,
    /// phase-offset by its instance index, so a paused frame is a frozen
    /// flap and a replay reproduces the identical visual.
    public var tick: Int

    public init(
        birds: BirdSoA,
        previousBirds: BirdSoA,
        falconCur: [SIMD2<Float>],
        falconPrev: [SIMD2<Float>],
        fields: [FieldState],
        roosts: [RoostState],
        trace: [TracePoint],
        duskBlend: Float,
        tick: Int
    ) {
        self.birds = birds
        self.previousBirds = previousBirds
        self.falconCur = falconCur
        self.falconPrev = falconPrev
        self.fields = fields
        self.roosts = roosts
        self.trace = trace
        self.duskBlend = duskBlend
        self.tick = tick
    }
}
