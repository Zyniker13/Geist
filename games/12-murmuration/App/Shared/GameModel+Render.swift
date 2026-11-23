// The renderer handoff and hover-preview state (MU-P7.2) live here so
// GameModel.swift stays under the 400-line type-body budget.
import Foundation

extension GameModel {
    /// The scene for the renderer: this tick against the previous one.
    var scene: RenderScene {
        makeScene(
            state: state, previousBirds: previousBirds, falconPrev: falconPrev,
            trace: trace, pendingPath: pendingPathSamples
        )
    }

    /// The hover preview path (MU-P7.2): the pending drag's waypoints as
    /// fresh trace samples, so the renderer draws it like the committed
    /// trace. Empty when nothing is being drawn.
    var pendingPathSamples: [TracePoint] {
        guard let builder = previewBuilder else { return [] }
        return builder.waypoints.map { waypoint in
            TracePoint(x: Float(waypoint.x), y: Float(waypoint.y), age: 0)
        }
    }

    /// The in-flight leader-path builder during a Pencil/pointer hover-drag
    /// (MU-P7.2). Set by the input layer; cleared on commit or cancel.
    var previewBuilder: LeaderPathBuilder?

    /// Which flock the active hover preview steers (nil = no preview).
    var previewFlock: UInt8?

    /// Scripted hover driver (MU-P7.2 test harness): a sequence of world
    /// points fed through `stepPreview(to:)` one per frame while
    /// `-uitest-preview` is active, standing in for real Pencil hover
    /// events (which XCUITest cannot synthesize). Empty when idle.
    var scriptedHover: [SIMD2<Float>] = []

    /// Last tick the hash label refreshed; -1 = never (GameModel+Hash).
    var lastHashTick = -1
}
