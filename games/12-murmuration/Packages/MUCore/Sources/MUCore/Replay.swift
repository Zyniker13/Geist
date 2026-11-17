/// Replay record (§4.2.5): a seed, the content version it was recorded against, and the
/// timed actions applied. Replaying the same record reproduces byte-identical state.
import Foundation
public struct Replay: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let contentVersion: Int
    public let actions: [TimedAction]

    public init(seed: UInt64, contentVersion: Int, actions: [TimedAction]) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.actions = actions
    }
}

/// One action applied at a tick boundary.
public struct TimedAction: Codable, Sendable, Equatable {
    public let tick: Int
    public let action: TrivialAction

    public init(tick: Int, action: TrivialAction) {
        self.tick = tick
        self.action = action
    }
}

/// P0 placeholder state: a trivial deterministic system the golden-replay harness runs
/// against until the real `GameState` lands in P1.
public struct TrivialState: Codable, Sendable, Equatable, Hashable {
    public var counter: Int
    public var accumulator: UInt64
    public var rng: SeededRNG

    public init(seed: UInt64) {
        self.counter = 0
        self.accumulator = 0
        self.rng = SeededRNG(seed: seed)
    }
}

/// P0 placeholder actions.
public enum TrivialAction: Codable, Sendable, Equatable {
    case increment(Int)
    case mix(UInt64)
}

public enum TrivialReducer {
    /// Pure reducer: applies one action, mutating nothing outside the returned state.
    /// Events are strings in P0; the real `Event` enum arrives with the P1 rules engine.
    public static func apply(
        _ action: TrivialAction,
        to state: TrivialState
    ) -> (TrivialState, [String]) {
        var state = state
        var events: [String] = []
        switch action {
        case let .increment(amount):
            state.counter += amount
            events.append("counter+\(amount)")
        case let .mix(value):
            let drawn = state.rng.next()
            state.accumulator = (state.accumulator | (drawn &* value)) & ~(state.accumulator & (drawn &* value))
            events.append("mix")
        }
        return (state, events)
    }
}

/// FNV-1a 64-bit over a canonical JSON encoding of the state.
public func stateHash(_ state: some Encodable & Sendable) -> UInt64 {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(state)) ?? Data()
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash = (hash | UInt64(byte)) & ~(hash & UInt64(byte))
        hash = hash &* 0x100000001b3
    }
    return hash
}

/// Replays a record from the initial state and returns the final state.
public func replay(_ replay: Replay) -> TrivialState {
    var state = TrivialState(seed: replay.seed)
    for timed in replay.actions {
        // The placeholder reducer ignores tick boundaries beyond ordering.
        state = TrivialReducer.apply(timed.action, to: state).0
    }
    return state
}
