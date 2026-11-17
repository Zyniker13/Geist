/// Falcon system (R-10, R-11): predatory birds that dive on sub-flocks.
///
/// Falcons patrol the world and periodically dive at the nearest sub-flock.
/// Dense flocks (density > threshold) reduce dive success.
import Foundation

/// State of a single falcon.
public struct FalconState: Codable, Sendable, Equatable, Hashable {
    /// Patrol angle in degrees (for circular patrol).
    public var patrolAngle: Double
    /// Cooldown ticks before next dive.
    public var cooldown: Int
    /// Whether currently diving.
    public var diving: Bool
    /// Dive target position.
    public var diveTargetX: Int32
    public var diveTargetY: Int32
    /// Current position (for patrol).
    public var currentX: Int32
    public var currentY: Int32

    public static func == (lhs: FalconState, rhs: FalconState) -> Bool {
        lhs.patrolAngle == rhs.patrolAngle
        && lhs.cooldown == rhs.cooldown
        && lhs.diving == rhs.diving
        && lhs.diveTargetX == rhs.diveTargetX
        && lhs.diveTargetY == rhs.diveTargetY
        && lhs.currentX == rhs.currentX
        && lhs.currentY == rhs.currentY
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(patrolAngle)
        hasher.combine(cooldown)
        hasher.combine(diving)
        hasher.combine(diveTargetX)
        hasher.combine(diveTargetY)
        hasher.combine(currentX)
        hasher.combine(currentY)
    }
}

/// Falcon events.
public enum FalconEvent: Codable, Sendable, Equatable, Hashable {
    /// Falcon starts a dive.
    case diveStart(falconIndex: Int, subFlock: UInt8)
    /// Falcon dive result: hit or missed.
    case diveResult(falconIndex: Int, subFlock: UInt8, hit: Bool)
}

/// Compute falcon behavior for this tick.
/// R-10: falcons patrol and dive at nearest sub-flock.
/// R-11: dense flocks reduce dive success.
public func computeFalcons(state: inout GameState, rng: inout SeededRNG) -> [FalconEvent] {
    var events: [FalconEvent] = []

    for (falconIdx, falcon) in state.falcons.enumerated() {
        var updatedFalcon = falcon

        // Update cooldown.
        if updatedFalcon.cooldown > 0 {
            updatedFalcon.cooldown -= 1
        }

        // If not diving and cooldown is over, consider diving.
        if !updatedFalcon.diving && updatedFalcon.cooldown <= 0 {
            // Find nearest sub-flock centroid.
            var nearestSF: Int = -1
            var nearestDist: Int32 = Int32.max
            for sf in 0..<Int(state.subFlockCount) {
                let (cx, cy) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(sf))
                let dx = cx - updatedFalcon.currentX
                let dy = cy - updatedFalcon.currentY
                let dist = dx * dx + dy * dy
                if dist < nearestDist {
                    nearestDist = dist
                    nearestSF = sf
                }
            }

            if nearestSF >= 0 && nearestDist < (Int32(GameState.diveRadius) * Int32(GameState.diveRadius) * 100) {
                // Start dive.
                updatedFalcon.diving = true
                updatedFalcon.diveTargetX = state.birds.posX[0] // approximate target
                updatedFalcon.diveTargetY = state.birds.posY[0]
                events.append(.diveStart(falconIndex: falconIdx, subFlock: UInt8(nearestSF)))

                // Check if the target flock is dense (R-11).
                let birdCount = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: UInt8(nearestSF))
                let density = birdCount / max(1, GameState.diveRadius)
                let isDense = density >= GameState.densityShield

                // Resolve dive after a short delay (simulated inline for determinism).
                let success: Bool
                if isDense {
                    // Dense flock: 50% chance of failure.
                    success = rng.next(upperBound: 2) == 0
                } else {
                    // Normal: high success rate.
                    success = rng.next(upperBound: 10) < 7
                }

                if success {
                    // Kill a bird.
                    if !state.subFlockAssignments.isEmpty {
                        let targetIdx = rng.next(upperBound: state.birds.count)
                        // Remove bird at targetIdx.
                        let removedSF = state.subFlockAssignments[targetIdx]
                        state.birds.remove(at: targetIdx)
                        state.subFlockAssignments.remove(at: targetIdx)
                        events.append(.diveResult(falconIndex: falconIdx, subFlock: removedSF, hit: true))
                    } else {
                        events.append(.diveResult(falconIndex: falconIdx, subFlock: UInt8(nearestSF), hit: false))
                    }
                } else {
                    events.append(.diveResult(falconIndex: falconIdx, subFlock: UInt8(nearestSF), hit: false))
                }

                updatedFalcon.diving = false
                updatedFalcon.cooldown = GameState.falconDiveCooldown
            }
        }

        // Patrol movement (circular).
        if !updatedFalcon.diving {
            updatedFalcon.patrolAngle += 2.0
            if updatedFalcon.patrolAngle >= 360.0 {
                updatedFalcon.patrolAngle -= 360.0
            }
            let rad = updatedFalcon.patrolAngle * Double.pi / 180.0
            let radius: Double = Double(min(state.worldWidth, state.worldHeight)) / 3
            let centerX = Double(state.worldWidth) / 2
            let centerY = Double(state.worldHeight) / 2
            updatedFalcon.currentX = Int32(centerX + radius * cos(rad))
            updatedFalcon.currentY = Int32(centerY + radius * sin(rad))
        }

        state.falcons[falconIdx] = updatedFalcon
    }

    return events
}
