// Murmuration app — hover preview behavior (MU-P7.2).
//
// The Pencil/pointer hover preview: a pending leader path the player is
// about to commit, rendered dashed-bright but never applied to the engine.
// Split out of GameModel to keep its type body within the lint budget;
// these members widen `private` storage to internal (`private` is
// file-scoped in Swift and a cross-file extension cannot see it).

import MUCore
import MURender

extension GameModel {
    /// Advance the hover preview to a world point (the gesture handlers'
    /// shared core: begins the preview builder on the first point, extends
    /// it after). State-free by design — the preview never touches the
    /// engine, it only renders.
    public func stepPreview(to world: SIMD2<Float>) {
        let flock = previewFlock ?? 0
        if previewBuilder == nil {
            let paths = state.leaderPaths
            let path = Int(flock) < paths.count
                ? paths[Int(flock)] : LeaderPath(points: [])
            var builder = LeaderPathBuilder()
            // begin() returns a state-mutating action; the preview must
            // stay state-free, so seed the waypoints directly and discard
            // the action.
            _ = builder.begin(leaderX: path.currentX, leaderY: path.currentY, subFlock: flock)
            previewBuilder = builder
            previewFlock = flock
        } else if var builder = previewBuilder, builder.extend(to: world) != nil {
            previewBuilder = builder
        }
    }

    /// End the hover preview (gesture end, exit, or a committed drag).
    public func endPreview() {
        previewBuilder = nil
        previewFlock = nil
    }
}
