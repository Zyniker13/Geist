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

/// Cardinal direction (bridge spans, flow-field corner costs).
public enum Direction: Codable, Sendable, Equatable, Hashable, CaseIterable {
    case north
    case south
    case east
    case west

    public var delta: (col: Int, row: Int) {
        switch self {
        case .north: return (0, -1)
        case .south: return (0, 1)
        case .east: return (1, 0)
        case .west: return (-1, 0)
        }
    }

    /// The opposite direction (a corner turn changes direction).
    public var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
    }

    /// True when moving `from` this direction to `to` turns a corner.
    public static func isTurn(from: Direction, to: Direction) -> Bool {
        from != to && from != to.opposite
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
        result.reserveCapacity(4)
        forEachNeighbor(in: grid) { result.append($0) }
        return result
    }

    /// Allocation-free neighbor iteration for hot loops.
    @inline(__always)
    public func forEachNeighbor(in grid: Grid, _ body: (Tile) -> Void) {
        if col > 0 { body(Tile(col: col - 1, row: row)) }
        if col < grid.width - 1 { body(Tile(col: col + 1, row: row)) }
        if row > 0 { body(Tile(col: col, row: row - 1)) }
        if row < grid.height - 1 { body(Tile(col: col, row: row + 1)) }
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

    public func boundsContain(_ tile: Tile) -> Bool {
        tile.col >= 0 && tile.col < width && tile.row >= 0 && tile.row < height
    }
}
