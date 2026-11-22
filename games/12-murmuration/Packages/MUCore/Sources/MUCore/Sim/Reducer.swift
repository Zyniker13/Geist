/// Game reducer: pure function that applies actions to GameState and produces events.
///
/// This is the core of the P1 rules engine. It applies the boid simulation,
/// leader paths, energy, falcons, and roosts in a deterministic order.
import Foundation

// MARK: - Actions (player input)

/// Player actions that modify game state.
public enum GameAction: Codable, Sendable, Equatable {
    /// Set a leader path for a sub-flock (R-3).
    case setLeaderPath(subFlock: UInt8, waypoints: [Waypoint])
    /// Split a sub-flock into two (R-3, R-4).
    case splitFlock(from: UInt8, ratio: Double)
    /// Create the rival's side at the start of a versus day (ADR-0033).
    /// Unlike a split, the new sub-flock belongs to the rival side.
    case spawnRival(ratio: Double)
    /// Condense a sub-flock (R-4).
    case condense(subFlock: UInt8)
    /// Release condense (R-4).
    case releaseCondense(subFlock: UInt8)
    /// Pause the simulation.
    case pause
    /// Resume the simulation.
    case resume
}

// MARK: - Events (game output)

/// All events produced by the rules engine.
public enum GameEvent: Codable, Sendable, Equatable, Hashable {
    /// Boid events.
    case boidStep(tick: Int, birdCount: Int)
    /// Leader path event.
    case leaderPath(subFlock: UInt8, waypointReached: Int)
    /// Energy events (from Energy.swift).
    case energy(EnergyEvent)
    /// Falcon events (from Falcon.swift).
    case falcon(FalconEvent)
    /// Roost events (from Roost.swift).
    case roost(RoostEvent)
    /// Sub-flock split.
    case split(from: UInt8, into: UInt8)
    /// Sub-flock merge (R-5).
    case merge(into: UInt8, from: UInt8)
    /// Condense event.
    case condense(subFlock: UInt8, active: Bool)
    /// Day ended.
    case dayEnd(tick: Int)
    /// Victory.
    case victory(winner: Int)
    /// Bird count changed (growth/starvation).
    case birdCountChange(delta: Int)
}

// MARK: - Reducer

/// Temporary phase profiler for P1 performance work, enabled via the
/// MU_PROFILE environment variable. Overhead when disabled is one Bool check
/// per phase; it reads no state, so determinism (INV-3) is unaffected.
public enum TickProfiler {
    public static let enabled = ProcessInfo.processInfo.environment["MU_PROFILE"] != nil
    nonisolated(unsafe) static var rebuildNs: UInt64 = 0
    nonisolated(unsafe) static var boidsNs: UInt64 = 0
    nonisolated(unsafe) static var rulesNs: UInt64 = 0
    nonisolated(unsafe) static var ticks: UInt64 = 0

    @inline(__always) static func start() -> UInt64 {
        enabled ? DispatchTime.now().uptimeNanoseconds : 0
    }

    @inline(__always) static func accumulate(_ phase: inout UInt64, _ t0: UInt64) {
        if enabled { phase &+= DispatchTime.now().uptimeNanoseconds &- t0 }
    }

    /// One-line summary of accumulated phase time (ms) and tick count.
    public static func report() -> String {
        let ms: (UInt64) -> String = { String(format: "%.1f", Double($0) / 1_000_000.0) }
        return "profile ticks=\(ticks) rebuildMs=\(ms(rebuildNs)) boidsMs=\(ms(boidsNs)) rulesMs=\(ms(rulesNs))"
    }
}

