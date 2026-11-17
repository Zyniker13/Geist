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

    // 1. Run boid simulation (R-6, R-7).
    var boidsFrame = BoidsFrame(
        leaderX: 0, leaderY: 0,
        windXQ: 0, windYQ: 0,
        worldWidth: state.worldWidth,
        worldHeight: state.worldHeight
    )

    // Update leader attractors.
    for sfIdx in state.leaderPaths.indices {
        let path = state.leaderPaths[sfIdx]
        let attractor = path.attractor(for: UInt8(sfIdx), at: state.tick)
        if sfIdx == 0 {
            boidsFrame.leaderX = attractor.x
            boidsFrame.leaderY = attractor.y
        }
    }

    // Update wind (changes every 600 ticks = 20 seconds at 30 Hz).
    let windCycle = state.tick % 600
    let windAngle = Double(windCycle) * 0.1 + Double(state.windSeedOffset)
    let windMag: Double = 0.3
    boidsFrame.windXQ = Int32(cos(windAngle) * windMag * 65536)
    boidsFrame.windYQ = Int32(sin(windAngle) * windMag * 65536)
    boidsFrame.worldWidth = state.worldWidth
    boidsFrame.worldHeight = state.worldHeight

    // Rebuild spatial hash.
    let tRebuild = TickProfiler.start()
    var sh = state.spatialHash
    sh.rebuild(posX: state.birds.posX, posY: state.birds.posY, count: state.birds.count)
    TickProfiler.accumulate(&TickProfiler.rebuildNs, tRebuild)

    // Step boids.
    let tBoids = TickProfiler.start()
    stepBirds(
        birds: &state.birds,
        hash: &sh,
        frame: boidsFrame,
        params: state.boidsParams
    )
    TickProfiler.accumulate(&TickProfiler.boidsNs, tBoids)
    if TickProfiler.enabled { TickProfiler.ticks &+= 1 }
    events.append(.boidStep(tick: state.tick, birdCount: state.birds.count))

    // 2. Advance leader paths (R-3).
    let tRules = TickProfiler.start()
    for sfIdx in 0..<state.leaderPaths.count {
        var path = state.leaderPaths[sfIdx]
        let reached = path.advance(
            targetX: state.birds.posX[0],
            targetY: state.birds.posY[0],
            speed: 60
        )
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

    let starveEvents = computeStarvation(state: &state, rng: &rng)
    for e in starveEvents {
        events.append(.energy(e))
        if case .starve(_, let count) = e {
            events.append(.birdCountChange(delta: -count))
        }
    }

    // 4. Falcons (R-10, R-11).
    let falconEvents = computeFalcons(state: &state, rng: &rng)
    for e in falconEvents { events.append(.falcon(e)) }

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

    // 6. Sub-flock merge check (R-5).
    if state.subFlockCount > 1 && state.tick % GameState.mergeCheckInterval == 0 {
        // Check if sub-flocks are close enough to merge.
        var shouldMerge = false
        for sf0 in 0..<Int(state.subFlockCount) - 1 {
            for sf1 in sf0 + 1..<Int(state.subFlockCount) {
                let (cx0, cy0) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(sf0))
                let (cx1, cy1) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(sf1))
                let dx = cx0 - cx1
                let dy = cy0 - cy1
                if dx * dx + dy * dy < GameState.mergeProximity * GameState.mergeProximity {
                    shouldMerge = true
                }
            }
        }
        if shouldMerge {
            // Merge all into sub-flock 0 (R-5): one event per merged sub-flock,
            // reporting the sub-flock that was merged away.
            var merged: Set<UInt8> = []
            for i in state.subFlockAssignments.indices where state.subFlockAssignments[i] != 0 {
                let from = state.subFlockAssignments[i]
                state.subFlockAssignments[i] = 0
                if !merged.contains(from) {
                    merged.insert(from)
                    events.append(.merge(into: 0, from: from))
                }
            }
        }
    }

    // 7. Day end check.
    TickProfiler.accumulate(&TickProfiler.rulesNs, tRules)
    state.tick += 1
    if state.tick >= GameState.dayTicks {
        events.append(.dayEnd(tick: state.tick))
    }

    return (state, events)
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

    case .splitFlock(let from, let ratio):
        // Split sub-flock `from` into two.
        guard state.subFlockCount <= 2 else { return (state, events) } // Max 2 sub-flocks.
        let newSF = UInt8(state.subFlockCount)
        state.energy.append(800) // New sub-flock starts at 800 energy.
        // Reassign some birds to the new sub-flock.
        var reassigned = 0
        let targetCount = Int(Double(state.birds.count) * ratio)
        for i in 0..<state.subFlockAssignments.count {
            if state.subFlockAssignments[i] == from && reassigned < targetCount {
                state.subFlockAssignments[i] = newSF
                reassigned += 1
            }
        }
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
