// Murmuration app — meta persistence (MU-P5).
//
// One JSON file under Application Support holds the campaign progress,
// daily best scores, lifetime stats, and the earned-achievement set.
// MUMeta owns the pure models; this file is the app's storage layer:
// load, mutate through the pure APIs, save.

import Foundation
import MUMeta

/// The persisted meta state.
struct MetaState: Codable {
    /// Campaign end sizes by stage index (nil = not reached).
    var campaignEndSizes: [Int?] = []
    /// Daily best scores (one record per date).
    var dailyScores: [DailyScore] = []
    /// Lifetime stats.
    var stats = LifetimeStats()
    /// Achievement ids already awarded (so new ones can be surfaced).
    var earnedAchievements: [String] = []

    /// The campaign route the progress applies to; re-derive stages from
    /// the shipped route each load.
    static let campaignRoute = [
        "meadow", "commons", "gorge", "ridge", "delta", "fenlands",
        "commons", "gorge", "delta", "ridge", "meadow", "fenlands",
    ]
}

/// Meta storage (load/apply/save).
enum MetaStore {
    private static func url() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Murmuration", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("meta.json")
    }

    static func load() -> MetaState {
        guard let data = try? Data(contentsOf: url()) else { return MetaState() }
        return (try? JSONDecoder().decode(MetaState.self, from: data)) ?? MetaState()
    }

    static func store(_ state: MetaState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url(), options: .atomic)
    }

    /// Record a finished session: fold stats, record daily bests, and
    /// return the newly earned achievements (caller surfaces them).
    static func record(
        _ outcome: SessionOutcome, dayCompleted: Bool, dailyDayNumber: Int?
    ) -> (MetaState, [Achievement]) {
        var state = load()
        state.stats.fold(session: outcome, dayCompleted: dayCompleted)
        if let dayNumber = dailyDayNumber {
            let score = DailyChallenge.score(
                roostsClaimed: outcome.roostsClaimed, birdsAlive: outcome.peakFlock
            )
            state.dailyScores = DailyScores.record(
                DailyScore(dayNumber: dayNumber, score: score),
                into: state.dailyScores
            )
        }
        let nowEarned = Achievements.earned(at: state.stats)
        let fresh = nowEarned.subtracting(Set(state.earnedAchievements.compactMap(Achievement.init(rawValue:))))
        state.earnedAchievements = nowEarned.map(\.rawValue).sorted()
        store(state)
        return (state, Array(fresh).sorted { $0.rawValue < $1.rawValue })
    }

    /// Record a campaign stage's end size and carry it forward.
    static func recordCampaignStage(index: Int, endSize: Int) -> MetaState {
        var state = load()
        while state.campaignEndSizes.count <= index {
            state.campaignEndSizes.append(nil)
        }
        state.campaignEndSizes[index] = endSize
        store(state)
        return state
    }

    /// Reset campaign progress only (stats and dailies persist).
    static func resetCampaign() {
        var state = load()
        state.campaignEndSizes = []
        store(state)
    }
}
