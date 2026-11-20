// Murmuration Content — region model.
//
// A Region is everything needed to build a GameState for one playable area:
// world size, flock size, roosts, feeding fields, falcon count, rival flag,
// wind seed, and a landscape palette. Regions load from JSON (S2.3) and are
// validated by the RegionCatalog before use.

import Foundation
import MUCore

/// A single-channel RGBA color, components in [0, 1].
public struct RGBAColor: Codable, Sendable, Equatable, Hashable {
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(r: Float, g: Float, b: Float, a: Float = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// True when every component is within [0, 1].
    public var isValid: Bool {
        [r, g, b, a].allSatisfy { $0 >= 0 && $0 <= 1 }
    }
}

/// The landscape palette for a region (MU-P2.1), following the ROADMAP §1
/// palette: four-stop dusk sky gradient, three parallax hill layers, ink birds
/// with iridescent highlights, a warm-sepia rival, and ochre/green fields.
public struct RegionPalette: Codable, Sendable, Equatable {
    /// Zenith: dusk indigo.
    public var skyTop: RGBAColor
    /// Upper mid: violet.
    public var skyHigh: RGBAColor
    /// Lower mid: rose.
    public var skyLow: RGBAColor
    /// Horizon: apricot.
    public var skyBottom: RGBAColor
    public var hillFar: RGBAColor
    public var hillMid: RGBAColor
    public var hillNear: RGBAColor
    /// Bird body color: ink.
    public var birdInk: RGBAColor
    /// Bird highlight: iridescent teal.
    public var birdHighlight: RGBAColor
    /// Rival flock: warm sepia.
    public var rival: RGBAColor
    /// Field fill: ochre.
    public var fieldOchre: RGBAColor
    /// Field accent: green.
    public var fieldGreen: RGBAColor
    /// Falcon silhouette.
    public var falcon: RGBAColor

    public init(
        skyTop: RGBAColor, skyHigh: RGBAColor, skyLow: RGBAColor, skyBottom: RGBAColor,
        hillFar: RGBAColor, hillMid: RGBAColor, hillNear: RGBAColor,
        birdInk: RGBAColor, birdHighlight: RGBAColor,
        rival: RGBAColor, fieldOchre: RGBAColor, fieldGreen: RGBAColor,
        falcon: RGBAColor
    ) {
        self.skyTop = skyTop
        self.skyHigh = skyHigh
        self.skyLow = skyLow
        self.skyBottom = skyBottom
        self.hillFar = hillFar
        self.hillMid = hillMid
        self.hillNear = hillNear
        self.birdInk = birdInk
        self.birdHighlight = birdHighlight
        self.rival = rival
        self.fieldOchre = fieldOchre
        self.fieldGreen = fieldGreen
        self.falcon = falcon
    }

    /// The ROADMAP §1 palette, shared by every region's flock colors.
    public static let standard = RegionPalette(
        skyTop: RGBAColor(r: 0.180, g: 0.165, b: 0.310),
        skyHigh: RGBAColor(r: 0.431, g: 0.353, b: 0.600),
        skyLow: RGBAColor(r: 0.851, g: 0.518, b: 0.608),
        skyBottom: RGBAColor(r: 0.965, g: 0.706, b: 0.561),
        hillFar: RGBAColor(r: 0.30, g: 0.30, b: 0.36),
        hillMid: RGBAColor(r: 0.20, g: 0.20, b: 0.26),
        hillNear: RGBAColor(r: 0.12, g: 0.12, b: 0.16),
        birdInk: RGBAColor(r: 0.106, g: 0.102, b: 0.133),
        birdHighlight: RGBAColor(r: 0.243, g: 0.361, b: 0.420),
        rival: RGBAColor(r: 0.353, g: 0.231, b: 0.165),
        fieldOchre: RGBAColor(r: 0.788, g: 0.639, b: 0.357),
        fieldGreen: RGBAColor(r: 0.494, g: 0.612, b: 0.416),
        falcon: RGBAColor(r: 0.13, g: 0.10, b: 0.08)
    )

