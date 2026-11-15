/// Replay engine (INV-5): deterministic simulation from seed + timed actions.
///
/// Ticks run 0..<21600 (one full night). A timed action applies when the clock
/// reaches its tick. At hour boundaries the sim pauses; the runner resumes by
/// choosing an upgrade (the replay must contain one, or the sim stays paused).
/// Checkpoint hashes are taken every 1,800 ticks (INV-5).
public enum Replay {
    /// Result of a full replay run.
    public struct RunResult: Sendable, Equatable {
        public let finalState: GameState
        public let checkpointHashes: [UInt64]  // hash after each 1,800-tick checkpoint
        public let actionsApplied: Int
        public let actionsSkipped: Int
    }

    /// Run a replay deterministically for up to `horizonTicks` (default: full night).
    public static func run(_ replay: ReplayData, horizonTicks: Int = 21_600, skipNightEndPause: Bool = true)
        -> RunResult
    {
        var rng = SeededRNG(seed: replay.seed)
        var state = GameState.initial(seed: replay.seed, contentVersion: replay.contentVersion)
        let sorted = replay.actions.sorted { a, b in
            if a.tick != b.tick { return a.tick < b.tick }
            return actionOrderKey(a.action) < actionOrderKey(b.action)
        }

        var applied = 0
        var skipped = 0
        var actionIndex = 0
        var checkpoints: [UInt64] = []

        // Applies every action scheduled at or before the current clock tick.
        // Called both pre-advance (mid-tick actions) and post-advance (upgrade
        // choices recorded at paused hour boundaries).
        @discardableResult
        func applyPending() -> Bool {
            var appliedAny = false
            while actionIndex < sorted.count, sorted[actionIndex].tick <= state.clock.tick {
                let timed = sorted[actionIndex]
                actionIndex += 1
                do {
                    let (next, _) = try Reducer.apply(timed.action, to: state, rng: &rng)
                    state = next
                    applied += 1
                    appliedAny = true
                } catch {
                    skipped += 1  // illegal under current state; replays are best-effort
                }
            }
            return appliedAny
        }

        while state.clock.tick < horizonTicks {
            // Apply all actions scheduled at or before the current tick.
            applyPending()

            let (next, _) = Tick.advance(state: state, rng: &rng)
            state = next

            // Checkpoint every 1,800 ticks.
            if state.clock.tick % 1_800 == 0 || state.clock.tick >= horizonTicks {
                checkpoints.append(StateHash.digest(state))
            }

            // Actions recorded at the new tick (e.g. an upgrade choice made at
            // a paused boundary) apply before the automatic fallback choice.
            applyPending()

            // Hour-boundary pauses need a choice; a replay without one stalls.
            // skipNightEndPause keeps golden replays flowing by auto-choosing
            // the first offered upgrade deterministically.
            if state.isPaused, !state.pendingOffers.isEmpty, skipNightEndPause {
                if let first = state.pendingOffers.first {
                    // Defensive: the draw guarantees a legal choice, so this
                    // cannot fail; if it ever does, keep the sim paused.
                    if let (next, _) = try? Reducer.apply(.chooseUpgrade(first.id), to: state, rng: &rng) {
                        state = next
                    }
                }
            }
        }

        return RunResult(
            finalState: state,
            checkpointHashes: checkpoints,
            actionsApplied: applied,
            actionsSkipped: skipped
        )
    }

    /// Deterministic tie-break for same-tick actions. Upgrade choices sort
    /// first: at a paused hour boundary the runner chooses the upgrade before
    /// that tick's other actions (the recording order in Tools/sim).
    static func actionOrderKey(_ action: Action) -> Int {
        switch action {
        case .chooseUpgrade: return 0
        case .pause: return 1
        case .eraseWalkway: return 2
        case .paintWalkway: return 3
        case .placeFixture: return 4
        case .moveFixture: return 5
        case .setSpeed: return 6
        case .resume: return 7
        }
    }
}