/// Apply one tick of simulation.
/// Returns (newState, events).
public func applyTick(to state: GameState, rng: inout SeededRNG) -> (GameState, [GameEvent]) {
    var state = state
    var events: [GameEvent] = []

    // 0. Regenerate the wind field every `effectiveWindRegenTicks` ticks
    // (R-1: per-256-cell seeded vectors, changing every 20 seconds at 30 Hz
    // by default; pattern branches in P3; the fog daily halves the cadence).
    if state.tick % state.effectiveWindRegenTicks == 0 {
        let generation = state.tick / state.effectiveWindRegenTicks
        let (wx, wy) = GameState.windField(
            generation: generation, seed: state.seed, windSeedOffset: state.windSeedOffset,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight,
            pattern: state.windPattern,
            strengthQ16: state.windStrengthQ16
        )
        state.windCellsX = wx
        state.windCellsY = wy
    }

    // 1. Run boid simulation (R-6, R-7).
    let boidsFrame = BoidsFrame(
        leaderX: 0, leaderY: 0,
        windXQ: 0, windYQ: 0,
        worldWidth: state.worldWidth,
        worldHeight: state.worldHeight,
        leadersX: state.leaderPaths.map { $0.attractor().x },
        leadersY: state.leaderPaths.map { $0.attractor().y },
        windCellsX: state.windCellsX,
        windCellsY: state.windCellsY,
        windGridCols: Int32(max(1, Int(state.worldWidth) / GameState.windCellSize)),
        windGridRows: Int32(max(1, Int(state.worldHeight) / GameState.windCellSize)),
        windCellSize: Int32(GameState.windCellSize),
        obstacleCenterX: state.obstacleCenterX,
        obstacleCenterY: state.obstacleCenterY,
        obstacleRadius: state.obstacleRadius
        )

    // Rebuild spatial hash.
    let tRebuild = TickProfiler.start()
    var sh = state.spatialHash
    sh.rebuild(posX: state.birds.posX, posY: state.birds.posY, count: state.birds.count)
    TickProfiler.accumulate(&TickProfiler.rebuildNs, tRebuild)

    // Step boids. R-4: an active condense doubles cohesion for its duration.
    let tBoids = TickProfiler.start()
    stepBirds(
        birds: &state.birds,
        hash: &sh,
        frame: boidsFrame,
        params: effectiveParams(state)
    )
    TickProfiler.accumulate(&TickProfiler.boidsNs, tBoids)
    if TickProfiler.enabled { TickProfiler.ticks &+= 1 }
    events.append(.boidStep(tick: state.tick, birdCount: state.birds.count))
    state.spatialHash = sh

    // 2. Advance leader paths (R-3): the leader point moves along its path at
    // the flock's max speed, then circles its last position (R-4).
    let tRules = TickProfiler.start()
    let leaderSpeed = Int32(state.boidsParams.maxSpeed >> 16)
    for sfIdx in 0..<state.leaderPaths.count {
        var path = state.leaderPaths[sfIdx]
        let reached = path.advance(speed: leaderSpeed)
        if reached {
            events.append(.leaderPath(subFlock: UInt8(sfIdx), waypointReached: path.currentTarget))
        }
        state.leaderPaths[sfIdx] = path
    }

    // 3. Energy: drain, feed, grow, starve (R-8, R-9).
    let drainEvents = computeEnergyDrain(state: &state)
    for e in drainEvents { events.append(.energy(e)) }

    let feedEvents = computeFeeding(state: &state, rng: &rng)
    for e in feedEvents { events.append(.energy(e)) }

    let growEvents = computeGrowth(state: &state, rng: &rng)
    for e in growEvents {
        events.append(.energy(e))
        switch e {
        case .grow(_, let count):
            events.append(.birdCountChange(delta: count))
        default:
            break
        }
    }

    // R-9 starvation: 1% of the flock per 10 ticks at zero energy.
    if state.tick % GameState.starvationRate == 0 {
        let starveEvents = computeStarvation(state: &state, rng: &rng)
        for e in starveEvents {
            events.append(.energy(e))
            if case .starve(_, let count) = e {
                events.append(.birdCountChange(delta: -count))
            }
        }
    }

    // 4. Falcons (R-10, R-11).
    let falconEvents = computeFalcons(state: &state, rng: &rng)
    for e in falconEvents {
        events.append(.falcon(e))
        if case .forcedSplit(let sf) = e {
            events.append(.split(from: sf, into: sf == 0 ? 1 : 0))
        }
    }

    // 5. Condense/cooldown (R-4).
    if state.condenseActive > 0 {
        state.condenseActive -= 1
        if state.condenseActive <= 0 {
            events.append(.condense(subFlock: 0, active: false))
        }
    }
    if state.condenseCooldown > 0 {
        state.condenseCooldown -= 1
    }

    // 6. Sub-flock merge (R-5).
    let mergeEvents = computeMerge(state: &state)
    events.append(contentsOf: mergeEvents)

    // 7. Roost claims during dusk (R-12) and the day-end tally (R-13).
    let roostEvents = computeRoostClaims(state: &state)
    for e in roostEvents { events.append(.roost(e)) }

    // 8. Day end check.
    TickProfiler.accumulate(&TickProfiler.rulesNs, tRules)
    state.tick += 1
    if state.tick >= GameState.dayTicks {
        events.append(.dayEnd(tick: state.tick))
        let (tallyEvents, victory) = checkVictory(state: &state)
        for e in tallyEvents { events.append(.roost(e)) }
        if let victory = victory {
            events.append(.roost(victory))
            events.append(.victory(winner: winnerOf(victory)))
        }
    }

    return (state, events)
}

