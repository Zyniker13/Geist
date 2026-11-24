/// Deterministic game replay (INV-4): a seed-picked variant, a recorded action
/// list, and per-round checkpoint hashes.
///
/// "Tick" is the ply number (turn index) — Orrery is turn-based, so actions
/// replay in ply order with no clock.
public struct GameReplay: Sendable, Codable, Equatable {
    /// Content version marker for golden files.
    public static let contentVersion = "or-0.1"

    public struct TimedAction: Sendable, Codable, Equatable {
        /// The ply at which the action was taken (0-based, must equal the
        /// ply count at application time).
        public var tick: Int
        public var action: Action

        public init(tick: Int, action: Action) {
            self.tick = tick
            self.action = action
        }
    }

    public var seed: UInt64
    public var variantID: String
    public var contentVersion: String
    public var actions: [TimedAction]

    public init(
        seed: UInt64, variantID: String, contentVersion: String = GameReplay.contentVersion, actions: [TimedAction]
    ) {
        self.seed = seed
        self.variantID = variantID
        self.contentVersion = contentVersion
        self.actions = actions
    }

    /// Result of running a replay.
    public struct RunResult: Sendable, Equatable {
        public let finalState: GameState
        public let finalHash: UInt64
        /// Hash after each completed round (post-rotation checks).
        public let checkpointHashes: [UInt64]
        public let applied: Int
        public let skipped: Int
    }

    /// Run the replay. Actions are applied in the recorded order; an action
    /// whose recorded ply does not match the current ply is skipped (defensive
    /// against hand-edited files). Illegal actions are skipped, and the count
    /// is reported (golden replays must have `skipped == 0`).
    public static func run(_ replay: GameReplay, variant: Variant? = nil) -> RunResult {
        let resolvedVariant = variant ?? VariantCatalog.variant(id: replay.variantID) ?? .standard
        var state = GameStateFactory.initial(seed: replay.seed, variant: resolvedVariant)
        var applied = 0
        var skipped = 0
        var checkpoints: [UInt64] = []

        for timed in replay.actions {
            if state.result != nil { skipped += 1; continue }
            if timed.tick != applied { skipped += 1; continue }
            do {
                let (next, _) = try Reducer.apply(timed.action, to: state, variant: resolvedVariant)
                state = next
                applied += 1
            } catch {
                skipped += 1
            }
            // A checkpoint after every even ply (round boundary, post-rotation).
            if applied % 2 == 0 {
                checkpoints.append(GameStateHash.digest(state))
            }
        }

        return RunResult(
            finalState: state,
            finalHash: GameStateHash.digest(state),
            checkpointHashes: checkpoints,
            applied: applied,
            skipped: skipped
        )
    }
}

/// Seeded initial states (R-3/R-4): both players start with `variant.reserve`
/// planets, empty rings at offset 0, player 1 to move. The seed picks nothing
/// in Standard (perfect information, no luck — pillar 1); it is recorded in
/// replays for future variants with seeded setups.
public enum GameStateFactory {
    public static func initial(seed: UInt64, variant: Variant = .standard) -> GameState {
        _ = seed  // reserved for seeded variants (P5); Standard is seed-free
        let rings = variant.rings.map { spec in
            RingState(slots: spec.slots, offset: 0, speed: spec.speed)
        }
        return GameState(
            rings: rings,
            reserve: [.one: variant.reserve, .two: variant.reserve],
            captured: [.one: 0, .two: 0],
            toMove: .one,
            round: 1,
            turnInRound: 0,
            lastNudge: nil,
            variantID: variant.id,
            contentVersion: GameReplay.contentVersion,
            result: nil
        )
    }
}
