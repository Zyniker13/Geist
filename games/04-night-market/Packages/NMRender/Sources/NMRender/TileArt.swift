/// Mini-Motorways-style auto-joining walkway tiles: each walkway tile draws
/// connectors toward its walkway/plaza/gate neighbors. 16 neighbor masks.
import SpriteKit
import NMCore
import CoreGraphics

public enum TileArt {
    /// Neighbor mask bits: 1 = north, 2 = east, 4 = south, 8 = west.
    public static func mask(for tile: Tile, isWalkable: (Tile) -> Bool, in grid: Grid) -> Int {
        var mask = 0
        if tile.row + 1 < grid.height, isWalkable(Tile(col: tile.col, row: tile.row + 1)) { mask |= 1 }
        if tile.col + 1 < grid.width, isWalkable(Tile(col: tile.col + 1, row: tile.row)) { mask |= 2 }
        if tile.row > 0, isWalkable(Tile(col: tile.col, row: tile.row - 1)) { mask |= 4 }
        if tile.col > 0, isWalkable(Tile(col: tile.col - 1, row: tile.row)) { mask |= 8 }
        return mask
    }

    /// The path (in a 0..<1 unit square, origin bottom-left) for a mask:
    /// a rounded slab through the tile joining the connected sides.
    public static func path(for mask: Int, tileSize: CGFloat) -> CGPath {
        let half = tileSize / 2
        let slab = tileSize * 0.52
        let r = slab / 2

        if mask == 0 {
            let p = CGMutablePath()
            p.addRoundedRect(
                in: CGRect(x: half - r, y: half - r, width: slab, height: slab),
                cornerWidth: r, cornerHeight: r
            )
            return p
        }
        let p = CGMutablePath()
        let vertical = mask & 1 != 0 || mask & 4 != 0
        let horizontal = mask & 2 != 0 || mask & 8 != 0
        if vertical {
            p.addRoundedRect(
                in: CGRect(x: half - r, y: 0, width: slab, height: tileSize),
                cornerWidth: r, cornerHeight: r
            )
        }
        if horizontal {
            p.addRoundedRect(
                in: CGRect(x: 0, y: half - r, width: tileSize, height: slab),
                cornerWidth: r, cornerHeight: r
            )
        }
        return p
    }
}
