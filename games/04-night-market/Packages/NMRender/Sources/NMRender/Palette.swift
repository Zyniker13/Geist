/// Night Market placeholder palette (ROADMAP §1 aesthetic spec).
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

    /// Tile background for the static map.
    public static func tile(_ type: TileType) -> SKColor {
        switch type {
        case .ground: return nightGround
        case .plaza: return plaza
        case .water: return canal
        case .building: return SKColor(hex: 0x14161E)
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
