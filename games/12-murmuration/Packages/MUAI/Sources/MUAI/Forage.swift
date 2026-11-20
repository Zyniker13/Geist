/// Shared regrowth-aware forage scoring (P4.1).
///
/// A field regrows `richness / 5` per tick, but only after a 100-tick ramp
/// since its last feed, and every feed restarts that ramp. A flock that
/// sits on a spent field therefore harvests almost nothing: each trickle
/// of regrowth is eaten in one tick, resetting the ramp again. Both the
/// autoplayer and the rivals use this scorer to leave spent fields
/// promptly and rotate to whichever field holds the most food by arrival.
///
/// Because any gain restarts the ramp, harvesting must be pulsed: strip a
/// field's remaining food in one visit, then stand clear of it until it
/// re-arms (100-tick ramp plus refill). The scorer hands pilots a
/// `ForageDirective`: either fly to a field worth stripping, or stand off
/// from every field that is spent or regrowing so no straggler grazes and
/// restarts their ramp.
import MUCore

/// What a forage pilot should do this tick.
enum ForageDirective: Equatable, Sendable {
    /// Fly to this point (a field center) and strip it.
    case forage(Waypoint)
    /// Stand off from regrowing fields at this point until one re-arms.
    case standoff(Waypoint)
    /// Nothing to decide (no fields at all): keep the current path.
    case hold
}

/// Regrowth-aware field choice shared by the autoplayer and the rivals.
enum ForageScoring {
    /// The pilot's last forage decision, feeding the directive's
    /// commitment hysteresis: `current` is the waypoint of the last
    /// issued path (a field center or a standoff point), `standoff` the
    /// pilot's parked position, if any.
    struct PilotPrior: Equatable, Sendable {
        let current: Waypoint?
        let standoff: Waypoint?

        /// No decision has been issued yet.
        static let none = PilotPrior(current: nil, standoff: nil)
    }

    /// Ticks after a feed before a field starts regrowing again.
    static let rampTicks = 100

    /// Flock speed in units per tick (BoidsParams default maxSpeed).
    static let flockSpeed = 40

    /// Bonus for keeping the current target, in energy units. Small enough
    /// that a clearly better field still wins, large enough that two
    /// equally good fields do not make the flock oscillate.
    static let stayBonus: Int64 = 150

    /// Maximum avoid penalty, in energy units. Scaled to the food scores
    /// (a field's budget is a few hundred) so the rivals still eat: a full
    /// field near the player beats a spent field far away.
    static let avoidMaxPenalty: Int64 = 500

    /// A field is worth a strip trip only when the flock can take most of
    /// its budget in one visit: a partial harvest would restart the ramp
    /// and waste whatever the field had regrown. Expected food by arrival
    /// must reach this fraction (out of ten) of the field's full budget,
    /// unless the flock is starving and must graze whatever exists.
    static let harvestFraction = 6

    /// Energy bank below which a pilot forages whatever exists: better to
    /// restart a ramp with a partial harvest than to starve while waiting.
    static let starveBank = 100
    /// Minimum meal a starving flock will fly for. Below this the trip
    /// costs more than it feeds and grazing resets the field's regrowth
    /// ramp, so the flock waits at standoff instead (ADR-0029).
    static let starveYield = 150

    /// Extra distance beyond a field's radius that the flock's leader
    /// stands off, so no straggler grazes the field and restarts its
    /// regrowth ramp. Sized for a condensed flock (the autoplayer and
    /// rival keep the pinch on while parked; a parked cloud mills
    /// within ~200 units of its centre).
    static let standoffMargin: Int32 = 200

    /// Food a field holds by the time a flock near (`nearX`, `nearY`)
    /// arrives: what remains now, plus expected regrowth by arrival when
    /// the field has finished its ramp. Integer units of energy.
    static func expectedYield(
        _ field: FieldState, nearX: Int32, nearY: Int32
    ) -> Int64 {
        let dx = Int64(field.centerX) - Int64(nearX)
        let dy = Int64(field.centerY) - Int64(nearY)
        let dist = isqrt64(UInt64(max(0, dx * dx + dy * dy)))
        let travelTicks = dist / Int64(flockSpeed)
        var expected = Int64(field.maxDepletion - field.currentDepletion)
        if field.ticksSinceFeed >= rampTicks {
            expected += min(
                Int64(field.currentDepletion),
                Int64(field.richness / 5) * travelTicks
            )
        }
        return expected
    }

    /// Whether a field holds enough food by arrival to be worth a strip
    /// trip (`harvestFraction` of its full budget).
    static func isWorthStripping(
        _ field: FieldState, nearX: Int32, nearY: Int32
    ) -> Bool {
        expectedYield(field, nearX: nearX, nearY: nearY) * 10
            >= Int64(field.maxDepletion) * Int64(harvestFraction)
    }

