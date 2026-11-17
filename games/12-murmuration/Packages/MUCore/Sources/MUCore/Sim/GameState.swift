/// Murmuration game state: the pure, deterministic simulation state.
///
/// All state changes go through the reducer `apply(_:to:)`. No external
/// mutation is allowed. State is a value type (struct, Codable, Equatable,
/// Hashable, Sendable) so it can be checkpointed and replayed deterministically
/// (INV-3).
import Foundation

// MARK: - Game State

/// The complete simulation state for one day.
public struct GameState: Codable, Sendable, Equatable {
    /// Bird positions and velocities (struct-of-arrays).
    public var birds: BirdSoA

    /// Spatial hash for neighbor queries (R-7).
    public var spatialHash: SpatialHash

    /// Current tick (0–4799). 0–3899 = day; 3900–4799 = dusk.
    public var tick: Int

    /// Total ticks in a day (R-2).
    public static let dayTicks = 4800
    /// Dusk starts at the last 900 ticks (R-2).
    public static let duskStart = 3900

    /// Whether we are in the dusk phase.
    public var isDusk: Bool { tick >= GameState.duskStart }

    /// Active leader paths per sub-flock (R-3).
    public var leaderPaths: [LeaderPath]

    /// Sub-flock assignments for each bird (index-aligned with BirdSoA).
    public var subFlockAssignments: [UInt8]

    /// Energy per sub-flock (R-8).
    public var energy: [Int]

    /// Maximum energy per sub-flock (R-8).
    public static let maxEnergy = 1000

    /// Field states: depletion and regrowth (R-8).
    public var fields: [FieldState]

    /// Roost claim points per sub-flock (R-12).
    public var roostClaims: [[Int]]

    /// Falcon states (R-10).
    public var falcons: [FalconState]

    /// Condense cooldown timer (R-4).
    public var condenseCooldown: Int

    /// Condense active timer (R-4).
    public var condenseActive: Int

    /// Cohesion multiplier when condensing (R-4).
    public static let condenseCohesionMultiplier = 2

    /// Number of ticks the centroid must stay within range to merge (R-5).
    public static let mergeThresholdTicks = 30

    /// Merge proximity threshold in world units (R-5).
    public static let mergeProximity = 200

    /// Maximum birds per flock (R-5 / ADR-0005).
    public static let maxBirdsPerFlock = 3000

    /// Number of sub-flocks (capped at 2 for two-finger split).
    public var subFlockCount: Int {
        guard let maxSF = subFlockAssignments.max() else { return 1 }
        return Int(maxSF) + 1
    }

    /// Seed for deterministic simulation.
    public let seed: UInt64

    /// Content version for golden replays.
    public let contentVersion: Int

    /// Initial bird count for this state (for growth/starvation tracking).
    public let initialBirdCount: Int

    /// Wind seed offset for this region.
    public let windSeedOffset: Int

    /// World dimensions (R-1).
    public let worldWidth: Int32
    public let worldHeight: Int32

    /// Boids parameters (weights from balance.json, R-6).
    public let boidsParams: BoidsParams

    /// Number of falcons for this region.
    public let falconCount: Int

    /// Rival flock flag.
    public let hasRival: Bool

    /// Energy drain per 100 birds per tick (R-8).
    public static let energyDrainPer100 = 1

    /// Growth threshold: every 200 energy above 600 triggers growth (R-9).
    public static let growthThreshold = 600
    public static let growthEnergyStep = 200
    public static let growthBirdPercent = 5 // percent

    /// Starvation rate: 1% per 10 ticks at 0 energy (R-9).
    public static let starvationRate = 10 // ticks per 1%

    /// Falcon dive radius (R-10).
    public static let diveRadius = 30

    /// Density shield threshold (R-11).
    public static let densityShield = 10

    /// Falcon dive success reduction in dense flocks (R-11).
    public static let denseFlockDiveReduction = 0.5

    /// Leader path sampling interval in ticks (R-3).
    public static let leaderPathSampleInterval = 1

    /// Falcon cooldown between dives in ticks (R-10).
    public static let falconDiveCooldown = 120

    /// Falcon patrol speed in world units per tick (R-10).
    public static let falconPatrolSpeed = 60 // Q16.16 → ~60 units/tick

    /// Sub-flock merge proximity check interval (R-5).
    public static let mergeCheckInterval = 30

    /// Condense duration in ticks (R-4).
    public static let condenseDuration = 60

    /// Condense cooldown duration in ticks (R-4).
    public static let condenseCooldownDuration = 120

    public init(
        birdCount: Int,
        worldWidth: Int32,
        worldHeight: Int32,
        boidsParams: BoidsParams,
        fieldRichness: [Int],
        fieldRadius: [Int],
        fieldCenterX: [Int32],
        fieldCenterY: [Int32],
        roostCount: Int,
        roostCenterX: [Int32],
        roostCenterY: [Int32],
        roostRadius: [Int],
        falconCount: Int,
        hasRival: Bool,
        windSeedOffset: Int,
        seed: UInt64,
        contentVersion: Int = 1
    ) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.boidsParams = boidsParams
        self.falconCount = falconCount
        self.hasRival = hasRival
        self.windSeedOffset = windSeedOffset

