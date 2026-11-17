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

// MARK: - Golden replays for the real rules engine (S1.4)

/// One game action applied at a tick boundary inside a golden replay.
public struct TimedGameAction: Codable, Sendable, Equatable {
    public let tick: Int
    public let action: GameAction

    public init(tick: Int, action: GameAction) {
        self.tick = tick
        self.action = action
    }
}

/// A golden replay record (S1.4): the world configuration, the seeded RNG,
/// the timed actions, and the final state hash the replay must reproduce.
/// The content version must match the engine's, so a behavior-affecting
/// change cannot silently pass against stale goldens.
public struct GameReplay: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let contentVersion: Int
    public let birdCount: Int
    public let worldWidth: Int32
    public let worldHeight: Int32
    public let actions: [TimedGameAction]
    public let finalHash: UInt64

    public init(
        seed: UInt64, contentVersion: Int, birdCount: Int,
        worldWidth: Int32, worldHeight: Int32,
        actions: [TimedGameAction], finalHash: UInt64
    ) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.birdCount = birdCount
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.actions = actions
        self.finalHash = finalHash
    }
}

/// The canonical world configuration golden replays run against: one field,
/// one roost, one falcon, no rival, all centered (matches Tools/sim).
public func makeGoldenWorld(birdCount: Int, seed: UInt64) -> GameState {
    let worldWidth: Int32 = 2048
    let worldHeight: Int32 = 1536
    return GameState(
        birdCount: birdCount,
        worldWidth: worldWidth,
        worldHeight: worldHeight,
        boidsParams: BoidsParams(),
        fieldRichness: [10],
        fieldRadius: [128],
        fieldCenterX: [Int32(worldWidth / 2)],
        fieldCenterY: [Int32(worldHeight / 2)],
        roostCount: 1,
        roostCenterX: [Int32(worldWidth / 2)],
        roostCenterY: [Int32(worldHeight / 2)],
        roostRadius: [128],
        falconCount: 1,
        hasRival: false,
        windSeedOffset: 0,
        seed: seed
    )
}

/// Run a golden replay to completion: applies each stored action at its tick
/// boundary (before that tick's advance), then advances the full day.
/// Throws when the record's content version is stale — a replay recorded
/// against older engine behavior must fail loudly, never replay "green"
/// against rules it was not recorded with.
public func runReplay(_ record: GameReplay, days: Int = 1) throws -> GameState {
    guard record.contentVersion == GameState.replayContentVersion else {
        throw ReplayError.staleContentVersion(record.contentVersion)
    }
    var state = makeGoldenWorld(birdCount: record.birdCount, seed: record.seed)
    var rng = SeededRNG(seed: record.seed)
    var actions = record.actions
        .sorted { $0.tick < $1.tick }
        .makeIterator()
    var pending = actions.next()
    for tick in 0..<(GameState.dayTicks * days) {
        while let timed = pending, timed.tick == tick {
            let (next, _) = applyAction(timed.action, to: state)
            state = next
            pending = actions.next()
        }
        let (next, _) = applyTick(to: state, rng: &rng)
        state = next
    }
    return state
}

public enum ReplayError: Error, Equatable {
    /// The record's content version does not match the current engine.
    case staleContentVersion(Int)
}
