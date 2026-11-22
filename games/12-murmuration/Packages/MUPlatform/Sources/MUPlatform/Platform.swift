// MUPlatform: Game Center posting + iCloud progress (MU-P7.1).
// Depends on MUCore only; the pure plans are tested headlessly here, the
// real posters compile unconditionally and act only when signed in.
import Foundation
import MUMeta

// MARK: - Leaderboard identifiers (fixed strings; the maintainer's Game
// Center configuration references these — see docs/HANDOFF.md).

/// Leaderboard and achievement identifiers, fixed now so cross-device
/// identity holds forever (Night Market ADR-0012 pattern).
public enum MUBoards {
    /// The daily challenge board: `mu.daily`.
    public static let daily = "mu.daily"
    /// Campaign boards, one per stage index: `mu.campaign.<0-based stage>`.
    public static func campaign(stage: Int) -> String { "mu.campaign.\(stage)" }
}

/// One score the app wants recorded outside the device.
public struct MUCoreScore: Equatable, Sendable {
    public let leaderboard: String
    public let score: Int
    /// Challenge context (the daily modifier id), else nil.
    public let context: String?

    public init(leaderboard: String, score: Int, context: String? = nil) {
        self.leaderboard = leaderboard
        self.score = score
        self.context = context
    }
}

/// Everything one finished session wants to post, resolved as a pure plan.
public struct MUPostPlan: Equatable, Sendable {
    public let scores: [MUCoreScore]
    /// Newly earned achievement raw values (the 20 `Achievement` ids).
    public let achievements: [String]

    public init(scores: [MUCoreScore], achievements: [String]) {
        self.scores = scores
        self.achievements = achievements
    }
}

// MARK: - Posting protocols

/// Posts scores and achievements to Game Center.
public protocol ScoresPosting: Sendable {
    func post(_ score: MUCoreScore)
    func reportAchievement(id: String, percentComplete: Double)
}

/// Saves/loads one opaque profile blob for cross-device progress (iCloud
/// key-value store; the profile is well under the 1 MB limit).
public protocol ProgressSyncing: Sendable {
    func save(_ data: Data)
    func load() -> Data?
}

// MARK: - Pure plan resolution (headless-tested)

/// Resolves a finished session into the posts the app should make.
public enum MUPostPlanner {
    /// A daily day's outcome.
    /// - Parameters:
    ///   - dayNumber: the daily's day number (also the score context).
    ///   - modifierID: the daily modifier's raw value (e.g. "strong-winds").
    ///   - score: `DailyChallenge.score` over the day's roosts and flock.
    public static func dailyPlan(
        dayNumber: Int, modifierID: String?, score: Int
    ) -> MUPostPlan {
        MUPostPlan(
            scores: [MUCoreScore(
                leaderboard: MUBoards.daily, score: score,
                context: modifierID.map { "\($0)#\(dayNumber)" }
            )],
            achievements: []
        )
    }

    /// A campaign stage's outcome: the stage's best score posts only when
    /// it beats the previously recorded end size... no: campaign posts the
    /// stage's end size to its own board; the board's ordering keeps the
    /// best. Posting every completion is correct.
    /// - Parameter endSize: the flock size at the stage's end.
    public static func campaignPlan(stage: Int, endSize: Int) -> MUPostPlan {
        MUPostPlan(
            scores: [MUCoreScore(leaderboard: MUBoards.campaign(stage: stage), score: endSize)],
            achievements: []
        )
    }

    /// The achievements part: only newly earned ids, 100% complete.
    public static func achievementPlan(newlyEarned: [Achievement]) -> MUPostPlan {
        MUPostPlan(
            scores: [],
            achievements: newlyEarned.map(\.rawValue).sorted()
        )
    }

    /// Merge several plans into one (order: scores then achievements).
    public static func merged(_ plans: [MUPostPlan]) -> MUPostPlan {
        MUPostPlan(
            scores: plans.flatMap(\.scores),
            achievements: plans.flatMap(\.achievements)
        )
    }
}

// MARK: - Real posters (compiled unconditionally; act only when enabled)

/// The real Game Center poster. Posting only acts when Game Center is
/// authenticated; sandbox verification is the maintainer's (§8.2).
#if canImport(GameKit)
import GameKit
#endif
public final class GameCenterPoster: ScoresPosting, @unchecked Sendable {
    public init() {}

    public func post(_ score: MUCoreScore) {
        #if canImport(GameKit)
        let entry = GKScore(leaderboardIdentifier: score.leaderboard)
        entry.value = Int64(score.score)
        if let context = score.context {
            var h = UInt64(bitPattern: -0x5EED_1D5A)
            for byte in context.utf8 {
                h = (h ^ UInt64(byte)) &* 0x1_0000_0001_B3
            }
            entry.context = h
        }
        GKScore.report([entry], withCompletionHandler: nil)
        #endif
    }

    public func reportAchievement(id: String, percentComplete: Double) {
        #if canImport(GameKit)
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = min(100, max(0, percentComplete))
        if achievement.percentComplete > 0 {
            GKAchievement.report([achievement], withCompletionHandler: nil)
        }
        #endif
    }
}

/// iCloud key-value progress sync. Without the iCloud entitlement on this
/// build the store is a local no-op — exactly the pre-account behavior;
/// sandbox verification is the maintainer's (§8.2).
#if canImport(UIKit) || canImport(AppKit)
#endif
public final class ICloudSync: ProgressSyncing, @unchecked Sendable {
    public init() {}

    public func save(_ data: Data) {
        #if canImport(UIKit) || canImport(AppKit)
        NSUbiquitousKeyValueStore.default.set(data, forKey: "mu.progress")
        NSUbiquitousKeyValueStore.default.synchronize()
        #endif
    }

    public func load() -> Data? {
        #if canImport(UIKit) || canImport(AppKit)
        return NSUbiquitousKeyValueStore.default.data(forKey: "mu.progress")
        #else
        return nil
        #endif
    }
}

// MARK: - Deterministic fakes (tests + UI runs record every post in order)

/// Records every post in order for tests and UI runs.
public final class MockPoster: ScoresPosting, @unchecked Sendable {
    public private(set) var scorePosts: [MUCoreScore] = []
    public private(set) var achievementPosts: [(id: String, percent: Double)] = []

    public init() {}

    public func post(_ score: MUCoreScore) {
        scorePosts.append(score)
    }

    public func reportAchievement(id: String, percentComplete: Double) {
        achievementPosts.append((id, percentComplete))
    }
}

/// In-memory progress store for tests and fallbacks.
public final class MockSync: ProgressSyncing, @unchecked Sendable {
    private var storage: Data?

    public init() {}

    public func save(_ data: Data) {
        storage = data
    }

    public func load() -> Data? {
        storage
    }
}
