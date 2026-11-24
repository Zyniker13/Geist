/// Trivial P0 state for the golden-replay harness (S0.6).
///
/// The real `GameState` (rings, planets, captures) arrives in P1 (OR-P1.x).
/// This placeholder keeps the replay contract testable from day one: a
/// counter that a recorded action can bump, hashed canonically.
public struct TrivialState: Sendable, Codable, Hashable {
    /// Number of `bump` actions applied so far.
    public var count: Int
    /// Content version stamped into the replay file.
    public var contentVersion: String

    public init(count: Int = 0, contentVersion: String = Replay.contentVersion) {
        self.count = count
        self.contentVersion = contentVersion
    }

    /// Canonical FNV-1a digest (versioned encoding).
    public func canonicalHash() -> UInt64 {
        var hasher = FNV1a()
        hasher.byte(StateHash.encodingVersion)
        hasher.int(count)
        hasher.string(contentVersion)
        return hasher.finish()
    }

    /// Hex form of `canonicalHash()`.
    public func hashHex() -> String {
        StateHash.hexDigest(canonicalHash())
    }
}

/// The P0 trivial action: bump the counter.
public enum TrivialAction: Sendable, Codable, Hashable {
    case bump
    case bumps(Int)
}

/// Errors the trivial reducer can throw.
public enum TrivialRuleError: Error, Equatable {
    /// Negative bump amounts are not actions.
    case negativeBump
}

/// Apply one trivial action. Pure: state in, new state plus an event out.
public func applyTrivial(_ action: TrivialAction, to state: TrivialState) throws -> (TrivialState, String) {
    switch action {
    case .bump:
        return (TrivialState(count: state.count + 1, contentVersion: state.contentVersion), "bumped")
    case .bumps(let n):
        guard n >= 0 else { throw TrivialRuleError.negativeBump }
        return (TrivialState(count: state.count + n, contentVersion: state.contentVersion), "bumped")
    }
}