    /// True when every color is valid.
    public var isValid: Bool {
        [
            skyTop, skyHigh, skyLow, skyBottom, hillFar, hillMid, hillNear,
            birdInk, birdHighlight, rival, fieldOchre, fieldGreen, falcon,
        ]
        .allSatisfy(\.isValid)
    }
}

/// A playable region (S2.3).
public struct Region: Codable, Sendable, Equatable, Identifiable {
    /// A stable identifier (e.g. "meadow").
    public let id: String
    /// Display name.
    public let name: String
    /// World extent in world units.
    public let worldWidth: Int32
    public let worldHeight: Int32
    /// Starting flock size.
    public let birdCount: Int
    /// Number of falcons (R-10).
    public let falconCount: Int
    /// Whether a rival flock is present (R-12).
    public let hasRival: Bool
    /// Birds the rival flock starts with (ROADMAP §5 `rival.startBirds`).
    /// The engine has no rival spawn, so P2 creates the rival with a day-start
    /// split (`RegionStarter`); 0 means no rival.
    public let rivalStartBirds: Int
    /// Rival pilot difficulty (MU-P4.1). Defaults to gentle for regions
    /// authored before P4.
    public let rivalDifficulty: RivalDifficulty
    /// Solo-objective target (MU-P3.2, R-13): in a no-rival region, the goal
    /// is to roost this many birds. 0 means no solo objective (region is
    /// versus or free-play).
    public let soloTargetBirds: Int
    /// Wind seed offset (R-1).
    public let windSeedOffset: Int
    /// Simulation seed.
    public let seed: UInt64
    /// Roost definitions (R-12).
    public let roosts: [RoostDef]
    /// Feeding field definitions (R-8).
    public let fields: [FieldDef]
    /// Landscape palette.
    public let palette: RegionPalette
    /// Static world obstacles (MU-P3.1): circular pillars the flock steers
    /// around. Empty in regions authored before P3.
    public let obstacles: [ObstacleDef]
    /// Wind pattern (R-1) this region plays under.
    public let windPattern: WindPattern
    /// Falcon behavior (R-10) used by this region's falcons.
    public let falconBehavior: FalconBehavior

    /// A roost placement.
    public struct RoostDef: Codable, Sendable, Equatable {
        public let x: Int32
        public let y: Int32
        public let radius: Int

        public init(x: Int32, y: Int32, radius: Int) {
            self.x = x
            self.y = y
            self.radius = radius
        }
    }

    /// A feeding field placement.
    public struct FieldDef: Codable, Sendable, Equatable {
        public let x: Int32
        public let y: Int32
        public let radius: Int
        public let richness: Int

        public init(x: Int32, y: Int32, radius: Int, richness: Int) {
            self.x = x
            self.y = y
            self.radius = radius
            self.richness = richness
        }
    }

    /// A static circular obstacle placement (MU-P3.1).
    public struct ObstacleDef: Codable, Sendable, Equatable {
        public let x: Int32
        public let y: Int32
        public let radius: Int

        public init(x: Int32, y: Int32, radius: Int) {
            self.x = x
            self.y = y
            self.radius = radius
        }
    }

    public init(
        id: String,
        name: String,
        worldWidth: Int32,
        worldHeight: Int32,
        birdCount: Int,
        falconCount: Int,
        hasRival: Bool,
        rivalStartBirds: Int = 0,
        rivalDifficulty: RivalDifficulty = .gentle,
        soloTargetBirds: Int = 0,
        windSeedOffset: Int,
        seed: UInt64,
        roosts: [RoostDef],
        fields: [FieldDef],
        palette: RegionPalette,
        obstacles: [ObstacleDef] = [],
        windPattern: WindPattern = .uniform,
        falconBehavior: FalconBehavior = .patrol
    ) {
        self.id = id
        self.name = name
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.birdCount = birdCount
        self.falconCount = falconCount
        self.hasRival = hasRival
        self.rivalStartBirds = rivalStartBirds
        self.rivalDifficulty = rivalDifficulty
        self.soloTargetBirds = soloTargetBirds
        self.windSeedOffset = windSeedOffset
        self.seed = seed
        self.roosts = roosts
        self.fields = fields
        self.palette = palette
        self.obstacles = obstacles
        self.windPattern = windPattern
        self.falconBehavior = falconBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, worldWidth, worldHeight, birdCount, falconCount
        case hasRival, rivalStartBirds, rivalDifficulty, soloTargetBirds, windSeedOffset, seed
        case roosts, fields, palette, obstacles, windPattern, falconBehavior
    }