/// Map a roost victory event onto the GameEvent winner encoding (0 player,
/// 1 rival).
private func winnerOf(_ event: RoostEvent) -> Int {
    if case .victory(let winner) = event { return winner }
    return -1
}

/// The boids parameters in effect for the current tick (R-4): an active
/// condense doubles cohesion for its remaining duration. Pure function so
/// the doubling is unit-testable and applies identically in- and outside
/// the reducer.
public func effectiveParams(_ state: GameState) -> BoidsParams {
    var params = state.boidsParams
    if state.condenseActive > 0 {
        params.cohWeight = Int32(clamping: Int64(params.cohWeight) * Int64(GameState.condenseCohesionMultiplier))
    }
    return params
}

/// Sub-flock merge (R-5): the sub-flock centroids must stay within 200 units
/// for 30 consecutive ticks; then all birds merge into sub-flock 0. Pure
/// function of the state so the streak is unit-testable.
public func computeMerge(state: inout GameState) -> [GameEvent] {
    var events: [GameEvent] = []
    guard state.subFlockCount > 1, !state.versusMergeSuppressed else {
        state.mergeProximityStreak = 0
        return events
    }
    let (cx0, cy0) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: 0)
    let (cx1, cy1) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: 1)
    let dx = cx0 - cx1
    let dy = cy0 - cy1
    if dx * dx + dy * dy < GameState.mergeProximity * GameState.mergeProximity {
        state.mergeProximityStreak += 1
    } else {
        state.mergeProximityStreak = 0
        return events
    }
    guard state.mergeProximityStreak >= GameState.mergeThresholdTicks else { return events }
    state.mergeProximityStreak = 0
    var merged: Set<UInt8> = []
    for i in state.subFlockAssignments.indices where state.subFlockAssignments[i] != 0 {
        let from = state.subFlockAssignments[i]
        state.subFlockAssignments[i] = 0
        state.birds.subFlock[i] = 0
        if !merged.contains(from) {
            merged.insert(from)
            events.append(.merge(into: 0, from: from))
        }
    }
    return events
}

