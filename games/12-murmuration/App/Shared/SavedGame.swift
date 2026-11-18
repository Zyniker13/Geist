// Murmuration app — local save/resume (S2.4).
//
// One JSON file per region under Application Support. The save captures
// everything a mid-day resume needs: the engine state, the RNG stream, the
// current day, and both pilot states so an autoplay resume behaves
// identically to the session it left.

import Foundation
import MUCore
import MUContent
import MUAI

/// A resumable game snapshot.
struct SavedGame: Codable {
    var regionID: String
    var day: Int
    var state: GameState
    var rng: SeededRNG
    var autoplayer: Autoplayer?
    var rival: GentleRival

    // MARK: - Storage

    private static func url(for regionID: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Murmuration", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("save-\(regionID).json")
    }

    static func store(_ save: SavedGame) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(save) else { return }
        try? data.write(to: url(for: save.regionID), options: .atomic)
    }

    static func load(regionID: String) -> SavedGame? {
        guard let data = try? Data(contentsOf: url(for: regionID)) else { return nil }
        return try? JSONDecoder().decode(SavedGame.self, from: data)
    }

    static func discard(regionID: String) {
        try? FileManager.default.removeItem(at: url(for: regionID))
    }
}
