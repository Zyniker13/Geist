/// Replay contract (INV-4): a replay is a seed, a content version, and a list
/// of timed actions. Running it must always produce the same final-state hash.
///
/// The P0 harness runs the trivial state; P1 replaces `TrivialState` in the
/// runner with the real `GameState` reducer while keeping this contract.
public struct Replay: Sendable, Codable, Equatable {
    /// Content version marker baked into golden files.
    public static let contentVersion = "or-0.1"

    /// A single timed action.
    public struct TimedAction: Sendable, Codable, Equatable {
        public var tick: Int
        public var action: TrivialAction

        public init(tick: Int, action: TrivialAction) {
            self.tick = tick
            self.action = action
        }
    }

    public var seed: UInt64
    public var contentVersion: String
    public var actions: [TimedAction]

    public init(seed: UInt64, contentVersion: String = Replay.contentVersion, actions: [TimedAction] = []) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.actions = actions
    }

    /// Result of running a replay.
    public struct RunResult: Sendable, Equatable {
        public let finalState: TrivialState
        public let finalHash: UInt64
        public let applied: Int
        public let skipped: Int
    }

    /// Run the replay: apply actions in canonical order (tick, then insertion
    /// order within a tick — arrays preserve it). Deterministic by construction.
    public static func run(_ replay: Replay) -> RunResult {
        let sorted = replay.actions.enumerated().sorted { a, b in
            if a.element.tick != b.element.tick { return a.element.tick < b.element.tick }
            return a.offset < b.offset
        }

        var state = TrivialState(count: 0, contentVersion: replay.contentVersion)
        var applied = 0
        var skipped = 0

        for (_, timed) in sorted {
            do {
                let (next, _) = try applyTrivial(timed.action, to: state)
                state = next
                applied += 1
            } catch {
                skipped += 1
            }
        }

        return RunResult(finalState: state, finalHash: state.canonicalHash(), applied: applied, skipped: skipped)
    }
}
