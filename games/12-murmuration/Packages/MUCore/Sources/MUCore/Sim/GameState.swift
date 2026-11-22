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

    /// Side owner of each sub-flock: 0 = player side, 1 = rival side (ADR-0033).
    /// Index-aligned with `leaderPaths`, `energy` and the roost-claims rows.
    /// Every mechanism that creates or reassigns a sub-flock must respect
    /// this: a falcon forced split moves birds only within their side, a
    /// split only extends its own side, and the day-end roost tally counts
    /// claims by this table instead of by flock index.
    public var subFlockOwners: [UInt8]

    /// Energy per sub-flock (R-8).
    public var energy: [Int]

    /// Maximum energy per sub-flock (R-8).
    public static let maxEnergy = 1000

    /// Field states: depletion and regrowth (R-8).
    public var fields: [FieldState]

    /// Roost claim points per sub-flock (R-12).
    public var roostClaims: [[Int]]

    /// Roost points owned by the state (R-1, R-12): position, radius, and
    /// day-end claimant.
    public var roosts: [RoostState]

    /// Consecutive ticks the sub-flock centroids have been within
    /// `mergeProximity` (R-5): the merge fires after `mergeThresholdTicks`.
    public var mergeProximityStreak: Int

    /// Versus and rival modes suppress the R-5 auto-merge (MU-P3.3, MU-P4.1):
    /// the day-start split defines the two flocks, and both start coincident
    /// at the world center — the proximity rule would collapse them back into
    /// one flock within 30 ticks. In versus that merges the two players; in
    /// rival mode it would absorb the rival's flock into the player's.
    public var versusMergeSuppressed: Bool

    /// Wind vectors per 256-unit cell, row-major (R-1). Regenerated
    /// deterministically every 600 ticks (20 s at 30 Hz) from the region seed.
    public var windCellsX: [Int32]
    public var windCellsY: [Int32]

    /// Wind cell edge in world units (R-1).
    public static let windCellSize = 256

    /// Ticks between wind-field regenerations (R-1: every 20 seconds = 600
    /// ticks at 30 Hz).
    public static let windRegenTicks = 600

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

    /// Content version for golden replays. Bump whenever an engine change
    /// alters replay outcomes, then regenerate the committed goldens.
    /// v4: P3 world features — obstacle circles, wind patterns, and falcon
    /// behavior modes joined the state (all with defaults that reproduce the
    /// v3 legacy field, but the JSON encoding grew, so hashes change).
    /// v5: P3.2 solo objective — `soloTargetBirds` joined the state (default
    /// 0 reproduces versus behavior, but the JSON encoding grew, so hashes
    /// change).
    /// v6: P3.3 versus fix — `splitFlock` now seeds the new flock's leader
    /// path at its centroid (regression: pathless flocks steered toward the
    /// world origin), so replay trajectories with a split diverge.
    /// v7: P3.3 versus fix — `versusMergeSuppressed` joined the state (R-5
    /// auto-merge collapsed the versus flocks; default false reproduces the
    /// v6 behavior, but the JSON encoding grew, so hashes change).
    /// v8: P4 energy fix — feeding gain now counts only the birds inside the
    /// field's radius (R-8), not the whole sub-flock, so replay trajectories
    /// diverge wherever a flock grazed a field from outside (see ADR-0028).
    /// v9: P4 leader brake — inside `leaderBrakeRadius` of the leader point
    /// the bird's velocity is damped each tick, so a parked flock settles
    /// onto the point instead of penduluming around it forever.
    /// v10: the brake ramps linearly to zero at the radius edge (arrive
    /// profile); the flat brake damped day-start trips to a crawl and merged
    /// the day-start clouds before the pilots could separate them.
    /// v11: a split widens every roost's claim row by one slot (R-12);
    /// before this, a third sub-flock's dusk claim trapped with
    /// "Index out of range" (exit 133 in the G4 hard-tier balance sweep).
    /// v12: energy tuning for the G4 dusk-flock window (ADR-0032) — fields
    /// hold double the depletion budget (`fieldRichness * 20`), grazing gain
    /// uses divisor 7 instead of 10, and the energy drain applies only while
    /// the sub-flock is in flight (R-8 "while flying"), so flocks no longer
    /// starve through the 900-tick dusk on roosts that overlap no field.
    /// v13: versus sub-flock side ownership (ADR-0033) — `spawnRival`
    /// replaces the starter split, `subFlockOwners` gates forced splits,
    /// scripted splits, and the day-end roost tally.
    /// v14: falcon stoop path (ADR-0034) — kills land within `diveRadius`
    /// of the falcon→target→2×diveRadius segment instead of the dive point,
    /// the grab budget scales with the target flock's size, and the
    /// centroid split check runs against the path.
    /// v15: ADR-0035 retune — the forced-split trigger tightens to
    /// `diveRadius` around the stoop path (the 2× catchment minted a
    /// second flock on nearly every hit), and the rival dusk tunables
    /// (`claimGate`/`contestRatio`/`splitMinBirds`) join the pilot.
    /// v16: ADR-0036 — the falcon grab budget scales with the struck
    /// flock's side size (via `subFlockOwners`) instead of the struck
    /// flock's own size, so a forced split no longer halves a side's
    /// per-dive losses; replay trajectories diverge wherever a dive hits
    /// a split side.
    public static let replayContentVersion = 16

    /// R-10 grab budget: successful-dive kills per 1,000 birds of the target
    /// flock (ADR-0034). Tuning constant — the balance harness overrides it
    /// with `--falcon-budget` when sweeping falcon pressure; production code
    /// reads it only at the dive site.
    nonisolated(unsafe) public static var falconGrabPerThousand = 8

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

    /// Solo objective target (R-13 / P3.2): the number of birds that must
    /// settle inside a roost radius for the day to be won. `0` means a
    /// versus region (roost tally rules).
    public let soloTargetBirds: Int

    /// Wind-field pattern for this region (P3 R-1). Defaults to the legacy
    /// `uniform` field.
    public let windPattern: WindPattern

    /// Falcon behavior mode for this region (P3 R-10). Defaults to the
    /// legacy `patrol` behavior.
    public let falconBehavior: FalconBehavior

    /// Static obstacle circles, center coordinates in world units (P3).
    /// Immutable for the life of the state; the kernel only reads them.
    public let obstacleCenterX: [Int32]
    public let obstacleCenterY: [Int32]
    public let obstacleRadius: [Int32]

    /// Number of static obstacles (P3).
    public var obstacleCount: Int { obstacleCenterX.count }

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

    /// Density shield threshold (R-11): average neighbor count at or above
    /// this halves dive success.
    public static let densityShield = 10

    /// Neighbor radius for the R-11 density metric (the alignment radius).
    public static let defaultAlignRadius = 64

    /// Leader path sampling interval in ticks (R-3).
    public static let leaderPathSampleInterval = 1

    /// Falcon cooldown between dives in ticks (R-10).
    public static let falconDiveCooldown = 120

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
        soloTargetBirds: Int = 0,
        versusMergeSuppressed: Bool = false,
        windSeedOffset: Int,
        seed: UInt64,
        windPattern: WindPattern = .uniform,
        falconBehavior: FalconBehavior = .patrol,
        obstacleCenterX: [Int32] = [],
        obstacleCenterY: [Int32] = [],
        obstacleRadius: [Int32] = [],
        contentVersion: Int = GameState.replayContentVersion
    ) {
        self.seed = seed
        self.contentVersion = contentVersion
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.boidsParams = boidsParams
        self.falconCount = falconCount
        self.hasRival = hasRival
        self.soloTargetBirds = soloTargetBirds
        self.versusMergeSuppressed = versusMergeSuppressed
        self.windSeedOffset = windSeedOffset
        self.windPattern = windPattern
        self.falconBehavior = falconBehavior
        self.obstacleCenterX = obstacleCenterX
        self.obstacleCenterY = obstacleCenterY
        self.obstacleRadius = obstacleRadius

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

            // Random initial velocity (Q16.16) from the integer trig table.
            let speed = Int32(rng.next(upperBound: Int(boidsParams.maxSpeed - boidsParams.minSpeed) + 1)) + boidsParams.minSpeed
            let angle = Int32(rng.next(upperBound: IntTrig.turns))
            let unit = unitVectorQ16(angle)
            let cosA = (Int64(unit.x) * Int64(speed)) >> 16
            let sinA = (Int64(unit.y) * Int64(speed)) >> 16

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
        // With no path drawn yet, the leader point rests at the world center
        // (an attractor of (0,0) would drag the flock into the corner).
        self.leaderPaths[0].currentX = centerX
        self.leaderPaths[0].currentY = centerY
        self.subFlockAssignments = subFlockAssignments
        self.subFlockOwners = [0] // ADR-0033: one player-side flock at start.
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
                maxDepletion: fieldRichness[i] * 20,
                ticksSinceFeed: 0
            ))
        }
        self.fields = fields

        // Initialize roosts (R-12).
        var roosts: [RoostState] = []
        var roostClaims: [[Int]] = []
        for i in 0..<roostCount {
            roosts.append(RoostState(
                centerX: roostCenterX[i],
                centerY: roostCenterY[i],
                radius: Int32(roostRadius[i]),
                claims: [0],
                claimant: -1
            ))
            roostClaims.append([0]) // One row per roost, one slot per flock.
        }
        self.roosts = roosts
        self.roostClaims = roostClaims
        self.mergeProximityStreak = 0

        // Seed the wind field (R-1): one vector per 256-unit cell.
        let (wx, wy) = GameState.windField(
            generation: 0, seed: seed, windSeedOffset: windSeedOffset,
            worldWidth: worldWidth, worldHeight: worldHeight,
            pattern: windPattern
        )
        self.windCellsX = wx
        self.windCellsY = wy

        // Initialize falcons (R-10).
        var falcons: [FalconState] = []
        for i in 0..<falconCount {
            falcons.append(FalconState(
                patrolAngle: Int32(i * 1024 / max(falconCount, 1)),
                cooldown: 0,
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
        && lhs.roosts == rhs.roosts
        && lhs.roostClaims == rhs.roostClaims
        && lhs.soloTargetBirds == rhs.soloTargetBirds
        && lhs.versusMergeSuppressed == rhs.versusMergeSuppressed
        && lhs.mergeProximityStreak == rhs.mergeProximityStreak
        && lhs.windCellsX == rhs.windCellsX
        && lhs.windCellsY == rhs.windCellsY
        && lhs.falcons == rhs.falcons
        && lhs.condenseCooldown == rhs.condenseCooldown
        && lhs.condenseActive == rhs.condenseActive
        && lhs.windPattern == rhs.windPattern
        && lhs.falconBehavior == rhs.falconBehavior
        && lhs.obstacleCenterX == rhs.obstacleCenterX
        && lhs.obstacleCenterY == rhs.obstacleCenterY
        && lhs.obstacleRadius == rhs.obstacleRadius
    }
}

// MARK: - Helpers

extension GameState {
    /// Deterministic per-cell wind angle hash: mixes the cell index, the wind
    /// generation, the region seed, and the region's wind offset. Pure integer
    /// (INV-3); golden-ratio multiplier avalanche gives well-spread angles.
    static func windCellAngle(cellIndex: Int, generation: Int, seed: UInt64, windSeedOffset: Int) -> Int32 {
        var h: UInt64 = 0x9E3779B97F4A7C15
        h &+= UInt64(truncatingIfNeeded: cellIndex) &* 0xBF58476D1CE4E5B9
        h &+= UInt64(truncatingIfNeeded: generation) &* 0x94D049BB133111EB
        h &+= seed &+ UInt64(truncatingIfNeeded: windSeedOffset)
        h ^= h >> 30; h = h &* 0xBF58476D1CE4E5B9
        h ^= h >> 27; h = h &* 0x94D049BB133111EB
        h ^= h >> 31
        return Int32(truncatingIfNeeded: h % UInt64(IntTrig.turns))
    }

    /// Regenerate the per-256-cell wind field (R-1) for `generation` = tick / 600.
    /// The base magnitude is 0.3 in Q16.16 (19661); `pattern` selects the
    /// spatial structure (all integer math, INV-3).
    static func windField(
        generation: Int, seed: UInt64, windSeedOffset: Int,
        worldWidth: Int32, worldHeight: Int32,
        pattern: WindPattern = .uniform
    ) -> (x: [Int32], y: [Int32]) {
        let cols = max(1, Int(worldWidth) / GameState.windCellSize)
        let rows = max(1, Int(worldHeight) / GameState.windCellSize)
        let count = cols * rows
        var xs = [Int32](repeating: 0, count: count)
        var ys = [Int32](repeating: 0, count: count)
        let magnitudeQ16: Int32 = 19_661 // 0.3 units/tick
        // Disjoint angle/magnitude hash slots so the patterns cannot alias
        // the legacy per-cell uniform space.
        let shearAngleSalt = 0x5EED_0000
        let gustDirectionSalt = 0x6A57_0000
        let gustMagnitudeSalt = 0x6A57_0001

        switch pattern {
        case .uniform:
            for cell in 0..<count {
                let angle = windCellAngle(cellIndex: cell, generation: generation, seed: seed, windSeedOffset: windSeedOffset)
                let unit = unitVectorQ16(angle)
                xs[cell] = (Int32(unit.x) * magnitudeQ16) >> 16
                ys[cell] = (Int32(unit.y) * magnitudeQ16) >> 16
            }
        case .shear:
            // One shared angle per row (P3 R-1): every cell in a row carries
            // the identical vector, so the field forms horizontal bands.
            for cell in 0..<count {
                let row = cell / cols
                let angle = windCellAngle(cellIndex: shearAngleSalt + row, generation: generation, seed: seed, windSeedOffset: windSeedOffset)
                let unit = unitVectorQ16(angle)
                xs[cell] = (Int32(unit.x) * magnitudeQ16) >> 16
                ys[cell] = (Int32(unit.y) * magnitudeQ16) >> 16
            }
        case .gusts:
            // One shared direction per generation; per-cell magnitude from
            // 1/8 to 8/8 of the base strength (P3 R-1). All products widen
            // to Int64: 65535 * 19661 fits Int64, not Int32.
            let gustAngle = windCellAngle(cellIndex: gustDirectionSalt, generation: generation, seed: seed, windSeedOffset: windSeedOffset)
            let unit = unitVectorQ16(gustAngle)
            for cell in 0..<count {
                let magSlot = windCellAngle(cellIndex: gustMagnitudeSalt + cell, generation: generation, seed: seed, windSeedOffset: windSeedOffset)
                let scale = Int32(1 + (magSlot & 7)) // 1...8 eighths
                let magnitude = Int32((Int64(magnitudeQ16) * Int64(scale)) >> 3)
                xs[cell] = Int32((Int64(unit.x) * Int64(magnitude)) >> 16)
                ys[cell] = Int32((Int64(unit.y) * Int64(magnitude)) >> 16)
            }
        }
        return (xs, ys)
    }

    /// Recompute the wind cells for the generation the state's tick sits in
    /// (P3). Used by the reducer on the regeneration boundary and by callers
    /// that change `windPattern` on a live state.
    public mutating func rebuildWindField() {
        let (wx, wy) = GameState.windField(
            generation: tick / GameState.windRegenTicks,
            seed: seed, windSeedOffset: windSeedOffset,
            worldWidth: worldWidth, worldHeight: worldHeight,
            pattern: windPattern
        )
        windCellsX = wx
        windCellsY = wy
    }
}
