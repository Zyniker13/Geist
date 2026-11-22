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

/// The multi-point forage avoid anchor (ADR-0035); lives in `ForageScoring`.
typealias AvoidPoint = ForageScoring.AvoidPoint

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
    /// Minimum player-leader distance for a dusk roost claim (squared at the
    /// comparison site): roosts nearer to the player than this are left to
    /// the player. Separate from `standoffDistance` — field avoidance and
    /// claim boldness are different dials (ADR-0035 probing). 0 = claim
    /// regardless of the player.
    public var claimGate: Int
    /// Hard-tier dusk contests are denied when the player outnumbers the
    /// rival flock by more than this ratio (`playerBirds >
    /// contestRatio * rivalBirds`). Lower ratios contest more.
    public var contestRatio: Int
    /// The minimum birds the hard tier needs before it spends a split on
    /// contesting two roosts (MU-P4.1: "splits to contest two roosts").
    public var splitMinBirds: Int
    /// The minimum birds for a day-start sustainability split (ADR-0035):
    /// a fat single flock splits once per day into two halves that strip
    /// different fields, so a side's growth is limited by the fields, not
    /// by its own flocking. 0 disables it (gentle/normal default).
    public var sustainSplit: Int
    /// The pilot's difficulty tier (P4.1).
    public var difficulty: RivalDifficulty

    /// Per-flock forage memory (ADR-0035): every flock the pilot steers
    /// re-decides forage independently, with its own last-issued target
    /// (commitment hysteresis) and standoff parking spot.
    var lastForageTickByFlock: [UInt8: Int]
    var lastFleeCheckTick: Int
    var lastTargetByFlock: [UInt8: Waypoint]
    var lastStandoffByFlock: [UInt8: Waypoint]
    /// Whether this dusk already received its roost or standoff plan.
    var issuedDuskPlan: Bool
    /// Split routing progress (the hard-tier dusk split and the ADR-0035
    /// sustainability split share it): 0 = none, 1 = split issued (route
    /// flock 1 next), 2 = flock 1 routed (route flock 2 next).
    var splitStage: Int
    var splitTargetA: Waypoint?
    var splitTargetB: Waypoint?
    /// Whether this day already spent its sustainability split (reset at
    /// each dawn).
    var sustainSplitDone: Bool
    /// The day number whose per-day flags were last reset.
    var lastResetDay: Int

    public init(difficulty: RivalDifficulty = .gentle) {
        self.init(
            forageInterval: Self.cadence(difficulty).forage,
            fleeInterval: Self.cadence(difficulty).flee,
            fleeRadius: Self.cadence(difficulty).fleeRadius,
            standoffDistance: Self.cadence(difficulty).standoff,
            sustainSplit: Self.cadence(difficulty).sustain,
            difficulty: difficulty
        )
    }

    public init(
        forageInterval: Int,
        fleeInterval: Int,
        fleeRadius: Int,
        standoffDistance: Int,
        sustainSplit: Int = 0,
        difficulty: RivalDifficulty = .gentle
    ) {
        self.forageInterval = forageInterval
        self.fleeInterval = fleeInterval
        self.fleeRadius = fleeRadius
        self.standoffDistance = standoffDistance
        self.claimGate = Self.cadence(difficulty).claimGate
        self.contestRatio = Self.cadence(difficulty).contestRatio
        self.splitMinBirds = Self.cadence(difficulty).splitMinBirds
        self.sustainSplit = sustainSplit
        self.difficulty = difficulty
        self.lastForageTickByFlock = [:]
        self.lastFleeCheckTick = Autoplayer.noTick
        self.lastTargetByFlock = [:]
        self.lastStandoffByFlock = [:]
        self.issuedDuskPlan = false
        self.splitStage = 0
        self.splitTargetA = nil
        self.splitTargetB = nil
        self.sustainSplitDone = false
        self.lastResetDay = 0
    }

    /// Per-tier cadence, standoff, and dusk-aggression tunables. The default
    /// `claimGate` equals the tier's field standoff for gentle/normal (the
    /// pre-ADR-0035 behavior, where one dial served both) and 0 for hard
    /// (contest regardless of the player's position). `sustain` is the
    /// ADR-0035 sustainability-split threshold (0 = disabled).
    static func cadence(_ difficulty: RivalDifficulty)
        -> (forage: Int, flee: Int, fleeRadius: Int, standoff: Int,
            claimGate: Int, contestRatio: Int, splitMinBirds: Int,
            sustain: Int)
    {
        switch difficulty {
        case .gentle: return (480, 60, 320, 640, 640, 2, 500, 0)
        case .normal: return (300, 45, 360, 520, 520, 2, 500, 0)
        case .hard: return (240, 30, 400, 380, 0, 2, 500, 750)
        }
    }

    /// The action to apply this tick, or nil.
    public mutating func action(for state: GameState) -> GameAction? {
        // No rival flock until the day-start split creates one; a wiped-out
        // flock has no centroid (centroidOfFlock would report the corner).
        guard countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 1) > 0,
            countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: 0) > 0
        else { return nil }

        // Reset the per-day flags once per day. Split routing spans ticks
        // within a day (one action per tick), so a per-tick reset would
        // strand the follow-up routing calls — reset only when the day
        // number advances.
        if state.tick < GameState.duskStart {
            let day = state.tick / GameState.dayTicks
            if day != lastResetDay {
                lastResetDay = day
                issuedDuskPlan = false
                splitStage = 0
                splitTargetA = nil
                splitTargetB = nil
                sustainSplitDone = false
                for (flock, tick) in lastForageTickByFlock where tick > state.tick {
                    lastForageTickByFlock[flock] = Autoplayer.noTick
                }
                if lastFleeCheckTick > state.tick { lastFleeCheckTick = Autoplayer.noTick }
            }
        }

        if state.isDusk {
            return duskAction(state)
        }
        return dayAction(state)
    }

    // MARK: - Daytime

    private mutating func dayAction(_ state: GameState) -> GameAction? {
        if let sustain = sustainIfNeeded(state) { return sustain }
        if splitStage > 0 { return continueSustainRouting(state) }
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
    /// when it clears the claim gate; otherwise hold a standoff (P2.3).
    private mutating func planGentle(
        _ state: GameState, ranked: [RoostState], lx: Int32, ly: Int32
    ) -> GameAction? {
        if let roost = ranked.first, claimable(roost, lx: lx, ly: ly) {
            return route(to: roost)
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
        // Contend only when the pick clears the claim gate; ranked is
        // player-distance-ordered, so a nearer pick means a farther pick
        // does not exist. Fall back to a standoff.
        if claimable(best, lx: lx, ly: ly) {
            return route(to: best)
        }
        return holdStandoff(state)
    }

    /// Hard: contest unless the flock is hopelessly outnumbered (the
    /// `contestRatio` guard); in multi-roost regions with a fighting flock,
    /// split so the two roosts the player is least likely to reach are both
    /// contested.
    private mutating func planHard(
        _ state: GameState, ranked: [RoostState],
        leader: (x: Int32, y: Int32),
        rivalBirds: Int, playerBirds: Int
    ) -> GameAction? {
        guard !ranked.isEmpty else { return holdStandoff(state) }
        // Hopeless: a condensing player flock that big wins the roost race;
        // hold a standoff instead of feeding birds into a lost contest.
        guard playerBirds <= contestRatio * rivalBirds else {
            return holdStandoff(state)
        }

        // Two roosts and a fighting flock: contest both top roosts. When the
        // side already fields two flocks (a falcon forcedSplit mints on the
        // struck flock's own side, ADR-0033), the day-start split action is
        // rejected by the per-side cap — route the existing flocks instead
        // of spending the dusk plan on a split that cannot apply (ADR-0035).
        if ranked.count >= 2, rivalBirds >= splitMinBirds {
            splitTargetA = Waypoint(x: ranked[0].centerX, y: ranked[0].centerY)
            splitTargetB = Waypoint(x: ranked[1].centerX, y: ranked[1].centerY)
            if rivalFlocks(of: state).count >= 2 {
                splitStage = 1
                return nil
            }
            splitStage = 1
            return .splitFlock(from: 1, ratio: 0.5)
        }
        if claimable(ranked[0], lx: leader.x, ly: leader.y) {
            return route(to: ranked[0])
        }
        return holdStandoff(state)
    }

    /// Whether a dusk roost claim passes the tier's claim gate: the roost
    /// must sit at least `claimGate` from the player's leader point (0
    /// claims regardless).
    private func claimable(_ roost: RoostState, lx: Int32, ly: Int32) -> Bool {
        leaderDistanceSquared(roost, lx: lx, ly: ly)
            >= Int64(claimGate) * Int64(claimGate)
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
            lastTargetByFlock[1] = target
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
        if target == lastTargetByFlock[flock] { return nil }
        lastTargetByFlock[flock] = target
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
        // fields (whose ramp any grazer restarts) until one re-arms. For
        // ADR-0035 splits, each flock plans its OWN forage, and every
        // avoid set holds the player's leader point plus this side's other
        // flocks' centroids — so the halves strip different fields instead
        // of re-correlating on one field and starving via R-8.
        let (pcx, pcy) = playerLeaderPoint(state)
        let flocks = rivalFlocks(of: state)
        for flock in flocks {
            let id = Int(flock)
            let (cx, cy) = centroid(state, subFlock: flock)
            let birds = countBirdsInFlock(
                assignments: state.subFlockAssignments, subFlock: flock
            )
            var avoid = [AvoidPoint(x: pcx, y: pcy, distance: standoffDistance)]
            let others = flocks.filter { $0 != flock }
            if let other = others.first {
                let (ox, oy) = centroid(state, subFlock: other)
                avoid.append(AvoidPoint(x: ox, y: oy, distance: standoffDistance))
            }
            switch ForageScoring.directive(
                state,
                bank: state.energy[id],
                flock: (x: cx, y: cy, birds: birds),
                pilot: .init(
                    current: lastTargetByFlock[flock],
                    standoff: lastStandoffByFlock[flock]
                ),
                avoid: avoid
            ) {
            case .hold:
                continue
            case .standoff(let point):
                lastForageTickByFlock[flock] = state.tick
                lastStandoffByFlock[flock] = point
                if point == lastTargetByFlock[flock] { continue }
                lastTargetByFlock[flock] = point
                return .setLeaderPath(subFlock: flock, waypoints: [point])
            case .forage(let point):
                lastForageTickByFlock[flock] = state.tick
                lastStandoffByFlock[flock] = nil
                if point == lastTargetByFlock[flock] { continue }
                lastTargetByFlock[flock] = point
                return .setLeaderPath(subFlock: flock, waypoints: [point])
            }
        }
        return nil
    }

    /// Route the main rival flock (flock 1) to a roost center. No-op when
    /// the pilot already sent that path.
    private mutating func route(to roost: RoostState) -> GameAction? {
        let target = Waypoint(x: roost.centerX, y: roost.centerY)
        if target == lastTargetByFlock[1] { return nil }
        lastTargetByFlock[1] = target
        return .setLeaderPath(subFlock: 1, waypoints: [target])
    }

    private mutating func holdStandoff(_ state: GameState) -> GameAction? {
        let (rx, ry) = centroid(state, subFlock: 1)
        let (px, py) = centroid(state, subFlock: 0)
        let target = standoffPoint(
            state, fromX: rx, fromY: ry, awayFromX: px, awayFromY: py
        )
        if target != lastTargetByFlock[1] {
            lastTargetByFlock[1] = target
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
}

extension GentleRival: Codable {
    private enum CodingKeys: String, CodingKey {
        case forageInterval, fleeInterval, fleeRadius, standoffDistance, difficulty
        case claimGate, contestRatio, splitMinBirds, sustainSplit
        case lastForageTickByFlock, lastFleeCheckTick, lastTargetByFlock
        case lastStandoffByFlock, issuedDuskPlan
        case splitStage, splitTargetA, splitTargetB, sustainSplitDone, lastResetDay
        // Legacy (pre-ADR-0035) scalar flock-1 memory; read only, never written.
        case lastForageTick, lastTarget, lastStandoff
    }

    /// Legacy saves (pre-P4.1) have no `difficulty` or split-plan fields;
    /// decode them as gentle / unset. The ADR-0035 tunables default to the
    /// decoded tier's table values so legacy saves keep that tier's behavior.
    /// A pre-ADR-0035 save's scalar flock-1 memory migrates into the
    /// per-flock dicts.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try container.decodeIfPresent(RivalDifficulty.self, forKey: .difficulty) ?? .gentle
        let table = Self.cadence(difficulty)
        forageInterval = try container.decodeIfPresent(Int.self, forKey: .forageInterval) ?? 480
        fleeInterval = try container.decodeIfPresent(Int.self, forKey: .fleeInterval) ?? 60
        fleeRadius = try container.decodeIfPresent(Int.self, forKey: .fleeRadius) ?? 320
        standoffDistance = try container.decodeIfPresent(Int.self, forKey: .standoffDistance) ?? 640
        claimGate = try container.decodeIfPresent(Int.self, forKey: .claimGate) ?? table.claimGate
        contestRatio = try container.decodeIfPresent(Int.self, forKey: .contestRatio) ?? table.contestRatio
        splitMinBirds = try container.decodeIfPresent(Int.self, forKey: .splitMinBirds) ?? table.splitMinBirds
        sustainSplit = try container.decodeIfPresent(Int.self, forKey: .sustainSplit) ?? table.sustain
        lastForageTickByFlock = try container.decodeIfPresent([UInt8: Int].self, forKey: .lastForageTickByFlock) ?? [:]
        lastFleeCheckTick = try container.decodeIfPresent(Int.self, forKey: .lastFleeCheckTick) ?? Autoplayer.noTick
        lastTargetByFlock = try container.decodeIfPresent([UInt8: Waypoint].self, forKey: .lastTargetByFlock) ?? [:]
        lastStandoffByFlock = try container.decodeIfPresent([UInt8: Waypoint].self, forKey: .lastStandoffByFlock) ?? [:]
        issuedDuskPlan = try container.decodeIfPresent(Bool.self, forKey: .issuedDuskPlan) ?? false
        splitStage = try container.decodeIfPresent(Int.self, forKey: .splitStage) ?? 0
        splitTargetA = try container.decodeIfPresent(Waypoint.self, forKey: .splitTargetA)
        splitTargetB = try container.decodeIfPresent(Waypoint.self, forKey: .splitTargetB)
        sustainSplitDone = try container.decodeIfPresent(Bool.self, forKey: .sustainSplitDone) ?? false
        lastResetDay = try container.decodeIfPresent(Int.self, forKey: .lastResetDay) ?? 0
        if lastTargetByFlock[1] == nil,
            let legacyTarget = try container.decodeIfPresent(Waypoint.self, forKey: .lastTarget) {
            lastTargetByFlock[1] = legacyTarget
        }
        if lastStandoffByFlock[1] == nil,
            let legacyStandoff = try container.decodeIfPresent(Waypoint.self, forKey: .lastStandoff) {
            lastStandoffByFlock[1] = legacyStandoff
        }
        if lastForageTickByFlock[1] == nil,
            let legacyTick = try container.decodeIfPresent(Int.self, forKey: .lastForageTick) {
            lastForageTickByFlock[1] = legacyTick
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(forageInterval, forKey: .forageInterval)
        try container.encode(fleeInterval, forKey: .fleeInterval)
        try container.encode(fleeRadius, forKey: .fleeRadius)
        try container.encode(standoffDistance, forKey: .standoffDistance)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(claimGate, forKey: .claimGate)
        try container.encode(contestRatio, forKey: .contestRatio)
        try container.encode(splitMinBirds, forKey: .splitMinBirds)
        try container.encode(sustainSplit, forKey: .sustainSplit)
        try container.encode(lastForageTickByFlock, forKey: .lastForageTickByFlock)
        try container.encode(lastFleeCheckTick, forKey: .lastFleeCheckTick)
        try container.encode(lastTargetByFlock, forKey: .lastTargetByFlock)
        try container.encode(lastStandoffByFlock, forKey: .lastStandoffByFlock)
        try container.encode(issuedDuskPlan, forKey: .issuedDuskPlan)
        try container.encode(splitStage, forKey: .splitStage)
        try container.encode(splitTargetA, forKey: .splitTargetA)
        try container.encode(splitTargetB, forKey: .splitTargetB)
        try container.encode(sustainSplitDone, forKey: .sustainSplitDone)
        try container.encode(lastResetDay, forKey: .lastResetDay)
    }
}
