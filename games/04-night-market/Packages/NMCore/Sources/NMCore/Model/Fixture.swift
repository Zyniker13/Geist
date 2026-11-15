/// A fixture placed on the grid.
public struct Fixture: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let kind: FixtureKind
    public var position: Tile
    public var radius: Int  // in tiles

    public init(id: Int, kind: FixtureKind, position: Tile, radius: Int) {
        self.id = id
        self.kind = kind
        self.position = position
        self.radius = radius
    }
}

public enum FixtureKind: Codable, Sendable, Equatable, Hashable {
    case lantern(radius: Int = 3)
    case awning  // covers 3x3 area
    case busker(radius: Int = 2)
    case bridge(length: Int)  // spans 1-3 water tiles
    case seat(count: Int = 3)
}