    /// The fields a standoff must stay clear of: those that hold or will
    /// hold too little food to be worth a strip trip, whose ramp any
    /// grazer would restart.
    static func blockedFields(
        _ state: GameState, nearX: Int32, nearY: Int32
    ) -> [FieldState] {
        state.fields.filter { !isWorthStripping($0, nearX: nearX, nearY: nearY) }
    }

    /// Among grid points clearing every given field by at least
    /// `field.radius + standoffMargin`, the one nearest the flock; when
    /// no point clears that far, the point with the greatest clearance
    /// (ties toward the flock, then scan order — deterministic). The
    /// clearance test is a property of the layout, so a parked flock
    /// holds its point (the directive reuses a still-clear point) while
    /// the per-sortie choice keeps the wait phase's travel short
    /// (ADR-0029). Clamped into the world by construction.
    static func standoffPoint(
        clearOf fields: [FieldState],
        nearX: Int32,
        nearY: Int32,
        worldWidth: Int32,
        worldHeight: Int32
    ) -> Waypoint {
        let step = 64
        var best = Waypoint(x: Int32(max(0, min(Int64(worldWidth) - 1, Int64(nearX)))),
                            y: Int32(max(0, min(Int64(worldHeight) - 1, Int64(nearY)))))
        if fields.isEmpty { return best }
        var bestSatisfied = false
        var bestClearance = Int64.min
        var bestCentroidD2 = Int64.max
        var gy = 0
        while gy < worldHeight {
            var gx = 0
            while gx < worldWidth {
                var minClearance = Int64.max
                for field in fields {
                    let dx = Int64(gx) - Int64(field.centerX)
                    let dy = Int64(gy) - Int64(field.centerY)
                    let clearance = isqrt64(UInt64(max(0, dx * dx + dy * dy)))
                        - Int64(field.radius)
                    if clearance < minClearance { minClearance = clearance }
                }
                let cdx = Int64(gx) - Int64(nearX)
                let cdy = Int64(gy) - Int64(nearY)
                let centroidD2 = cdx * cdx + cdy * cdy
                let satisfied = minClearance >= Int64(standoffMargin)
                var better = false
                if satisfied != bestSatisfied {
                    better = satisfied
                } else if satisfied {
                    better = centroidD2 < bestCentroidD2
                } else {
                    better = minClearance > bestClearance
                        || (minClearance == bestClearance
                            && centroidD2 < bestCentroidD2)
                }
                if better {
                    bestSatisfied = satisfied
                    bestClearance = minClearance
                    bestCentroidD2 = centroidD2
                    best = Waypoint(x: Int32(gx), y: Int32(gy))
                }
                gx += step
            }
            gy += step
        }
        return best
    }

    /// Whether a standoff point is still clear of every blocked field.
    static func isClear(
        _ point: Waypoint, blocked: [FieldState]
    ) -> Bool {
        let margin = Int64(standoffMargin)
        for field in blocked {
            let dx = Int64(point.x) - Int64(field.centerX)
            let dy = Int64(point.y) - Int64(field.centerY)
            let d = isqrt64(UInt64(max(0, dx * dx + dy * dy)))
            if d < Int64(field.radius) + margin { return false }
        }
        return true
    }

    /// The forage decision for one flock: strip a field worth the trip,
    /// stand off while fields regrow, or hold. When the flock's energy
    /// bank falls below `starveBank`, it forages whatever exists instead
    /// of standing off.
    ///
    /// - Parameters:
    ///   - state: the world state.
    ///   - bank: the flock's energy bank (`state.energy[subFlock]`).
    ///   - flock: the flock's centroid and bird count (the count sizes
    ///     the trip's drain cost).
    ///   - pilot: the pilot's last issued decision (hysteresis).
    ///   - avoid: optional soft penalty applied to forage choices.
    static func directive(
        _ state: GameState,
        bank: Int,
        flock: (x: Int32, y: Int32, birds: Int),
        pilot: PilotPrior,
        avoid: (x: Int32, y: Int32, distance: Int)? = nil
    ) -> ForageDirective {
        let nearX = flock.x
        let nearY = flock.y
        let birds = flock.birds
        let current = pilot.current
        let standoff = pilot.standoff
        guard !state.fields.isEmpty else { return .hold }
        // Commitment (ADR-0029): while the pilot's current target still
        // holds a worthwhile meal, keep it. Re-deciding every tick let the
        // ranking rotate (the flock's drifting centroid changes each
        // field's trip cost), so the leader teleported between fields
        // every few ticks and the flock orbited instead of arriving.
        // Commit until the target drops below worth, then re-decide.
        if let current,
           let field = state.fields.first(where: {
               $0.centerX == current.x && $0.centerY == current.y
           }),
           isWorthStripping(field, nearX: nearX, nearY: nearY)
           || (bank < starveBank
               && field.maxDepletion > field.currentDepletion) {
            // Hold the target while it is worth a trip, or — for a
            // starving flock — while any food at all remains: abandoning
            // a half-eaten meal mid-visit wasted the trip and re-issued
            // paths every tick (ADR-0029).
            return .forage(current)
        }
        let worthies = state.fields.filter {
            isWorthStripping($0, nearX: nearX, nearY: nearY)
        }
        if let field = bestField(
            in: worthies, nearX: nearX, nearY: nearY,
            birds: birds, current: current, avoid: avoid
        ) {
            return .forage(Waypoint(x: field.centerX, y: field.centerY))
        }
        // Starving: graze what the field HOLDS now, never the regrowth
        // it would reach by arrival — nibbling a ramped crumb's trickle
        // restarts its ramp, so the counted regrowth never materialises
        // and every field stays pinned near empty (ADR-0029). With
        // nothing substantial in hand the flock stands off and lets
        // fields rebuild for a full strip.
        if bank < starveBank {
            let yielding = state.fields.filter {
                Int64($0.maxDepletion - $0.currentDepletion) >= starveYield
            }
            if let field = bestField(
                in: yielding, nearX: nearX, nearY: nearY,
                birds: birds, current: current, avoid: avoid
            ) {
                return .forage(Waypoint(x: field.centerX, y: field.centerY))
            }
        }
        // The standoff parks clear of EVERY field, worth or not: as
        // fields cross the worth threshold the blocked set changes, and
        // a point placed only against the blocked set swings across the
        // world — the flock chased the moving point over fields,
        // grazing them and restarting their regrowth ramps (ADR-0029).
        // A point clear of all fields never needs to move.
        if let standoff, isClear(standoff, blocked: state.fields) {
            return .standoff(standoff)
        }
        return .standoff(standoffPoint(
            clearOf: state.fields, nearX: nearX, nearY: nearY,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight
        ))
    }

