/// NMContent: maps, stalls, customers, weather, clock, fixtures.
/// Depends on NMCore.
import Foundation
import NMCore

// MARK: - Content types

/// A content map definition.
public struct MapDef: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public let tiles: [TileType]
    public let gates: [GateDef]
    public let initialStalls: [StallDef]
    public let walkwayBudget: Int

    public struct GateDef: Codable, Sendable, Equatable, Hashable {
        public let col: Int
        public let row: Int
    }

    public struct StallDef: Codable, Sendable, Equatable, Hashable {
        public let color: StallColor
        public let col: Int
        public let row: Int
        public let serviceTicks: Int
    }
}

/// Content version.
public struct ContentVersion: Codable, Sendable, Equatable, Hashable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public static let initial = ContentVersion(major: 0, minor: 0, patch: 0)
}