        // Initialize birds: spread in a cluster near center.
        var rng = SeededRNG(seed: seed)
        let centerX = worldWidth / 2
        let centerY = worldHeight / 2
        var birds = BirdSoA(capacity: birdCount)
        var subFlockAssignments: [UInt8] = []
        subFlockAssignments.reserveCapacity(birdCount)

        for _ in 0..<birdCount {
            let dx = Int32(rng.next(upperBound: 200)) - 100
            let dy = Int32(rng.next(upperBound: 200)) - 100
            let x = centerX + dx
            let y = centerY + dy

            // Random initial velocity (Q16.16).
            let speed = Int32(rng.next(upperBound: Int(boidsParams.maxSpeed - boidsParams.minSpeed) + 1)) + boidsParams.minSpeed
            let angle = Int32(rng.next(upperBound: 360))
            let cosA = (Int64(cosLookup(angle)) * Int64(speed)) >> 16
            let sinA = (Int64(sinLookup(angle)) * Int64(speed)) >> 16

            let sf: UInt8 = 0
            birds.append(x: x, y: y, velXQ: Int32(cosA), velYQ: Int32(sinA), subFlock: sf)
            subFlockAssignments.append(sf)
        }

        self.birds = birds
        self.spatialHash = SpatialHash(
            width: worldWidth,
            height: worldHeight,
            cellSize: 96 // R-6: cohesion radius
        )
        self.tick = 0
        self.leaderPaths = [LeaderPath(points: [])]
        self.subFlockAssignments = subFlockAssignments
        self.energy = Array(repeating: 800, count: 1) // start at 800 energy
        self.initialBirdCount = birdCount

        // Initialize fields (R-8).
        var fields: [FieldState] = []
        for i in 0..<fieldRichness.count {
            fields.append(FieldState(
                centerX: fieldCenterX[i],
                centerY: fieldCenterY[i],
                radius: Int32(fieldRadius[i]),
                richness: fieldRichness[i],
                currentDepletion: 0,
                maxDepletion: fieldRichness[i] * 10,
                ticksSinceFeed: 0
            ))
        }
        self.fields = fields

        // Initialize roosts (R-12).
        var roostClaims: [[Int]] = []
        for _ in 0..<roostCount {
            roostClaims.append([0, 0]) // [player flock, rival flock]
        }
        self.roostClaims = roostClaims

        // Initialize falcons (R-10).
        var falcons: [FalconState] = []
        for i in 0..<falconCount {
            falcons.append(FalconState(
                patrolAngle: Double(i) * (360.0 / Double(max(falconCount, 1))),
                cooldown: 0,
                diving: false,
                diveTargetX: 0,
                diveTargetY: 0,
                currentX: centerX,
                currentY: centerY
            ))
        }
        self.falcons = falcons

        self.condenseCooldown = 0
        self.condenseActive = 0
    }

    public static func == (lhs: GameState, rhs: GameState) -> Bool {
        lhs.tick == rhs.tick
        && lhs.seed == rhs.seed
        && lhs.contentVersion == rhs.contentVersion
        && lhs.birds.count == rhs.birds.count
        && lhs.birds.posX == rhs.birds.posX
        && lhs.birds.posY == rhs.birds.posY
        && lhs.birds.velX == rhs.birds.velX
        && lhs.birds.velY == rhs.birds.velY
        && lhs.birds.subFlock == rhs.birds.subFlock
        && lhs.subFlockAssignments == rhs.subFlockAssignments
        && lhs.energy == rhs.energy
        && lhs.leaderPaths == rhs.leaderPaths
        && lhs.fields == rhs.fields
        && lhs.roostClaims == rhs.roostClaims
        && lhs.falcons == rhs.falcons
        && lhs.condenseCooldown == rhs.condenseCooldown
        && lhs.condenseActive == rhs.condenseActive
    }
}

// MARK: - Helpers

/// Simple trigonometric lookup for initial bird velocities.
/// Returns cos(angle) * 65536 as Q16.16.
func cosLookup(_ angle: Int32) -> Int32 {
    // Approximate cosine using a small table.
    let a = angle % 360
    switch a {
    case 0: return 65536
    case 45: return 46340
    case 90: return 0
    case 135: return -46340
    case 180: return -65536
    case 225: return -46340
    case 270: return 0
    case 315: return 46340
    default:
        // Linear interpolation between table entries.
        let base = (a / 45) * 45
        let frac = Int64(a - base) * 46340 / 45
        let baseVal = cosLookup(base)
        return baseVal - Int32(frac)
    }
}

/// Simple sine lookup.
func sinLookup(_ angle: Int32) -> Int32 {
    cosLookup((angle + 270) % 360)
}
