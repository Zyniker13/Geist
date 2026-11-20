// Murmuration AI — the rival pilot (P2.3, tiered in P4.1).
//
// "Gentle" means the rival plays to survive, not to fight: it forages fields
// away from the player's leader point, claims a roost the player is not
// heading to, and otherwise holds a standoff. The hard constraint is R-5:
// two sub-flocks whose centroids stay within `mergeProximity` for 30
// consecutive ticks merge into flock 0 — a merged rival disappears, so the
// pilot keeps the flocks separated by a comfortable margin and flees when
// the player closes in.
//
// P4.1 adds three difficulty tiers (MU-P4.1):
// - gentle: the P2.3 pilot unchanged — survive, claim a far roost, condense.
// - normal: shorter forage and flee cadences, picks the roost that trades
//   near-rival against far-from-player, contests when it can reach one.
// - hard: fastest cadences, contests roosts regardless of standoff when it
//   has a fighting flock, and in multi-roost regions splits to contest two
//   roosts at once.
//
// Deterministic (integer arithmetic only), like the Autoplayer.

import MUCore

/// The rival pilot for sub-flock 1 (and 2 when a hard-tier split is active).
/// Value type, `Codable` for save/resume.
public struct GentleRival: Equatable, Sendable {
    /// Ticks between forage re-decisions.
    public var forageInterval: Int
    /// Ticks between centroid-proximity checks (flee decisions).
    public var fleeInterval: Int
    /// Centroid distance (squared Euclidean) that triggers a flee. R-5 merges
    /// under 200 for 30 consecutive ticks; every tier keeps a margin above
    /// that so the pilot can open the gap before the streak completes.
    public var fleeRadius: Int
    /// Distance the rival keeps from the player's leader point when picking
    /// fields and roosts.
    public var standoffDistance: Int
    /// The pilot's difficulty tier (P4.1).
    public var difficulty: RivalDifficulty

    var lastForageTick: Int
    var lastFleeCheckTick: Int
    /// The waypoint of the last issued path, if any.
    var lastTarget: Waypoint?
    /// The flock's standoff waypoint while it waits for fields to re-arm,
    /// if any.
    var lastStandoff: Waypoint?
    /// Whether this dusk already received its roost or standoff plan.
    var issuedDuskPlan: Bool
    /// Hard-tier split plan progress: 0 = none, 1 = split issued (route flock
    /// 1 to roost A next), 2 = flock 1 routed (route flock 2 to roost B next).
    var splitStage: Int
    var splitTargetA: Waypoint?
    var splitTargetB: Waypoint?

    /// The minimum birds the hard tier needs before it spends a split on
    /// contesting two roosts (MU-P4.1: "splits to contest two roosts").
    static let splitMinBirds = 500

    public init(difficulty: RivalDifficulty = .gentle) {
        self.init(
            forageInterval: Self.cadence(difficulty).forage,
            fleeInterval: Self.cadence(difficulty).flee,
            fleeRadius: Self.cadence(difficulty).fleeRadius,
            standoffDistance: Self.cadence(difficulty).standoff,
            difficulty: difficulty
        )
    }

    public init(
        forageInterval: Int,
        fleeInterval: Int,
        fleeRadius: Int,
        standoffDistance: Int,
        difficulty: RivalDifficulty = .gentle
    ) {
        self.forageInterval = forageInterval
        self.fleeInterval = fleeInterval
        self.fleeRadius = fleeRadius
        self.standoffDistance = standoffDistance
        self.difficulty = difficulty
        self.lastForageTick = Autoplayer.noTick
        self.lastFleeCheckTick = Autoplayer.noTick
        self.lastTarget = nil
        self.lastStandoff = nil
        self.issuedDuskPlan = false
        self.splitStage = 0
        self.splitTargetA = nil
        self.splitTargetB = nil
    }

    /// Per-tier cadence and standoff tunables.
    static func cadence(_ difficulty: RivalDifficulty)
        -> (forage: Int, flee: Int, fleeRadius: Int, standoff: Int)
    {
        switch difficulty {
        case .gentle: return (480, 60, 320, 640)
        case .normal: return (300, 45, 360, 520)
        case .hard: return (240, 30, 400, 380)
        }
    }

