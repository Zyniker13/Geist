/// Content definitions for P3 (maps, schedules, upgrades, tutorial).
///
/// Map JSON lives in the game's `Resources/Content/maps/*.json` (see
/// ROADMAP.md §5). The RLE tile encoding is run-length pairs of
/// `(count: UInt8, value: UInt8)` where value is 0 ground, 1 plaza,
/// 2 canal, 3 building; pairs decode row-major over `size`.
import Foundation

public struct MapDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// [width, height]
    public var size: [Int]
    /// Base64 of RLE-encoded tile bytes (see above).
    public var tiles: String
    /// Gate positions [col, row] in id order.
    public var gates: [[Int]]
    /// Ticks after night start when each gate opens (0 = open at start).
    public var gateOpenTicks: [Int]
    /// Stall placement zones per stall color: [x, y, w, h] rects.
    public var zones: [String: [[Int]]]
    /// Candidate stride within zone rects (Taipei uses 2, others 1).
    public var stallStride: Int
    /// Starting lantern positions [col, row].
    public var lanternSpots: [[Int]]
    public var schedule: String
    public var palette: String
    /// Per-color demand weights (P3: distinct per map; keyed by debug name;
    /// missing colors default to 1).
    public var zoneWeights: [String: Int] = [:]

    public init(
        id: String, name: String, size: [Int], tiles: String, gates: [[Int]],
        gateOpenTicks: [Int], zones: [String: [[Int]]], stallStride: Int,
        lanternSpots: [[Int]], schedule: String, palette: String,
        zoneWeights: [String: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.tiles = tiles
        self.gates = gates
        self.gateOpenTicks = gateOpenTicks
        self.zones = zones
        self.stallStride = stallStride
        self.lanternSpots = lanternSpots
        self.schedule = schedule
        self.palette = palette
        self.zoneWeights = zoneWeights
    }

    /// Decodes the RLE tile stream to `width * height` tile types.
    public func decodeTiles() throws -> [TileType] {
        guard size.count == 2, size[0] > 0, size[1] > 0 else {
            throw ContentError.invalidField("size")
        }
        let width = size[0]
        let height = size[1]
        guard let data = Data(base64Encoded: tiles) else {
            throw ContentError.invalidField("tiles")
        }
        var result: [TileType] = []
        result.reserveCapacity(width * height)
        var index = 0
        while index + 1 < data.count {
            let count = Int(data[index])
            let value = data[index + 1]
            index += 2
            let tile: TileType
            switch value {
            case 0: tile = .ground
            case 1: tile = .plaza
            case 2: tile = .water(.canal)
            case 3: tile = .building
            default: throw ContentError.invalidField("tiles")
            }
            result.append(contentsOf: Array(repeating: tile, count: count))
        }
        guard result.count == width * height else {
            throw ContentError.invalidField("tiles count \(result.count) != \(width * height)")
        }
        return result
    }

    public func grid() throws -> Grid {
        Grid(tiles: try decodeTiles())
    }
}

/// A named spawn schedule (P5: Standard, Festival, Monsoon). `spawnsPerHour`
/// replaces `Spawner.hourlyRates` for the night when selected.
public struct ScheduleDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var startHour: Int
    public var hours: Int
    public var spawnsPerHour: [Int]

    public init(id: String, startHour: Int, hours: Int, spawnsPerHour: [Int]) {
        self.id = id
        self.startHour = startHour
        self.hours = hours
        self.spawnsPerHour = spawnsPerHour
    }
}

public enum ContentError: Error, CustomStringConvertible {
    case invalidField(String)
    case missingMap(String)

    public var description: String {
        switch self {
        case .invalidField(let field): return "invalid content field: \(field)"
        case .missingMap(let id): return "map not found: \(id)"
        }
    }
}

/// The eight upgrade kinds offered at hour boundaries (G3 counts).
public enum UpgradeContentKind: String, Codable, CaseIterable, Sendable {
    case walkwayBudget
    case lanterns
    case awning
    case busker
    case bridge
    case seatingBlock
    case fasterCooks
    case extraQueue
}
