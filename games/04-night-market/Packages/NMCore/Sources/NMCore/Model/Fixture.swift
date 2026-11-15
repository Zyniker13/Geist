/// A fixture placed on the grid.
///
/// Bridges carry a direction: the span runs `length` water tiles in that
/// direction starting from the tile adjacent to `position`.
public struct Fixture: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let kind: FixtureKind
    public var position: Tile
    public var radius: Int  // in tiles
    public var direction: Direction?

    public init(id: Int, kind: FixtureKind, position: Tile, radius: Int, direction: Direction? = nil) {
        self.id = id
        self.kind = kind
        self.position = position
        self.radius = radius
        self.direction = direction
    }

    /// Tiles this fixture covers or affects directly.
    ///
    /// Lanterns, awnings, and buskers affect tiles within their radius (the flow
    /// field checks those by distance). Bridges physically cover water tiles:
    /// `length` tiles in a straight line starting adjacent to `position`.
    public func coveredTiles() -> Set<Tile> {
        guard case .bridge(let length) = kind, let direction else { return [position] }
        var tiles: Set<Tile> = []
        var col = position.col + direction.delta.col
        var row = position.row + direction.delta.row
        for _ in 0..<length {
            tiles.insert(Tile(col: col, row: row))
            col += direction.delta.col
            row += direction.delta.row
        }
        return tiles
    }
}

public enum FixtureKind: Codable, Sendable, Equatable, Hashable {
    case lantern(radius: Int)
    case awning  // covers a 3×3 area (radius 1)
    case busker(radius: Int)
    case bridge(length: Int)  // spans exactly 1–3 water tiles in a straight line
    case seat(count: Int)

    /// Canonical radii per R-15: lanterns light radius 3, awnings cover 3×3,
    /// buskers attract within radius 2.
    public static func canonical(_ kind: FixtureKind) -> FixtureKind {
        switch kind {
        case .lantern: return .lantern(radius: 3)
        case .awning: return .awning
        case .busker: return .busker(radius: 2)
        case .bridge(let length): return .bridge(length: length)
        case .seat(let count): return .seat(count: count)
        }
    }

    public var defaultRadius: Int {
        switch self {
        case .lantern: return 3
        case .awning: return 1
        case .busker: return 2
        case .bridge: return 0
        case .seat: return 0
        }
    }
}
