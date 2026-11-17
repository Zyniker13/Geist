/// Roost system (R-1, R-2, R-12, R-13): dusk claims and day-end victory.
///
/// During dusk (the last 900 ticks, R-2) each roost counts the birds within
/// its radius per flock each tick and one claim point accrues to the flock
/// holding the majority (R-12). At day end each roost is claimed by the flock
/// with the most claim points, and the day's winner holds more roosts; an
/// exact tie in roosts goes to the flock with more birds alive (R-13).
import Foundation

/// State of a single roost point.
public struct RoostState: Codable, Sendable, Equatable, Hashable {
    public var centerX: Int32
    public var centerY: Int32
    public var radius: Int32
    /// Claim points accrued during dusk: [player flock, rival flock] (R-12).
    public var claims: [Int]
    /// Which flock claimed it at day end (0 = player, 1 = rival, -1 = none).
    public var claimant: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(centerX)
        hasher.combine(centerY)
        hasher.combine(radius)
        hasher.combine(claims)
        hasher.combine(claimant)
    }
}

/// Roost events.
public enum RoostEvent: Codable, Sendable, Equatable, Hashable {
    /// The majority holder of a roost changed during dusk (R-12).
    case claim(roostIndex: Int, flock: Int)
    /// A roost was claimed at day end (R-13).
    case won(roostIndex: Int, flock: Int)
    /// Day ended with the roost tally.
    case dayEnd(playerFlocksWon: Int, rivalFlocksWon: Int)
    /// Victory condition met (0 = player, 1 = rival).
    case victory(winner: Int)
}

/// Accrue dusk claim points (R-12): one point per tick to the flock holding
/// the majority of birds inside each roost's radius. Emits `.claim` when a
/// roost's majority holder changes. Player sub-flocks only until the rival
/// arrives with P4 (its birds join the same counting).
public func computeRoostClaims(state: inout GameState) -> [RoostEvent] {
    var events: [RoostEvent] = []
    guard state.isDusk else { return events }

    for roostIdx in state.roosts.indices {
        let roost = state.roosts[roostIdx]
        let r2 = Int64(roost.radius) * Int64(roost.radius)
        // Birds within the radius per player sub-flock.
        var counts = [Int](repeating: 0, count: max(2, state.subFlockCount))
        for i in 0..<state.birds.count {
            let dx = Int64(state.birds.posX[i]) - Int64(roost.centerX)
            let dy = Int64(state.birds.posY[i]) - Int64(roost.centerY)
            if dx * dx + dy * dy <= r2 {
                let sf = Int(state.subFlockAssignments[i])
                if sf < counts.count { counts[sf] += 1 }
            }
        }
        // Majority: strictly more birds than every other flock; exact ties
        // accrue nothing (deterministic).
        var majority = -1
        var best = 0
        var tie = false
        for sf in 0..<state.subFlockCount {
            if counts[sf] > best {
                best = counts[sf]
                majority = sf
                tie = false
            } else if counts[sf] == best && best > 0 {
                tie = true
            }
        }
        if majority >= 0 && !tie && best > 0 {
            // Prior majority holder (before this tick's point): exact ties count
            // as no holder, so the first accrual always emits a .claim.
            var priorLeader = -1
            var priorBest = 0
            var priorTie = false
            for sf in 0..<state.roostClaims[roostIdx].count {
                let c = state.roostClaims[roostIdx][sf]
                if c > priorBest {
                    priorBest = c
                    priorLeader = sf
                    priorTie = false
                } else if c == priorBest && c > 0 {
                    priorTie = true
                }
            }
            state.roostClaims[roostIdx][majority] += 1
            if majority != priorLeader || priorTie {
                events.append(.claim(roostIndex: roostIdx, flock: majority))
            }
        }
    }

    return events
}

/// Resolve the day (R-13): claim each roost by its claim-point leader
/// (exact point ties leave the roost unclaimed), then decide the winner by
/// roosts held, breaking ties by birds alive. Returns the events and the
/// winning flock (0 player, 1 rival), or nil when nothing is claimed.
public func checkVictory(state: inout GameState) -> ([RoostEvent], RoostEvent?) {
    var events: [RoostEvent] = []

    for roostIdx in state.roosts.indices {
        let claims = state.roostClaims[roostIdx]
        var bestIdx = -1
        var best = 0
        var tie = false
        for (idx, c) in claims.enumerated() {
            if c > best {
                best = c
                bestIdx = idx
                tie = false
            } else if c == best && c > 0 {
                tie = true
            }
        }
        if bestIdx >= 0 && !tie && best > 0 {
            state.roosts[roostIdx].claimant = bestIdx
            events.append(.won(roostIndex: roostIdx, flock: bestIdx))
        }
    }

    var playerWon = 0
    var rivalWon = 0
    for roost in state.roosts where roost.claimant >= 0 {
        if roost.claimant == 0 { playerWon += 1 } else { rivalWon += 1 }
    }
    events.append(.dayEnd(playerFlocksWon: playerWon, rivalFlocksWon: rivalWon))

    if playerWon == 0 && rivalWon == 0 {
        return (events, nil)
    }
    if playerWon > rivalWon {
        return (events, .victory(winner: 0))
    }
    if rivalWon > playerWon {
        return (events, .victory(winner: 1))
    }
    // R-13 tiebreak: more birds alive takes the day.
    let playerBirds = state.birds.count
    let rivalBirds = 0 // the rival flock arrives with P4; until then the player wins ties on birds
    if playerBirds > rivalBirds {
        return (events, .victory(winner: 0))
    }
    return (events, .victory(winner: 1))
}