    /// The action to apply this tick, or nil.
    public mutating func action(for state: GameState) -> GameAction? {
        // No rival flock until the day-start split creates one; a wiped-out
        // flock has no centroid (centroidOfFlock would report the corner).
        guard countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 1) > 0,
            countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 0) > 0
        else { return nil }

        // A fresh day's state starts at tick 0; reset the per-day flags.
        if state.tick < GameState.duskStart {
            issuedDuskPlan = false
            splitStage = 0
            splitTargetA = nil
            splitTargetB = nil
            if lastForageTick > state.tick { lastForageTick = Autoplayer.noTick }
            if lastFleeCheckTick > state.tick { lastFleeCheckTick = Autoplayer.noTick }
        }

        if state.isDusk {
            return duskAction(state)
        }
        return dayAction(state)
    }

    // MARK: - Daytime

    private mutating func dayAction(_ state: GameState) -> GameAction? {
        if let flee = fleeIfNeeded(state) { return flee }
        return forageIfNeeded(state)
    }

    // MARK: - Dusk

    private mutating func duskAction(_ state: GameState) -> GameAction? {
        // The dusk plan is decided first: on the first dusk tick the clouds
        // can still sit near-coincident after the day-start split, and both
        // plan outcomes (a far roost, or a held standoff) open distance
        // anyway. The flee check keeps guarding the later dusk ticks.
        if !issuedDuskPlan {
            issuedDuskPlan = true
            return issueDuskPlan(state)
        }
        // Route a hard-tier split over the following ticks: split, then one
        // path per rival flock. One action per tick, like every other pilot.
        if splitStage > 0 { return continueSplitRouting(state) }

        if let flee = fleeIfNeeded(state) { return flee }

        // While holding a roost it can win, condense on cooldown (R-4).
        if state.condenseCooldown <= 0, state.condenseActive <= 0 {
            for flock in rivalFlocks(of: state) {
                let (cx, cy) = centroid(state, subFlock: flock)
                for roost in state.roosts {
                    let dx = cx - roost.centerX
                    let dy = cy - roost.centerY
                    if dx * dx + dy * dy <= roost.radius * roost.radius {
                        return .condense(subFlock: flock)
                    }
                }
            }
        }
        return nil
    }

    /// The first dusk tick's decision: which roost (if any) to claim, and at
    /// which tier's aggression. Returns the action to apply this tick.
    private mutating func issueDuskPlan(_ state: GameState) -> GameAction? {
        let (lx, ly) = playerLeaderPoint(state)
        let rivalBirds = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 1)
        let playerBirds = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 0)
        // Roosts ranked farthest-from-player first (index tiebreak keeps the
        // order deterministic for equal distances).
        let ranked = state.roosts.enumerated().sorted { a, b in
            let da = leaderDistanceSquared(a.element, lx: lx, ly: ly)
            let db = leaderDistanceSquared(b.element, lx: lx, ly: ly)
            if da != db { return da > db }
            return a.offset < b.offset
        }.map(\.element)

        switch difficulty {
        case .gentle:
            return planGentle(state, ranked: ranked, lx: lx, ly: ly)
        case .normal:
            return planNormal(state, ranked: ranked, lx: lx, ly: ly)
        case .hard:
            return planHard(
                state, ranked: ranked, leader: (x: lx, y: ly),
                rivalBirds: rivalBirds, playerBirds: playerBirds
            )
        }
    }

    /// Gentle: the farthest roost from the player's leader point, taken only
    /// when it keeps the standoff margin; otherwise hold a standoff (P2.3).
    private mutating func planGentle(
        _ state: GameState, ranked: [RoostState], lx: Int32, ly: Int32
    ) -> GameAction? {
        if let roost = ranked.first {
            let dist = leaderDistanceSquared(roost, lx: lx, ly: ly)
            if dist >= Int64(standoffDistance) * Int64(standoffDistance) {
                return route(to: roost)
            }
        }
        return holdStandoff(state)
    }

    /// Normal: pick the roost that trades far-from-player against
    /// near-rival (score = player distance − rival distance), and claim it
    /// when it stays out of the standoff margin; otherwise hold a standoff.
    private mutating func planNormal(
        _ state: GameState, ranked: [RoostState], lx: Int32, ly: Int32
    ) -> GameAction? {
        guard !ranked.isEmpty else { return holdStandoff(state) }
        let (rcx, rcy) = centroid(state, subFlock: 1)
        var best = ranked[0]
        var bestScore = Int64.min
        for roost in ranked {
            let playerDist = leaderDistanceSquared(roost, lx: lx, ly: ly)
            let rdx = Int64(roost.centerX) - Int64(rcx)
            let rdy = Int64(roost.centerY) - Int64(rcy)
            let rivalDist = rdx * rdx + rdy * rdy
            let score = playerDist - rivalDist
            if score > bestScore {
                best = roost
                bestScore = score
            }
        }
        // Contend only when the pick is far enough from the player's leader
        // point; ranked is player-distance-ordered, so a nearer pick means a
        // farther pick does not exist. Fall back to a standoff.
        let playerDist = leaderDistanceSquared(best, lx: lx, ly: ly)
        if playerDist >= Int64(standoffDistance) * Int64(standoffDistance) {
            return route(to: best)
        }
        return holdStandoff(state)
    }

    /// Hard: contest unless the flock is hopelessly outnumbered (more than
    /// 2:1 against); in multi-roost regions with a fighting flock, split so
    /// the two roosts the player is least likely to reach are both contested.
    private mutating func planHard(
        _ state: GameState, ranked: [RoostState],
        leader: (x: Int32, y: Int32),
        rivalBirds: Int, playerBirds: Int
    ) -> GameAction? {
        guard !ranked.isEmpty else { return holdStandoff(state) }
        // Hopeless: a condensing player flock that big wins the roost race;
        // hold a standoff instead of feeding birds into a lost contest.
        guard playerBirds <= 2 * rivalBirds else { return holdStandoff(state) }

        // Two roosts and a fighting flock: contest both top roosts.
        if ranked.count >= 2, rivalBirds >= Self.splitMinBirds {
            splitTargetA = Waypoint(x: ranked[0].centerX, y: ranked[0].centerY)
            splitTargetB = Waypoint(x: ranked[1].centerX, y: ranked[1].centerY)
            splitStage = 1
            return .splitFlock(from: 1, ratio: 0.5)
        }
        return route(to: ranked[0])
    }

    /// The follow-up routing for a hard-tier split: flock 1 to roost A, then
    /// flock 2 to roost B, one action per tick.
    private mutating func continueSplitRouting(_ state: GameState) -> GameAction? {
        switch splitStage {
        case 1:
            splitStage = 2
            guard let target = splitTargetA else {
                splitStage = 0
                return nil
            }
            lastTarget = target
            return .setLeaderPath(subFlock: 1, waypoints: [target])
        case 2:
            splitStage = 0
            guard let target = splitTargetB else { return nil }
            splitTargetA = nil
            splitTargetB = nil
            return .setLeaderPath(subFlock: 2, waypoints: [target])
        default:
            splitStage = 0
            return nil
        }
    }

    // MARK: - Shared decisions

    /// The rival flocks this pilot steers: flock 1 always, flock 2 when a
    /// hard-tier split created one.
    private func rivalFlocks(of state: GameState) -> [UInt8] {
        state.subFlockCount >= 3 ? [1, 2] : [1]
    }

    /// Flee when the closest rival-flock centroid drifts too close to the
    /// player's centroid (checked every `fleeInterval` ticks). Returns the
    /// action to apply, or nil.
    private mutating func fleeIfNeeded(_ state: GameState) -> GameAction? {
        guard state.tick - lastFleeCheckTick >= fleeInterval else { return nil }
        lastFleeCheckTick = state.tick
        let (pcx, pcy) = centroid(state, subFlock: 0)
        // Steer the rival flock that is closest to the player: that is the
        // one at merge risk (R-5 applies to every sub-flock pair).
        var bestFlock: UInt8?
        var bestDist = Int64.max
        for flock in rivalFlocks(of: state) {
            let (cx, cy) = centroid(state, subFlock: flock)
            let dx = Int64(cx) - Int64(pcx)
            let dy = Int64(cy) - Int64(pcy)
            let dist = dx * dx + dy * dy
            if dist < bestDist {
                bestDist = dist
                bestFlock = flock
            }
        }
        guard let flock = bestFlock,
            bestDist < Int64(fleeRadius) * Int64(fleeRadius)
        else { return nil }
        let (rcx, rcy) = centroid(state, subFlock: flock)
        let target = standoffPoint(
            state, fromX: rcx, fromY: rcy, awayFromX: pcx, awayFromY: pcy
        )
        if target == lastTarget { return nil }
        lastTarget = target
        return .setLeaderPath(subFlock: flock, waypoints: [target])
    }

    private mutating func forageIfNeeded(_ state: GameState) -> GameAction? {
        // Fleeing has priority over foraging: while a rival flock is within
        // `fleeRadius` of the player's centroid, hold the standoff path.
        // Foraging here would overwrite the flee path and steer the rival
        // back into the player (both flocks start coincident on the day's
        // first split).
        let (pcx0, pcy0) = centroid(state, subFlock: 0)
        for flock in rivalFlocks(of: state) {
            let (cx, cy) = centroid(state, subFlock: flock)
            let dx = Int64(cx) - Int64(pcx0)
            let dy = Int64(cy) - Int64(pcy0)
            if dx * dx + dy * dy < Int64(fleeRadius) * Int64(fleeRadius) {
                return nil
            }
        }
        // Re-decide every tick through the shared directive: it flies to
        // any field worth a strip trip, and stands off from regrowing
        // fields (whose ramp any grazer restarts) until one re-arms.
        let (cx, cy) = centroid(state, subFlock: 1)
        let birds = countBirdsInFlock(
            assignments: state.subFlockAssignments, subFlock: 1
        )
        let (pcx, pcy) = playerLeaderPoint(state)
        switch ForageScoring.directive(
            state,
            bank: state.energy[1],
            flock: (x: cx, y: cy, birds: birds),
            pilot: .init(current: lastTarget, standoff: lastStandoff),
            avoid: (x: pcx, y: pcy, distance: standoffDistance)
        ) {
        case .hold:
            return nil
        case .standoff(let point):
            lastForageTick = state.tick
            lastStandoff = point
            if point == lastTarget { return nil }
            lastTarget = point
            return .setLeaderPath(subFlock: 1, waypoints: [point])
        case .forage(let point):
            lastForageTick = state.tick
            lastStandoff = nil
            if point == lastTarget { return nil }
            lastTarget = point
            return .setLeaderPath(subFlock: 1, waypoints: [point])
        }
    }

    /// A point `standoffDistance` (Chebyshev) away from the player centroid,
    /// in the direction from the player through the rival, clamped into the
    /// world with a margin. Q16.16 fixed-point intermediate math.
    private func standoffPoint(
        _ state: GameState, fromX: Int32, fromY: Int32,
        awayFromX: Int32, awayFromY: Int32
    ) -> Waypoint {
        let dx = Int64(fromX) - Int64(awayFromX)
        let dy = Int64(fromY) - Int64(awayFromY)
        let mag = max(abs(dx), abs(dy))
        if mag < 64 {
            // Near-coincident centroids (the day-start split leaves the
            // clouds interleaved, so the centroid gap is scatter noise): the
            // player-to-rival direction is meaningless, so stand off +x from
            // the world center — where the day-start clouds are centered —
            // deterministically for every seed.
            let margin: Int32 = 64
            return Waypoint(
                x: min(max(state.worldWidth / 2 + Int32(standoffDistance), margin), state.worldWidth - margin),
                y: min(max(state.worldHeight / 2, margin), state.worldHeight - margin)
            )
        }
        let scale = (Int64(standoffDistance) << 16) / mag
        var tx = awayFromX + Int32(truncatingIfNeeded: (dx * scale) >> 16)
        var ty = awayFromY + Int32(truncatingIfNeeded: (dy * scale) >> 16)
        let margin: Int32 = 64
        tx = min(max(tx, margin), state.worldWidth - margin)
        ty = min(max(ty, margin), state.worldHeight - margin)
        return Waypoint(x: tx, y: ty)
    }

    /// Route the main rival flock (flock 1) to a roost center. No-op when
    /// the pilot already sent that path.
    private mutating func route(to roost: RoostState) -> GameAction? {
        let target = Waypoint(x: roost.centerX, y: roost.centerY)
        if target == lastTarget { return nil }
        lastTarget = target
        return .setLeaderPath(subFlock: 1, waypoints: [target])
    }

    private mutating func holdStandoff(_ state: GameState) -> GameAction? {
        let (rx, ry) = centroid(state, subFlock: 1)
        let (px, py) = centroid(state, subFlock: 0)
        let target = standoffPoint(
            state, fromX: rx, fromY: ry, awayFromX: px, awayFromY: py
        )
        if target != lastTarget {
            lastTarget = target
            return .setLeaderPath(subFlock: 1, waypoints: [target])
        }
        return nil
    }

    private func leaderDistanceSquared(
        _ roost: RoostState, lx: Int32, ly: Int32
    ) -> Int64 {
        let dx = Int64(roost.centerX) - Int64(lx)
        let dy = Int64(roost.centerY) - Int64(ly)
        return dx * dx + dy * dy
    }

    private func playerLeaderPoint(_ state: GameState) -> (x: Int32, y: Int32) {
        let path = state.leaderPaths[0]
        return (path.currentX, path.currentY)
    }

    private func centroid(_ state: GameState, subFlock: UInt8) -> (x: Int32, y: Int32) {
        centroidOfFlock(
            birds: state.birds,
            assignments: state.subFlockAssignments,
            subFlock: subFlock
        )
    }
}

