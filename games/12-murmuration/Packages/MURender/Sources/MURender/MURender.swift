// Murmuration Render — Metal instanced bird rendering and landscape layers.
//
// The Metal shaders live in Shaders.swift (compiled at runtime); FlockRenderer.swift drives them.
// This file holds shared render-side math that needs a Swift home.

import Foundation
import MUCore
import MUContent

/// Build the `RenderScene` for one engine tick: current and previous birds
/// for interpolation, falcons, fields, roosts, the leader trace, and the
/// dusk blend for the sky dimming.
public func makeScene(
    state: GameState,
    previousBirds: BirdSoA,
    falconPrev: [SIMD2<Float>],
    trace: [TracePoint],
    pendingPath: [TracePoint] = []
) -> RenderScene {
    let day = GameState.dayTicks
    let duskSpan = day - GameState.duskStart
    let duskBlend = state.tick > GameState.duskStart
        ? Float(min(state.tick - GameState.duskStart, duskSpan)) / Float(max(duskSpan, 1))
        : 0
    return RenderScene(
        birds: state.birds,
        previousBirds: previousBirds,
        falconCur: state.falcons.map {
            SIMD2(Float($0.currentX), Float($0.currentY))
        },
        falconPrev: falconPrev,
        fields: state.fields,
        roosts: state.roosts,
        trace: trace,
        pendingPath: pendingPath,
        duskBlend: duskBlend,
        tick: state.tick
    )
}