    /// JSON decoding defaults let regions authored before P3 load unchanged:
    /// no obstacles, uniform wind, patrol falcons. Unknown feature strings
    /// throw, so bad content never reaches the sim.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        worldWidth = try container.decode(Int32.self, forKey: .worldWidth)
        worldHeight = try container.decode(Int32.self, forKey: .worldHeight)
        birdCount = try container.decode(Int.self, forKey: .birdCount)
        falconCount = try container.decode(Int.self, forKey: .falconCount)
        hasRival = try container.decode(Bool.self, forKey: .hasRival)
        rivalStartBirds = try container.decodeIfPresent(Int.self, forKey: .rivalStartBirds) ?? 0
        rivalDifficulty = try container.decodeIfPresent(RivalDifficulty.self, forKey: .rivalDifficulty) ?? .gentle
        soloTargetBirds = try container.decodeIfPresent(Int.self, forKey: .soloTargetBirds) ?? 0
        windSeedOffset = try container.decode(Int.self, forKey: .windSeedOffset)
        seed = try container.decode(UInt64.self, forKey: .seed)
        roosts = try container.decode([RoostDef].self, forKey: .roosts)
        fields = try container.decode([FieldDef].self, forKey: .fields)
        palette = try container.decode(RegionPalette.self, forKey: .palette)
        obstacles = try container.decodeIfPresent([ObstacleDef].self, forKey: .obstacles) ?? []
        windPattern = try container.decodeIfPresent(WindPattern.self, forKey: .windPattern) ?? .uniform
        falconBehavior = try container.decodeIfPresent(FalconBehavior.self, forKey: .falconBehavior) ?? .patrol
    }

    /// A copy with different obstacles — validation tests build variants.
    public func copy(obstacles: [ObstacleDef]) -> Region {
        Region(
            id: id, name: name,
            worldWidth: worldWidth, worldHeight: worldHeight,
            birdCount: birdCount, falconCount: falconCount,
            hasRival: hasRival, rivalStartBirds: rivalStartBirds,
            rivalDifficulty: rivalDifficulty,
            soloTargetBirds: soloTargetBirds,
            windSeedOffset: windSeedOffset, seed: seed,
            roosts: roosts, fields: fields, palette: palette,
            obstacles: obstacles, windPattern: windPattern,
            falconBehavior: falconBehavior
        )
    }

    /// Build a fresh GameState for this region.
    public func makeGameState() -> GameState {
        GameState(
            birdCount: birdCount,
            worldWidth: worldWidth,
            worldHeight: worldHeight,
            boidsParams: BoidsParams(),
            fieldRichness: fields.map(\.richness),
            fieldRadius: fields.map(\.radius),
            fieldCenterX: fields.map(\.x),
            fieldCenterY: fields.map(\.y),
            roostCount: roosts.count,
            roostCenterX: roosts.map(\.x),
            roostCenterY: roosts.map(\.y),
            roostRadius: roosts.map(\.radius),
            falconCount: falconCount,
            hasRival: hasRival,
            soloTargetBirds: soloTargetBirds,
            windSeedOffset: windSeedOffset,
            seed: seed,
            windPattern: windPattern,
            falconBehavior: falconBehavior,
            obstacleCenterX: obstacles.map(\.x),
            obstacleCenterY: obstacles.map(\.y),
            obstacleRadius: obstacles.map { Int32($0.radius) }
        )
    }

    /// A solo copy with a different starting flock size — the perf harness
    /// renders the flock cap (3,000) without rival bookkeeping.
    public func withBirdCount(_ count: Int) -> Region {
        Region(
            id: id, name: name,
            worldWidth: worldWidth, worldHeight: worldHeight,
            birdCount: count, falconCount: falconCount,
            hasRival: false, rivalStartBirds: 0,
            soloTargetBirds: 0,
            windSeedOffset: windSeedOffset, seed: seed,
            roosts: roosts, fields: fields, palette: palette,
            obstacles: obstacles, windPattern: windPattern,
            falconBehavior: falconBehavior
        )
    }

    /// A copy with a different simulation seed (UI-test determinism checks).
    public func reseeded(_ newSeed: UInt64) -> Region {
        Region(
            id: id, name: name,
            worldWidth: worldWidth, worldHeight: worldHeight,
            birdCount: birdCount, falconCount: falconCount,
            hasRival: hasRival, rivalStartBirds: rivalStartBirds,
            soloTargetBirds: soloTargetBirds,
            windSeedOffset: windSeedOffset, seed: newSeed,
            roosts: roosts, fields: fields, palette: palette,
            obstacles: obstacles, windPattern: windPattern,
            falconBehavior: falconBehavior
        )
    }
}
