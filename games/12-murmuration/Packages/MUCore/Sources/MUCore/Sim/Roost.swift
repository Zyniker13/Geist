/// Roost system (R-1, R-2, R-12, R-13): claiming roost points at dusk.
///
/// At dusk (tick >= 3900), sub-flocks compete to claim roost points.
/// The flock that reaches a roost first claims it. The rival flock also
/// competes. Victory is determined by roost claims at day end.
import Foundation

/// State of a single roost point.
public struct RoostState: Codable, Sendable, Equatable, Hashable {
    public var centerX: Int32
    public var centerY: Int32
    public var radius: Int32
    /// Claims: [player flock, rival flock].
    public var claims: [Int]
    /// Whether claimed.
    public var claimed: Bool
    /// Which flock claimed it (0 = player, 1 = rival, -1 = unclaimed).
    public var claimant: Int

    public static func == (lhs: RoostState, rhs: RoostState) -> Bool {
        lhs.centerX == rhs.centerX
        && lhs.centerY == rhs.centerY
        && lhs.radius == rhs.radius
        && lhs.claims == rhs.claims
        && lhs.claimed == rhs.claimed
        && lhs.claimant == rhs.claimant
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(centerX)
        hasher.combine(centerY)
        hasher.combine(radius)
        hasher.combine(claims)
        hasher.combine(claimed)
        hasher.combine(claimant)
    }
}

/// Roost events.
public enum RoostEvent: Codable, Sendable, Equatable, Hashable {
    /// A roost was claimed by a flock.
    case claim(roostIndex: Int, flock: Int)
    /// A flock won a roost contest.
    case won(roostIndex: Int, flock: Int)
    /// Day ended with victory/defeat.
    case dayEnd(playerFlocksWon: Int, rivalFlocksWon: Int)
    /// Victory condition met.
    case victory(winner: Int) // 0 = player, 1 = rival
}

/// Compute roost claims at dusk.
/// R-12: sub-flocks claim roosts by proximity.
/// R-13: victory determined by roost counts.
public func computeRoosts(state: inout GameState, roosts: [RoostState], rng: inout SeededRNG) -> [RoostEvent] {
    var events: [RoostEvent] = []

    guard state.isDusk else { return events }

    for (roostIdx, roost) in roosts.enumerated() {
        if roost.claimed { continue }

        // Find which sub-flock is closest to this roost.
        var nearestSF: Int = -1
        var nearestDist: Int32 = Int32.max
        for sf in 0..<Int(state.subFlockCount) {
            let (cx, cy) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(sf))
            let dx = cx - roost.centerX
            let dy = cy - roost.centerY
            let dist = dx * dx + dy * dy
            if dist < nearestDist {
                nearestDist = dist
                nearestSF = sf
            }
        }

        if nearestSF >= 0 && nearestDist <= roost.radius * roost.radius {
            // Claim the roost.
            state.roostClaims[roostIdx][nearestSF] += 1
            events.append(.claim(roostIndex: roostIdx, flock: nearestSF))
        }
    }

    return events
}

/// Check for victory at day end.
/// R-13: the flock with more roost claims wins.
/// Returns (events, victory) where events contains day-end and optional victory.
public func checkVictory(state: GameState, roosts: [RoostState]) -> ([RoostEvent], RoostEvent?) {
    // Count roosts won by each side.
    var playerWon = 0
    var rivalWon = 0

    for roost in roosts {
        if roost.claimant == 0 {
            playerWon += 1
        } else if roost.claimant == 1 {
            rivalWon += 1
        }
    }

    let dayEndEvent = RoostEvent.dayEnd(playerFlocksWon: playerWon, rivalFlocksWon: rivalWon)

    if playerWon > rivalWon {
        return ([dayEndEvent], .victory(winner: 0))
    } else if rivalWon > playerWon {
        return ([dayEndEvent], .victory(winner: 1))
    } else {
        // Tie: no victory (or could be a draw condition).
        return ([dayEndEvent], nil)
    }
}
