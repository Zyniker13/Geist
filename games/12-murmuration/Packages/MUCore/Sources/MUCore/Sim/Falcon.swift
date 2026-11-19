/// Falcon system (R-10, R-11): predatory birds that dive on sub-flocks.
///
/// A falcon patrols a circle around the world center (integer trig, INV-3)
/// and periodically dives at the sub-flock whose *edge* (the flock member
/// nearest the falcon) has the lowest local neighbor density. A successful
/// dive kills the birds closest to the dive point, fewer when the area is
/// dense (R-10), and a dive through the flock's centroid region forces a
/// split (R-10). Dense flocks (average neighbor count ≥ 10) halve the dive
/// success chance (R-11).
import Foundation

/// State of a single falcon.
public struct FalconState: Codable, Sendable, Equatable, Hashable {
    /// Patrol angle in binary degrees (1024 per turn, integer trig).
    public var patrolAngle: Int32
    /// Cooldown ticks before next dive.
    public var cooldown: Int
    /// Last dive target position (the kill center).
    public var diveTargetX: Int32
    public var diveTargetY: Int32
    /// Current position (for patrol).
    public var currentX: Int32
    public var currentY: Int32

    public func hash(into hasher: inout Hasher) {
        hasher.combine(patrolAngle)
        hasher.combine(cooldown)
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
    /// The dive passed through the centroid region and forced a split (R-10).
    case forcedSplit(subFlock: UInt8)
}

/// Radius (world units) at which a falcon engages a flock's edge (R-10).
public let falconEngageRadius = 600

/// Orbit radius (world units) of a lurking falcon around the largest field
/// anchor (P3).
public let falconLurkOrbitRadius = 96

/// Compute falcon behavior for this tick.
public func computeFalcons(state: inout GameState, rng: inout SeededRNG) -> [FalconEvent] {
    var events: [FalconEvent] = []
    let lurk = state.falconBehavior == .lurk

    for falconIdx in state.falcons.indices {
        var falcon = state.falcons[falconIdx]

        if falcon.cooldown > 0 {
            falcon.cooldown -= 1
        }

        if falcon.cooldown <= 0 {
            // R-10 target selection: for each sub-flock, its edge bird is the
            // member nearest the falcon; local density there is the count of
            // same-flock birds within diveRadius. A patroller dives at the
            // lowest density (P3 R-10); a lurker dives at the closest edge.
            var bestSF = -1
            var bestEdgeIdx = -1
            var bestDensity = Int.max
            var bestEdgeDist2 = Int64.max
            for sf in 0..<Int(state.subFlockCount) {
                var edgeIdx = -1
                var edgeDist2 = Int64.max
                for i in 0..<state.birds.count where state.subFlockAssignments[i] == UInt8(sf) {
                    let dx = Int64(state.birds.posX[i]) - Int64(falcon.currentX)
                    let dy = Int64(state.birds.posY[i]) - Int64(falcon.currentY)
                    let d2 = dx * dx + dy * dy
                    if d2 < edgeDist2 {
                        edgeDist2 = d2
                        edgeIdx = i
                    }
                }
                guard edgeIdx >= 0 else { continue }
                let r2 = Int64(GameState.diveRadius) * Int64(GameState.diveRadius)
                var density = 0
                let ex = Int64(state.birds.posX[edgeIdx])
                let ey = Int64(state.birds.posY[edgeIdx])
                for j in 0..<state.birds.count where state.subFlockAssignments[j] == UInt8(sf) {
                    let dx = Int64(state.birds.posX[j]) - ex
                    let dy = Int64(state.birds.posY[j]) - ey
                    if dx * dx + dy * dy <= r2 { density += 1 }
                }
                let better = lurk
                    ? edgeDist2 < bestEdgeDist2
                        || (edgeDist2 == bestEdgeDist2 && density < bestDensity)
                    : density < bestDensity
                        || (density == bestDensity && edgeDist2 < bestEdgeDist2)
                if better {
                    bestDensity = density
                    bestSF = sf
                    bestEdgeIdx = edgeIdx
                    bestEdgeDist2 = edgeDist2
                }
            }

            // Engage only within reach of the patrol circle.
            if bestSF >= 0 && bestEdgeDist2 <= Int64(falconEngageRadius) * Int64(falconEngageRadius) {
                let targetX = state.birds.posX[bestEdgeIdx]
                let targetY = state.birds.posY[bestEdgeIdx]
                falcon.diveTargetX = targetX
                falcon.diveTargetY = targetY
                events.append(.diveStart(falconIndex: falconIdx, subFlock: UInt8(bestSF)))

                // R-11: average same-flock neighbor count within the alignment
                // radius (64), sampled deterministically over the flock.
                let density = averageNeighborDensity(state: state, subFlock: UInt8(bestSF))
                let isDense = density >= GameState.densityShield

                // R-11: dense flocks halve the success chance (0.7 → 0.35).
                let success = isDense
                    ? rng.next(upperBound: 20) < 7
                    : rng.next(upperBound: 10) < 7

                if success {
                    // R-10: kill the birds closest to the dive point, fewer in
                    // dense areas: kills = max(1, 4 - density / 8).
                    let r2 = Int64(GameState.diveRadius) * Int64(GameState.diveRadius)
                    var candidates: [(d2: Int64, idx: Int)] = []
                    for i in 0..<state.birds.count {
                        let dx = Int64(state.birds.posX[i]) - Int64(targetX)
                        let dy = Int64(state.birds.posY[i]) - Int64(targetY)
                        let d2 = dx * dx + dy * dy
                        if d2 <= r2 { candidates.append((d2, i)) }
                    }
                    let killBudget = max(1, 4 - bestDensity / 8)
                    if candidates.isEmpty {
                        events.append(.diveResult(falconIndex: falconIdx, subFlock: UInt8(bestSF), hit: false))
                    } else {
                        candidates.sort { $0.d2 == $1.d2 ? $0.idx < $1.idx : $0.d2 < $1.d2 }
                        let kills = min(candidates.count, killBudget)
                        // Remove highest bird index first so earlier indices
                        // stay valid while the arrays shrink.
                        var hitSF: UInt8 = UInt8(bestSF)
                        let victimIndices = candidates.prefix(kills).map(\.idx).sorted(by: >)
                        for idx in victimIndices {
                            hitSF = state.subFlockAssignments[idx]
                            state.birds.remove(at: idx)
                            state.subFlockAssignments.remove(at: idx)
                        }
                        events.append(.diveResult(falconIndex: falconIdx, subFlock: hitSF, hit: true))

                        // R-10: a dive through the centroid region forces a split.
                        let (cx, cy) = centroidOfFlock(birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(bestSF))
                        let cdx = Int64(targetX) - Int64(cx)
                        let cdy = Int64(targetY) - Int64(cy)
                        if cdx * cdx + cdy * cdy <= Int64(GameState.diveRadius) * Int64(GameState.diveRadius) * 4 {
                            forceSplit(state: &state, from: UInt8(bestSF))
                            events.append(.forcedSplit(subFlock: UInt8(bestSF)))
                        }
                    }
                } else {
                    events.append(.diveResult(falconIndex: falconIdx, subFlock: UInt8(bestSF), hit: false))
                }

                falcon.cooldown = GameState.falconDiveCooldown
            }
        }

        // Movement: a patroller circles the world center at
        // min(width, height) / 3; a lurker circles the largest field anchor
        // at a tight 96-unit orbit (P3 R-10). Integer trig for both.
        falcon.patrolAngle = (falcon.patrolAngle &+ 6) & Int32(IntTrig.turns - 1)
        let unit = unitVectorQ16(falcon.patrolAngle)
        if lurk {
            // Lurk anchor: the center of the field with the largest radius.
            var anchorX = state.worldWidth / 2
            var anchorY = state.worldHeight / 2
            var bestRadius: Int32 = -1
            for field in state.fields where field.radius > bestRadius {
                bestRadius = field.radius
                anchorX = field.centerX
                anchorY = field.centerY
            }
            falcon.currentX = anchorX
                + Int32((Int64(unit.x) * Int64(falconLurkOrbitRadius)) >> 16)
            falcon.currentY = anchorY
                + Int32((Int64(unit.y) * Int64(falconLurkOrbitRadius)) >> 16)
        } else {
            let radius = Int32(min(state.worldWidth, state.worldHeight)) / 3
            falcon.currentX = state.worldWidth / 2 + Int32((Int64(unit.x) * Int64(radius)) >> 16)
            falcon.currentY = state.worldHeight / 2 + Int32((Int64(unit.y) * Int64(radius)) >> 16)
        }

        state.falcons[falconIdx] = falcon
    }

    return events
}

/// Average same-flock neighbor count within the alignment radius for a
/// sub-flock, sampled deterministically (up to 32 members at a fixed stride).
/// Used for the R-11 density shield.
func averageNeighborDensity(state: GameState, subFlock: UInt8) -> Int {
    var members: [Int] = []
    members.reserveCapacity(state.birds.count)
    for i in 0..<state.birds.count where state.subFlockAssignments[i] == subFlock {
        members.append(i)
    }
    guard !members.isEmpty else { return 0 }
    let sampleCount = min(32, members.count)
    let stride = max(1, members.count / sampleCount)
    let r2 = Int64(GameState.defaultAlignRadius) * Int64(GameState.defaultAlignRadius)
    var total = 0
    var sampled = 0
    var m = 0
    while m < members.count && sampled < sampleCount {
        let i = members[m]
        let ix = Int64(state.birds.posX[i])
        let iy = Int64(state.birds.posY[i])
        var neighbors = 0
        for j in members {
            let dx = Int64(state.birds.posX[j]) - ix
            let dy = Int64(state.birds.posY[j]) - iy
            if dx * dx + dy * dy <= r2 { neighbors += 1 }
        }
        total += neighbors
        sampled += 1
        m += stride
    }
    guard sampled > 0 else { return 0 }
    return total / sampled
}

/// R-10 forced split: reassign every other member of `from` (by index order)
/// to the other sub-flock, creating it if needed (capped at 2 sub-flocks).
func forceSplit(state: inout GameState, from: UInt8) {
    let to: UInt8 = from == 0 ? 1 : 0
    if Int(to) >= state.subFlockCount {
        state.energy.append(GameState.maxEnergy / 2 + 200) // new flock starts at 700
    }
    var toggle = false
    for i in 0..<state.subFlockAssignments.count where state.subFlockAssignments[i] == from {
        if toggle { state.subFlockAssignments[i] = to }
        toggle.toggle()
    }
}
