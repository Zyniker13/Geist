/// Night Market placeholder palette (ROADMAP §1 aesthetic spec) plus the
/// per-city palettes (NM-P6.1). Three looks ship with the six maps:
/// neon_warm (Taipei), river_gold (Seoul/Bangkok), earth_lantern
/// (Marrakesh/Istanbul/Oaxaca). Unknown ids fall back to neon_warm.
import SpriteKit
import NMCore

public enum Palette {
    public static let nightGround = SKColor(hex: 0x0E1016)
    public static let walkway = SKColor(hex: 0x2A2E3A)
    public static let lanternGlow = SKColor(hex: 0xFFB547)
    public static let rainTint = SKColor(hex: 0x7FA7C9)
    public static let canal = SKColor(hex: 0x24466E)
    public static let plaza = SKColor(hex: 0x232838)
    public static let stallBody = SKColor(hex: 0x33384A)
    public static let hudText = SKColor(hex: 0xE8E4D8)

    /// Stall accent colors with their color-blind-safe glyphs.
    public static func stall(_ color: StallColor) -> SKColor {
        switch color {
        case .noodles: return SKColor(hex: 0xFF5A5F)
        case .tea: return SKColor(hex: 0x3DDC97)
        case .skewers: return SKColor(hex: 0xFFD23F)
        case .dumplings: return SKColor(hex: 0x5AA9FF)
        case .sweets: return SKColor(hex: 0xC77DFF)
        case .seafood: return SKColor(hex: 0xFF8C42)
        }
    }

    /// Tile background for the default (neon warm) look.
    public static func tile(_ type: TileType) -> SKColor {
        CityPalette.neonWarm.tile(type)
    }
}

/// One city's color set: ground tones, water, walkways, and the glow accent.
public struct CityPalette: Sendable, Equatable {
    public let id: String
    public let nightGround: UInt32
    public let groundA: UInt32
    public let groundB: UInt32
    public let groundEdge: UInt32
    public let walkway: UInt32
    public let canal: UInt32
    public let canalEdge: UInt32
    public let plaza: UInt32
    public let plazaEdge: UInt32
    public let building: UInt32
    public let glow: UInt32
    public let rainTint: UInt32

    public static let neonWarm = CityPalette(
        id: "neon_warm",
        nightGround: 0x0E1016, groundA: 0x12141C, groundB: 0x0F1118, groundEdge: 0x1A1E28,
        walkway: 0x2A2E3A, canal: 0x24466E, canalEdge: 0x3E6FA5,
        plaza: 0x232838, plazaEdge: 0x3A4258, building: 0x14161E,
        glow: 0xFFB547, rainTint: 0x7FA7C9
    )

    /// Riverside look: deeper blue night, brighter canals, gold lanterns.
    public static let riverGold = CityPalette(
        id: "river_gold",
        nightGround: 0x0B0E1A, groundA: 0x101528, groundB: 0x0D1120, groundEdge: 0x1B2340,
        walkway: 0x27304A, canal: 0x1E3A6E, canalEdge: 0x4C7FC7,
        plaza: 0x1B2238, plazaEdge: 0x35406B, building: 0x12162A,
        glow: 0xFFD27A, rainTint: 0x8FB4D9
    )

    /// Earthen look: warm mud walls, teal water, copper lanterns.
    public static let earthLantern = CityPalette(
        id: "earth_lantern",
        nightGround: 0x14100C, groundA: 0x1A150F, groundB: 0x15110C, groundEdge: 0x28201A,
        walkway: 0x33291F, canal: 0x2E4A44, canalEdge: 0x4E7A6E,
        plaza: 0x262019, plazaEdge: 0x3E342A, building: 0x1C1712,
        glow: 0xFFC078, rainTint: 0x9FB4A9
    )

    /// The palette for a map's `palette` id (unknown ids use neon_warm).
    public static func named(_ id: String) -> CityPalette {
        switch id {
        case "river_gold": return .riverGold
        case "earth_lantern": return .earthLantern
        default: return .neonWarm
        }
    }

    public var groundColor: SKColor { SKColor(hex: nightGround) }
    public var walkwayColor: SKColor { SKColor(hex: walkway) }
    public var canalColor: SKColor { SKColor(hex: canal) }
    public var glowColor: SKColor { SKColor(hex: glow) }
    public var rainColor: SKColor { SKColor(hex: rainTint) }

    public func tile(_ type: TileType) -> SKColor {
        switch type {
        case .ground: return SKColor(hex: groundA)
        case .plaza: return SKColor(hex: plaza)
        case .water: return SKColor(hex: canal)
        case .building: return SKColor(hex: building)
        }
    }
}

#if canImport(UIKit)
    import UIKit
    extension SKColor {
        convenience init(hex: UInt32) {
            self.init(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1
            )
        }
    }
#elseif canImport(AppKit)
    import AppKit
    extension SKColor {
        convenience init(hex: UInt32) {
            self.init(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1
            )
        }
    }
#endif