extension GentleRival: Codable {
    private enum CodingKeys: String, CodingKey {
        case forageInterval, fleeInterval, fleeRadius, standoffDistance, difficulty
        case lastForageTick, lastFleeCheckTick, lastTarget, lastStandoff, issuedDuskPlan
        case splitStage, splitTargetA, splitTargetB
    }

    /// Legacy saves (pre-P4.1) have no `difficulty` or split-plan fields;
    /// decode them as gentle / unset.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        forageInterval = try container.decodeIfPresent(Int.self, forKey: .forageInterval) ?? 480
        fleeInterval = try container.decodeIfPresent(Int.self, forKey: .fleeInterval) ?? 60
        fleeRadius = try container.decodeIfPresent(Int.self, forKey: .fleeRadius) ?? 320
        standoffDistance = try container.decodeIfPresent(Int.self, forKey: .standoffDistance) ?? 640
        difficulty = try container.decodeIfPresent(RivalDifficulty.self, forKey: .difficulty) ?? .gentle
        lastForageTick = try container.decodeIfPresent(Int.self, forKey: .lastForageTick) ?? Autoplayer.noTick
        lastFleeCheckTick = try container.decodeIfPresent(Int.self, forKey: .lastFleeCheckTick) ?? Autoplayer.noTick
        lastTarget = try container.decodeIfPresent(Waypoint.self, forKey: .lastTarget)
        lastStandoff = try container.decodeIfPresent(Waypoint.self, forKey: .lastStandoff)
        issuedDuskPlan = try container.decodeIfPresent(Bool.self, forKey: .issuedDuskPlan) ?? false
        splitStage = try container.decodeIfPresent(Int.self, forKey: .splitStage) ?? 0
        splitTargetA = try container.decodeIfPresent(Waypoint.self, forKey: .splitTargetA)
        splitTargetB = try container.decodeIfPresent(Waypoint.self, forKey: .splitTargetB)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(forageInterval, forKey: .forageInterval)
        try container.encode(fleeInterval, forKey: .fleeInterval)
        try container.encode(fleeRadius, forKey: .fleeRadius)
        try container.encode(standoffDistance, forKey: .standoffDistance)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(lastForageTick, forKey: .lastForageTick)
        try container.encode(lastFleeCheckTick, forKey: .lastFleeCheckTick)
        try container.encode(lastTarget, forKey: .lastTarget)
        try container.encodeIfPresent(lastStandoff, forKey: .lastStandoff)
        try container.encode(issuedDuskPlan, forKey: .issuedDuskPlan)
        try container.encode(splitStage, forKey: .splitStage)
        try container.encode(splitTargetA, forKey: .splitTargetA)
        try container.encode(splitTargetB, forKey: .splitTargetB)
    }
}
