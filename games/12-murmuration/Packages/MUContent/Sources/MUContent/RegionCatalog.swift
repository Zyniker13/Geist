// Murmuration Content — region catalog and validation (S2.3).
//
// The catalog loads regions from JSON files and validates them before use.
// The app loads the bundled regions; tests load from a directory.

import Foundation
import MUCore

/// A validated set of regions.
public struct RegionCatalog: Sendable {
    public let regions: [Region]

    public init(regions: [Region]) {
        self.regions = regions
    }

    /// Look up a region by id.
    public func region(id: String) -> Region? {
        regions.first { $0.id == id }
    }

    /// All region ids, in catalog order.
    public var ids: [String] { regions.map(\.id) }

    /// Load every `*.json` region file in a directory, sorted by file name.
    public static func load(from directory: URL) throws -> RegionCatalog {
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .map { directory.appendingPathComponent($0) }
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path }

        var regions: [Region] = []
        for file in files {
            let data = try Data(contentsOf: file)
            let region = try JSONDecoder().decode(Region.self, from: data)
            regions.append(region)
        }
        return RegionCatalog(regions: regions)
    }

    /// Load the bundled regions from `Resources/Content/regions`.
    public static func loadBundled() throws -> RegionCatalog {
        // The app bundle flattens the resource tree, so the region files sit
        // at the bundle root. Address them by name (robust to the flat
        // layout); try the nested `Content/regions` and `regions`
        // subdirectories first in case a future build preserves them.
        let names = ["commons", "delta", "fenlands", "gorge", "meadow", "ridge"]
        for base in bundleBaseCandidates("regions") {
            if let regions = try? loadNamedRegions(names, from: base) {
                return RegionCatalog(regions: regions)
            }
        }
        throw RegionError.missingRegions
    }

    /// Load the bundled solo-objective regions from `Resources/Content/solo`
    /// (P3.2). Solo regions are a separate content category from the main
    /// region set: they carry a `soloTargetBirds` objective and no rival, and
    /// are not part of the main region count. They are a small, fixed set,
    /// addressed by name so the lookup is robust to the app bundle flattening
    /// the resource tree.
    public static func loadSoloBundled() throws -> RegionCatalog {
        let names = ["first-roost", "tutorial-meadow"]
        for base in bundleBaseCandidates("solo") {
            if let regions = try? loadNamedRegions(names, from: base) {
                return RegionCatalog(regions: regions)
            }
        }
        throw RegionError.missingRegions
    }

    /// Candidate base directories for a resource category, in priority order:
    /// the nested `Content/<category>` and `<category>` subdirectories first,
    /// then the bundle root (the app bundle flattens the resource tree).
    private static func bundleBaseCandidates(_ category: String) -> [URL] {
        guard let root = Bundle.main.resourceURL else { return [] }
        return [
            root.appendingPathComponent("Content/\(category)"),
            root.appendingPathComponent(category),
            root,
        ]
    }

    /// Load a set of named region JSON files from `base` (P3.2). Each file
    /// must be at `base/<name>.json`. Addressing files by name (rather than
    /// by subdirectory) is robust to the app bundle flattening the resource
    /// tree.
    static func loadNamedRegions(_ names: [String], from base: URL) throws -> [Region] {
        var regions: [Region] = []
        for name in names {
            let url = base.appendingPathComponent("\(name).json")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw RegionError.missingRegions
            }
            let data = try Data(contentsOf: url)
            regions.append(try JSONDecoder().decode(Region.self, from: data))
        }
        return regions
    }

    /// Validate a region. Returns a list of problems (empty when valid).
    public static func validate(_ region: Region) -> [String] {
        var problems: [String] = []

        if region.id.isEmpty {
            problems.append("id is empty")
        }
        if region.name.isEmpty {
            problems.append("name is empty")
        }
        if region.worldWidth <= 0 {
            problems.append("worldWidth must be > 0")
        }
        if region.worldHeight <= 0 {
            problems.append("worldHeight must be > 0")
        }
        if region.birdCount <= 0 {
            problems.append("birdCount must be > 0")
        }
        if region.falconCount < 0 {
            problems.append("falconCount must be >= 0")
        }
        if region.rivalStartBirds < 0 {
            problems.append("rivalStartBirds must be >= 0")
        }
        if region.rivalStartBirds > region.birdCount {
            problems.append("rivalStartBirds must be <= birdCount")
        }
        if region.hasRival != (region.rivalStartBirds > 0) {
            problems.append("hasRival must match rivalStartBirds > 0")
        }
        if region.soloTargetBirds < 0 {
            problems.append("soloTargetBirds must be >= 0")
        }
        if region.soloTargetBirds > region.birdCount {
            problems.append("soloTargetBirds must be <= birdCount")
        }
        if region.hasRival && region.soloTargetBirds > 0 {
            problems.append("soloTargetBirds must be 0 in a rival region")
        }
        if region.roosts.isEmpty {
            problems.append("region needs at least one roost")
        }
        if region.fields.isEmpty {
            problems.append("region needs at least one field")
        }
        if !region.palette.isValid {
            problems.append("palette has an out-of-range color")
        }

        for (i, roost) in region.roosts.enumerated() {
            if roost.radius <= 0 {
                problems.append("roost[\(i)] radius must be > 0")
            }
            if roost.x < 0 || roost.x >= region.worldWidth
                || roost.y < 0 || roost.y >= region.worldHeight
            {
                problems.append("roost[\(i)] center is out of bounds")
            }
        }
        for (i, field) in region.fields.enumerated() {
            if field.radius <= 0 {
                problems.append("field[\(i)] radius must be > 0")
            }
            if field.richness <= 0 {
                problems.append("field[\(i)] richness must be > 0")
            }
            if field.x < 0 || field.x >= region.worldWidth
                || field.y < 0 || field.y >= region.worldHeight
            {
                problems.append("field[\(i)] center is out of bounds")
            }
        }
        if region.obstacles.count > 16 {
            problems.append("obstacles must be <= 16 (kernel capacity)")
        }
        for (i, obstacle) in region.obstacles.enumerated() {
            if obstacle.radius <= 0 {
                problems.append("obstacle[\(i)] radius must be > 0")
            }
            if obstacle.x < 0 || obstacle.x >= region.worldWidth
                || obstacle.y < 0 || obstacle.y >= region.worldHeight
            {
                problems.append("obstacle[\(i)] center is out of bounds")
            }
        }
        return problems
    }

    /// Validate every region in the catalog. Returns a map of region id to
    /// problems (only invalid regions appear).
    public func validateAll() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for region in regions {
            let problems = RegionCatalog.validate(region)
            if !problems.isEmpty {
                result[region.id] = problems
            }
        }
        return result
    }
}

/// Errors thrown while loading regions.
public enum RegionError: Error, Equatable {
    case missingRegions
}
