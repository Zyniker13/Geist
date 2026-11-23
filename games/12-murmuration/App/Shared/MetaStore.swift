// Murmuration app — meta persistence (MU-P5).
//
// One JSON file under Application Support holds the campaign progress,
// daily best scores, lifetime stats, and the earned-achievement set.
// MUMeta owns the pure models; this file is the app's storage layer:
// load, mutate through the pure APIs, save.

import Foundation
import MUMeta
import MUPlatform

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
    /// Accessibility settings (MU-P8.1): reduce-motion and high-contrast
    /// toggles persist with the profile so they survive relaunches and
    /// sync through the same iCloud blob as the rest of the meta.
    var reduceMotion = false
    var highContrastRival = false
    /// Falcon-assist steering (MU-P8.2): a sim-level option, persisted
    /// with the profile so it survives relaunches and iCloud sync.
    var falconAssist = false

    /// Effective reduce motion: the user toggle OR the system setting.
    /// Evaluated on the app side (the packages stay platform-free).
    func reduceMotionEffective(systemEnabled: Bool) -> Bool {
        reduceMotion || systemEnabled
    }

    /// The campaign route the progress applies to; re-derive stages from
    /// the shipped route each load.
    static let campaignRoute = [
        "meadow", "commons", "gorge", "ridge", "delta", "fenlands",
        "commons", "gorge", "delta", "ridge", "meadow", "fenlands",
    ]
}

/// Meta storage (load/apply/save).
@MainActor
enum MetaStore {
    /// iCloud progress sync (MU-P7.1): real store in apps, injectable for
    /// tests. Restoring on first launch merges cloud progress into a fresh
    /// local file (the profile is well under the 1 MB KVS limit).
    nonisolated(unsafe) static var syncing: ProgressSyncing = ICloudSync()

    private static func url() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Murmuration", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("meta.json")
    }

    static func load() -> MetaState {
        // UI-test isolation (MU-P8.2): a persisted toggle from a previous
        // test's failed cleanup (falconAssist etc.) silently alters later
        // runs on a dirty simulator — CI's fresh sim never sees it, so the
        // local-only divergence looks like a non-reproducible flake. The
        // `-uitest-reset` flag makes every in-session load return a fresh
        // profile (nothing read, nothing written back to disk), which
        // reproduces CI's fresh-sim environment locally. Persistence
        // tests opt OUT by not passing the flag, so real on-disk
        // persistence stays covered.
        if MULaunch.arguments().contains("-uitest-reset") {
            return MetaState()
        }
        let fresh = !FileManager.default.fileExists(atPath: url().path)
        if fresh, let cloud = syncing.load(),
            let restored = try? JSONDecoder().decode(MetaState.self, from: cloud)
        {
            store(restored)
            return restored
        }
        guard let data = try? Data(contentsOf: url()) else { return MetaState() }
        return (try? JSONDecoder().decode(MetaState.self, from: data)) ?? MetaState()
    }

    static func store(_ state: MetaState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url(), options: .atomic)
        syncing.save(data)
    }

    /// Record a finished session: fold stats, record daily bests, and
    /// return the newly earned achievements (caller surfaces them) with
    /// the count of Game Center posts made (MU-P7.1 debug row).
    /// `modifierID` is the daily's modifier raw value used as the
    /// Game Center post context; nil outside the daily.
    static func record(
        _ outcome: SessionOutcome, dayCompleted: Bool, dailyDayNumber: Int?,
        modifierID: String? = nil, campaignStageIndex: Int? = nil,
        poster: ScoresPosting = GameCenterPoster()
    ) -> (state: MetaState, fresh: [Achievement], posted: Int) {
        var state = load()
        state.stats.fold(session: outcome, dayCompleted: dayCompleted)
        var posts: [MUPostPlan] = []
        if let dayNumber = dailyDayNumber {
            let score = DailyChallenge.score(
                roostsClaimed: outcome.roostsClaimed, birdsAlive: outcome.peakFlock
            )
            state.dailyScores = DailyScores.record(
                DailyScore(dayNumber: dayNumber, score: score),
                into: state.dailyScores
            )
            posts.append(
                MUPostPlanner.dailyPlan(
                    dayNumber: dayNumber, modifierID: modifierID, score: score
                ))
        }
        if let stage = campaignStageIndex {
            posts.append(
                MUPostPlanner.campaignPlan(
                    stage: max(stage, 0), endSize: outcome.peakFlock
                ))
        }
        let nowEarned = Achievements.earned(at: state.stats)
        let fresh = nowEarned.subtracting(Set(state.earnedAchievements.compactMap(Achievement.init(rawValue:))))
        state.earnedAchievements = nowEarned.map(\.rawValue).sorted()
        posts.append(MUPostPlanner.achievementPlan(newlyEarned: Array(fresh)))
        store(state)
        let merged = MUPostPlanner.merged(posts)
        for post in merged.scores {
            poster.post(post)
        }
        for id in merged.achievements {
            poster.reportAchievement(id: id, percentComplete: 100)
        }
        return (
            state, Array(fresh).sorted { $0.rawValue < $1.rawValue },
            posted: merged.scores.count + merged.achievements.count
        )
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

    /// Telemetry-free stats export (MU-P9.3): encodes the lifetime stats,
    /// daily scores, and campaign end sizes with a format header, and
    /// writes them to Documents as `murmuration-stats.json`. Nothing is
    /// uploaded; the player shares the file themselves. No identifiers —
    /// the export holds only aggregate play counts.
    static func exportStats() -> String {
        struct Export: Codable {
            var format = "murmuration-stats"
            var version = 1
            var stats: LifetimeStats
            var dailyScores: [DailyScore]
            var campaignEndSizes: [Int?]
        }
        let state = load()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("murmuration-stats.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(
                Export(
                    stats: state.stats, dailyScores: state.dailyScores,
                    campaignEndSizes: state.campaignEndSizes
                ))
            try data.write(to: url, options: .atomic)
            return "saved \(url.lastPathComponent)"
        } catch {
            return "export failed"
        }
    }
}