    /// The best field to forage from, scoring food remaining now plus
    /// expected regrowth by arrival (only past the ramp), minus the trip's
    /// drain cost (R-8: 1 energy per tick per 100 birds).
    ///
    /// A field still under its regrowth ramp scores only what food it has
    /// left; a spent field that has ramped scores its expected regrowth by
    /// the time the flock arrives. The current target keeps a small
    /// hysteresis bonus. `avoid` optionally penalizes fields inside a
    /// radius of a point (the rivals avoid the player's position). Ties
    /// break toward the nearer field, then field order, deterministically.
    static func bestField(
        _ state: GameState,
        nearX: Int32,
        nearY: Int32,
        birds: Int,
        current: Waypoint?,
        avoid: (x: Int32, y: Int32, distance: Int)? = nil
    ) -> FieldState? {
        bestField(
            in: state.fields, nearX: nearX, nearY: nearY, birds: birds,
            current: current, avoid: avoid
        )
    }

    /// `bestField` over an explicit field subset (the directive scores
    /// only fields worth stripping).
    static func bestField(
        in fields: [FieldState],
        nearX: Int32,
        nearY: Int32,
        birds: Int,
        current: Waypoint?,
        avoid: (x: Int32, y: Int32, distance: Int)? = nil
    ) -> FieldState? {
        var best: FieldState?
        var bestScore = Int64.min
        var bestDist2 = Int64.max
        var bestIndex = Int.max
        for (index, field) in fields.enumerated() {
            let dx = Int64(field.centerX) - Int64(nearX)
            let dy = Int64(field.centerY) - Int64(nearY)
            let dist2 = dx * dx + dy * dy
            let dist = isqrt64(UInt64(max(0, dist2)))
            let travelTicks = dist / Int64(flockSpeed)
            var score = expectedYield(field, nearX: nearX, nearY: nearY)
            let travelCost = Int64(birds / 100) * travelTicks
            score -= travelCost
            // The hysteresis bonus applies only while the current target
            // still holds food or is regrowing; a spent field under its
            // ramp must not earn the bonus, or the flock would sit on it.
            if let current,
                current.x == field.centerX, current.y == field.centerY,
                field.maxDepletion > field.currentDepletion
                    || field.ticksSinceFeed >= rampTicks
            {
                score += stayBonus
            }
            if let avoid {
                // Soft proximity penalty: the closer the field is to the
                // avoided point, the more its score drops, so among fields
                // inside the radius the flock still prefers the one
                // farthest from the point. Scaled to food units (at most
                // `avoidMaxPenalty`): the rivals must still eat, and a full
                // field near the player beats a spent field far away.
                let adx = Int64(field.centerX) - Int64(avoid.x)
                let ady = Int64(field.centerY) - Int64(avoid.y)
                let adist = isqrt64(UInt64(max(0, adx * adx + ady * ady)))
                if adist < Int64(avoid.distance) {
                    let closeness = Int64(avoid.distance) - adist
                    score -= avoidMaxPenalty * closeness / Int64(avoid.distance)
                }
            }
            if score > bestScore
                || (score == bestScore && dist2 < bestDist2)
                || (score == bestScore && dist2 == bestDist2 && index < bestIndex) {
                bestScore = score
                bestDist2 = dist2
                bestIndex = index
                best = field
            }
        }
        return best
    }
}
