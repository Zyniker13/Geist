// Murmuration app — renderer handoff.
//
// The scene assembly and the MU-P7.2 hover-preview path samples live here
// to keep GameModel.swift's type body within the lint budget. They read
// GameModel's private members (`previousBirds`, `falconPrev`, `trace`),
// which a cross-file extension cannot see — so this file is not an
// extension: GameModel declares these members with `fileprivate(set)`
// exposure through the nested extension below (private in Swift is
// file-scoped, and the extension lives in THIS file, so the members stay
// in the class body in GameModel.swift and the extension sees them).

import MURender

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
}
