import Foundation
import MUCore
import MUContent

/// Deterministic driver for the five-step tutorial (P3.2).
///
/// Given the current tutorial goal and a live `GameState` sample, produces
/// the `GameAction` (if any) that should be applied this tick to move the
/// simulation toward the goal. One-shot goals (draw, split, condense) issue
/// their action exactly once; continuous goals (feed, roost) re-issue the
/// leader path every tick while the goal is incomplete.
///
/// Pure and deterministic: same goal + state → same action, so a tutorial
/// run is replayable and testable (INV-3).
public struct TutorialDriver: Sendable {
    public private(set) var drawIssued = false
    public private(set) var splitIssued = false
    public private(set) var condenseIssued = false

    public init() {}

    /// The action to apply this tick, or nil when nothing is needed.
    public mutating func action(goal: TutorialGoal, state: GameState) -> GameAction? {
        switch goal {
        case .drawPath(let minPoints):
            guard !drawIssued else { return nil }
            drawIssued = true
            return .setLeaderPath(
                subFlock: 0, waypoints: drawWaypoints(state: state, count: minPoints)
            )
        case .feed:
            return feedAction(state: state)
        case .splitFlock:
            guard !splitIssued else { return nil }
            splitIssued = true
            return .splitFlock(from: 0, ratio: 0.5)
        case .condense:
            guard !condenseIssued else { return nil }
            condenseIssued = true
            return .condense(subFlock: 0)
        case .roostTarget:
            return roostAction(state: state)
        }
    }

    // MARK: - Per-goal steering

    /// Step 1: a straight horizontal path across the sky, `count` waypoints.
    private func drawWaypoints(state: GameState, count: Int) -> [Waypoint] {
        let y = Int32(state.worldHeight / 2)
        let step = Int32(state.worldWidth) / Int32(max(count + 1, 2))
        return (0..<count).map { Waypoint(x: step * Int32($0 + 1), y: y) }
    }

    /// Step 2: steer sub-flock 0 to the richest field still holding energy.
    private func feedAction(state: GameState) -> GameAction? {
        guard let field = bestField(state: state) else { return nil }
        return .setLeaderPath(
            subFlock: 0, waypoints: [Waypoint(x: field.centerX, y: field.centerY)]
        )
    }

    /// Step 5: at dusk, steer sub-flock 0 to the first roost.
    private func roostAction(state: GameState) -> GameAction? {
        guard state.isDusk, let roost = state.roosts.first else { return nil }
        return .setLeaderPath(
            subFlock: 0, waypoints: [Waypoint(x: roost.centerX, y: roost.centerY)]
        )
    }

    /// The field with the most food remaining (maxDepletion is the total a
    /// field can give before regrowth; currentDepletion is what has been
    /// eaten so far).
    private func bestField(state: GameState) -> FieldState? {
        state.fields
            .filter { $0.maxDepletion > $0.currentDepletion }
            .max { ($0.maxDepletion - $0.currentDepletion) < ($1.maxDepletion - $1.currentDepletion) }
    }
}