/// Apply a player action to the game state.
/// Returns (newState, events).
public func applyAction(_ action: GameAction, to state: GameState) -> (GameState, [GameEvent]) {
    var state = state
    var events: [GameEvent] = []

    switch action {
    case .setLeaderPath(let sf, let waypoints):
        // Replace or extend the leader path for this sub-flock.
        while state.leaderPaths.count <= Int(sf) {
            state.leaderPaths.append(LeaderPath(points: []))
        }
        state.leaderPaths[Int(sf)] = LeaderPath(points: waypoints)
        events.append(.leaderPath(subFlock: sf, waypointReached: -1))

    case .spawnRival(let ratio):
        // Create the rival's side: a second sub-flock owned by the rival
        // (ADR-0033). Same bookkeeping as a split — claims rows widen, an
        // energy bucket appears, the leader path anchors at the new flock's
        // centroid — but the new sub-flock's owner is the rival.
        guard state.subFlockOwners.count == 1 else { return (state, events) }
        let newSF = UInt8(1)
        state.energy.append(800)
        for idx in state.roostClaims.indices {
            state.roostClaims[idx].append(0)
        }
        var reassigned = 0
        let fromCount = state.subFlockAssignments.count
        let targetCount = Int(Double(fromCount) * ratio)
        for i in 0..<state.subFlockAssignments.count {
            if state.subFlockAssignments[i] == 0 && reassigned < targetCount {
                state.subFlockAssignments[i] = newSF
                state.birds.subFlock[i] = newSF
                reassigned += 1
            }
        }
        let (cx, cy) = centroidOfFlock(
            birds: state.birds, assignments: state.subFlockAssignments, subFlock: newSF
        )
        state.leaderPaths.append(LeaderPath(points: [Waypoint(x: cx, y: cy)]))
        state.subFlockOwners.append(1)
        events.append(.split(from: 0, into: newSF))

    case .splitFlock(let from, let ratio):
        // The new sub-flock stays on the splitting side (ADR-0033): each
        // side may hold up to two flocks, so a side splits only while it
        // still has exactly one flock.
        let owner = state.subFlockOwners[Int(from)]
        let sideCount = state.subFlockOwners.filter { $0 == owner }.count
        guard sideCount == 1 else { return (state, events) } // Max 2 per side.
        let newSF = UInt8(state.subFlockOwners.count)
        state.energy.append(800) // New sub-flock starts at 800 energy.
        // Every roost's claim row gains a slot for the new sub-flock (R-12):
        // rows are sized to the sub-flock count and a split adds one, or the
        // dusk accrual traps with "Index out of range" (exit 133 in the G4
        // hard-tier balance sweep).
        for idx in state.roostClaims.indices {
            state.roostClaims[idx].append(0)
        }
        // Reassign some birds to the new sub-flock. The boids kernel reads
        // `birds.subFlock` while merge/energy logic reads
        // `subFlockAssignments`; both arrays must move together or the new
        // sub-flock keeps steering to the old leader point.
        var reassigned = 0
        // Split a fraction of the flock being split (not of all birds):
        // splitting the rival flock, which holds fewer birds than the
        // world total, used to strip every bird out of it.
        let fromCount = state.subFlockAssignments.filter { $0 == from }.count
        let targetCount = Int(Double(fromCount) * ratio)
        for i in 0..<state.subFlockAssignments.count {
            if state.subFlockAssignments[i] == from && reassigned < targetCount {
                state.subFlockAssignments[i] = newSF
                state.birds.subFlock[i] = newSF
                reassigned += 1
            }
        }
        // The new flock needs its own leader path anchored at its birds'
        // centroid: without one, the kernel's `leader(for:)` fallback steers
        // it toward the world origin until a driver sets a real path (the
        // versus mode has no rival driver to mask this).
        let (cx, cy) = centroidOfFlock(
            birds: state.birds, assignments: state.subFlockAssignments, subFlock: newSF
        )
        state.leaderPaths.append(LeaderPath(points: [Waypoint(x: cx, y: cy)]))
        state.subFlockOwners.append(owner)
        events.append(.split(from: from, into: newSF))

    case .condense(let sf):
        if state.condenseCooldown <= 0 {
            state.condenseActive = GameState.condenseDuration
            state.condenseCooldown = GameState.condenseCooldownDuration
            events.append(.condense(subFlock: sf, active: true))
        }

    case .releaseCondense(let sf):
        state.condenseActive = 0
        events.append(.condense(subFlock: sf, active: false))

    case .pause:
        // Pause is tracked externally; no state change here.
        break

    case .resume:
        // Resume is tracked externally; no state change here.
        break
    }

    return (state, events)
}
