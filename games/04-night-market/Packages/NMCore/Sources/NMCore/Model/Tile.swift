/// A single tile on the 32×20 grid.
public enum TileType: Codable, Sendable, Equatable, Hashable {
    case ground
    case plaza
    case water(WaterType)
    case building

    public enum WaterType: Codable, Sendable, Equatable, Hashable {
        case canal
    }
}

/// A walkway tile.
public struct WalkwayTile: Codable, Sendable, Equatable, Hashable {
    public let tile: Tile
    public var cost: Int  // computed cost for pathing

    public init(tile: Tile, cost: Int = 10) {
        self.tile = tile
        self.cost = cost
    }
}

/// A position on the grid.
public struct Tile: Codable, Sendable, Equatable, Hashable, Comparable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    public static func < (lhs: Tile, rhs: Tile) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }

    /// Neighbors (up, down, left, right).
    public func neighbors(in grid: Grid) -> [Tile] {
        var result: [Tile] = []
        if col > 0 { result.append(Tile(col: col - 1, row: row)) }
        if col < grid.width - 1 { result.append(Tile(col: col + 1, row: row)) }
        if row > 0 { result.append(Tile(col: col, row: row - 1)) }
        if row < grid.height - 1 { result.append(Tile(col: col, row: row + 1)) }
        return result
    }

    public func manhattanTiles(to other: Tile) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }
}

/// The 32×20 grid.
public struct Grid: Sendable, Codable, Equatable, Hashable {
    public var width: Int
    public var height: Int
    private let tiles: [TileType]  // flattened, index = row * width + col

    public init(width: Int = 32, height: Int = 20, tiles: [TileType]) {
        self.width = width
        self.height = height
        precondition(tiles.count == width * height, "Grid must have \(width * height) tiles, got \(tiles.count)")
        self.tiles = tiles
    }

    public subscript(col: Int, row: Int) -> TileType {
        tiles[row * width + col]
    }

    public func tile(at tile: Tile) -> TileType {
        tiles[tile.row * width + tile.col]
    }

    public func isWalkable(_ at: Tile) -> Bool {
        switch tile(at: at) {
        case .ground, .plaza: return true
        case .water, .building: return false
        }
    }
}
