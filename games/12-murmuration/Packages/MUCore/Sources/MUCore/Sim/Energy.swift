/// Energy system (R-8, R-9): feeding, growth, and starvation.
///
/// Each sub-flock has an energy level that drains over time. Birds feed in
/// fields to restore energy. Energy above a threshold triggers growth.
/// Zero energy triggers starvation.
import Foundation

/// State of a single feeding field.
public struct FieldState: Codable, Sendable, Equatable, Hashable {
    public var centerX: Int32
    public var centerY: Int32
    public var radius: Int32
    public var richness: Int
    public var currentDepletion: Int
    public var maxDepletion: Int
    /// Ticks since last depletion (for regrowth).
    public var ticksSinceFeed: Int

    public static func == (lhs: FieldState, rhs: FieldState) -> Bool {
        lhs.centerX == rhs.centerX
        && lhs.centerY == rhs.centerY
        && lhs.radius == rhs.radius
        && lhs.richness == rhs.richness
        && lhs.currentDepletion == rhs.currentDepletion
        && lhs.maxDepletion == rhs.maxDepletion
        && lhs.ticksSinceFeed == rhs.ticksSinceFeed
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(centerX)
        hasher.combine(centerY)
        hasher.combine(radius)
        hasher.combine(richness)
        hasher.combine(currentDepletion)
        hasher.combine(maxDepletion)
        hasher.combine(ticksSinceFeed)
    }
}

/// Energy events produced by the rules engine.
public enum EnergyEvent: Codable, Sendable, Equatable, Hashable {
    /// Energy drained from a sub-flock.
    case drain(subFlock: UInt8, amount: Int)
    /// Energy gained from feeding.
    case feed(subFlock: UInt8, amount: Int, fieldIndex: Int)
    /// Growth triggered (new bird spawned).
    case grow(subFlock: UInt8, newBirds: Int)
    /// Starvation triggered (bird died).
    case starve(subFlock: UInt8, deadBirds: Int)
}

/// Compute energy drain for all sub-flocks.
/// R-8: energy drains proportional to flock size.
public func computeEnergyDrain(state: inout GameState) -> [EnergyEvent] {
    var events: [EnergyEvent] = []
    for sf in 0..<Int(state.subFlockCount) {
        let birdCount = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: UInt8(sf))
        let drain = (birdCount * GameState.energyDrainPer100) / 100
        if drain > 0 {
            state.energy[sf] = max(0, state.energy[sf] - drain)
            events.append(.drain(subFlock: UInt8(sf), amount: drain))
        }
    }
    return events
}

/// Count birds in a sub-flock.
public func countBirdsInFlock(assignments: [UInt8], subFlock: UInt8) -> Int {
    assignments.filter { $0 == subFlock }.count
}

/// Compute feeding: birds in fields gain energy.
/// R-8: each sub-flock with birds in a field feeds from it.
public func computeFeeding(state: inout GameState, rng: inout SeededRNG) -> [EnergyEvent] {
    var events: [EnergyEvent] = []

    // Check each field for birds.
    for fieldIdx in 0..<state.fields.count {
        var field = state.fields[fieldIdx]

        // Find sub-flocks with birds in this field.
        var subFlocksInField: Set<UInt8> = []
        for (birdIdx, assignment) in state.subFlockAssignments.enumerated() {
            let bx = state.birds.posX[birdIdx]
            let by = state.birds.posY[birdIdx]
            let dx = bx - field.centerX
            let dy = by - field.centerY
            if dx * dx + dy * dy <= field.radius * field.radius {
                subFlocksInField.insert(assignment)
            }
        }

        for sf in subFlocksInField {
            if field.currentDepletion < field.maxDepletion {
                // Feed: gain energy proportional to bird count and field richness.
                let birdCount = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: sf)
                let gain = min(birdCount * field.richness / 10, field.maxDepletion - field.currentDepletion)
                if gain > 0 {
                    state.energy[Int(sf)] = min(GameState.maxEnergy, state.energy[Int(sf)] + gain)
                    field.currentDepletion += gain
                    field.ticksSinceFeed = 0
                    events.append(.feed(subFlock: sf, amount: gain, fieldIndex: fieldIdx))
                }
            }
        }

        // Regrow field if depleted enough time ago.
        if field.currentDepletion > 0 {
            field.ticksSinceFeed += 1
            let regrowthRate = field.richness / 5 // per 100 ticks
            if field.ticksSinceFeed >= 100 && field.currentDepletion > 0 {
                let regrow = min(regrowthRate, field.currentDepletion)
                field.currentDepletion -= regrow
            }
        }

        state.fields[fieldIdx] = field
    }

    return events
}

/// Compute growth: energy above threshold spawns new birds.
/// R-9: every 200 energy above 600 triggers growth of 5% of flock.
public func computeGrowth(state: inout GameState, rng: inout SeededRNG) -> [EnergyEvent] {
    var events: [EnergyEvent] = []

    for sf in 0..<Int(state.subFlockCount) {
        let energy = state.energy[sf]
        if energy >= GameState.growthThreshold {
            let excess = energy - GameState.growthThreshold
            let growthCycles = excess / GameState.growthEnergyStep
            let birdCount = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: UInt8(sf))
            let newBirds = max(1, birdCount * GameState.growthBirdPercent / 100) * growthCycles

            if birdCount + newBirds <= GameState.maxBirdsPerFlock {
                // Spawn new birds near the sub-flock centroid.
                let (cx, cy) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(sf))
                for _ in 0..<newBirds {
                    let dx = Int32(rng.next(upperBound: 50)) - 25
                    let dy = Int32(rng.next(upperBound: 50)) - 25
                    let speed = state.boidsParams.minSpeed
                    let angle = Int32(rng.next(upperBound: 360))
                    let cosA = (Int64(cosLookup(angle)) * Int64(speed)) >> 16
                    let sinA = (Int64(sinLookup(angle)) * Int64(speed)) >> 16
                    state.birds.append(x: cx + dx, y: cy + dy, velXQ: Int32(cosA), velYQ: Int32(sinA), subFlock: UInt8(sf))
                    state.subFlockAssignments.append(UInt8(sf))
                }
                // Drain energy for growth.
                state.energy[sf] = max(GameState.growthThreshold, state.energy[sf] - growthCycles * GameState.growthEnergyStep)
                events.append(.grow(subFlock: UInt8(sf), newBirds: newBirds))
            }
        }
    }

    return events
}

/// Compute starvation: zero energy kills birds.
/// R-9: 1% per 10 ticks at 0 energy.
public func computeStarvation(state: inout GameState, rng: inout SeededRNG) -> [EnergyEvent] {
    var events: [EnergyEvent] = []

    for sf in 0..<Int(state.subFlockCount) {
        if state.energy[sf] <= 0 {
            let birdCount = countBirdsInFlock(assignments: state.subFlockAssignments, subFlock: UInt8(sf))
            let deathRate = birdCount / GameState.starvationRate // 1% per 10 ticks
            if deathRate > 0 {
                // Remove random birds from this flock.
                var indicesToRemove: [Int] = []
                var remaining: [(Int32, Int32, Int32, Int32)] = []
                for (i, assignment) in state.subFlockAssignments.enumerated() where UInt8(sf) == assignment {
                    if rng.next(upperBound: birdCount) < deathRate {
                        indicesToRemove.append(i)
                    } else {
                        remaining.append((state.birds.posX[i], state.birds.posY[i], state.birds.velX[i], state.birds.velY[i]))
                    }
                }

                // Rebuild the bird arrays.
                state.birds = BirdSoA(capacity: remaining.count)
                state.subFlockAssignments = state.subFlockAssignments.filter { $0 != UInt8(sf) }
                for (posX, posY, velX, velY) in remaining {
                    state.birds.append(x: posX, y: posY, velXQ: velX, velYQ: velY, subFlock: UInt8(sf))
                }

                events.append(.starve(subFlock: UInt8(sf), deadBirds: deathRate))
            }
        }
    }

    return events
}

/// Compute the centroid of a sub-flock.
public func centroidOfFlock(birds: BirdSoA, assignments: [UInt8], subFlock: UInt8) -> (x: Int32, y: Int32) {
    var sumX: Int32 = 0
    var sumY: Int32 = 0
    var count: Int32 = 0
    for (i, assignment) in assignments.enumerated() where assignment == subFlock {
        sumX += birds.posX[i]
        sumY += birds.posY[i]
        count += 1
    }
    if count == 0 { return (0, 0) }
    return (sumX / count, sumY / count)
}
