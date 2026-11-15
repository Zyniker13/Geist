/// NMPlatform: input, platform abstraction.
/// Depends on NMCore.
import Foundation
import NMCore

// MARK: - Platform Types

/// Input event.
public enum InputEvent: Codable, Sendable, Equatable, Hashable {
    case tap(col: Int, row: Int)
    case pan(dx: Int, dy: Int)
    case pinch(scale: Float)
    case keyPress(String)
    case menuAction(String)
}

/// Platform input protocol.
public protocol InputProvider: Sendable {
    func pollEvents() -> [InputEvent]
}

// MARK: - Game Center posting (NM-P7.1)

/// One score or achievement the app wants recorded outside the device.
public struct ScorePost: Equatable, Sendable {
    /// Leaderboard identifier, e.g. `nm.map.taipei` or `nm.challenge.daily`.
    public let leaderboard: String
    public let score: Int
    public let context: String?

    public init(leaderboard: String, score: Int, context: String? = nil) {
        self.leaderboard = leaderboard
        self.score = score
        self.context = context
    }
}

/// Leaderboard identifiers, fixed strings reused by the maintainers'
/// Game Center configuration.
public enum Leaderboards {
    public static func map(_ mapId: String) -> String { "nm.map.\(mapId)" }
    public static let daily = "nm.challenge.daily"
    public static let weekly = "nm.challenge.weekly"
}

public protocol ScoresPosting: Sendable {
    func post(_ post: ScorePost)
    func reportAchievement(id: String, percentComplete: Double)
}

/// The plan of posts for a finished night (pure, tested in NMPlatform).
public enum LeaderboardPlan {
    /// Posts for one night's outcome: the map board, and any newly earned
    /// achievements. Challenge nights post to the challenge boards.
    public static func posts(
        for outcome: NightOutcomeSummary, newAchievements: [String]
    ) -> (scores: [ScorePost], achievements: [String]) {
        var scores: [ScorePost] = [
            ScorePost(leaderboard: Leaderboards.map(outcome.mapId), score: outcome.finalScore)
        ]
        switch outcome.challenge {
        case .daily:
            scores.append(ScorePost(leaderboard: Leaderboards.daily, score: outcome.finalScore, context: outcome.modifierId))
        case .weekly:
            scores.append(ScorePost(leaderboard: Leaderboards.weekly, score: outcome.finalScore, context: outcome.modifierId))
        case .none:
            break
        }
        return (scores, newAchievements)
    }
}

/// The outcome summary a poster needs — kept independent of the app layer
/// so NMPlatform does not depend on the app target.
public struct NightOutcomeSummary: Equatable, Sendable {
    public enum Challenge: Equatable, Sendable {
        case daily, weekly
    }

    public let mapId: String
    public let finalScore: Int
    public let challenge: Challenge?
    public let modifierId: String?

    public init(mapId: String, finalScore: Int, challenge: Challenge?, modifierId: String?) {
        self.mapId = mapId
        self.finalScore = finalScore
        self.challenge = challenge
        self.modifierId = modifierId
    }
}

/// The real poster: GameKit, compiled unconditionally; posting only acts
/// when Game Center is authenticated (sandbox verification is the
/// maintainer's, §8.2).
#if canImport(GameKit)
import GameKit
#endif
public final class GameCenterPoster: ScoresPosting, @unchecked Sendable {
    public init() {}

    public func post(_ post: ScorePost) {
        #if canImport(GameKit)
        let score = GKScore(leaderboardIdentifier: post.leaderboard)
        score.value = Int64(post.score)
        if let context = post.context {
            score.context = Challenge.hash(context)
        }
        GKScore.report([score], withCompletionHandler: nil)
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

/// Deterministic fake for tests and UI runs: records every post in order.
public final class MockPoster: ScoresPosting, @unchecked Sendable {
    public private(set) var scorePosts: [ScorePost] = []
    public private(set) var achievementPosts: [(id: String, percent: Double)] = []
    private let lock = NSLock()

    public init() {}

    public func post(_ post: ScorePost) {
        lock.lock()
        scorePosts.append(post)
        lock.unlock()
    }

    public func reportAchievement(id: String, percentComplete: Double) {
        lock.lock()
        achievementPosts.append((id, percentComplete))
        lock.unlock()
    }
}

// MARK: - Profile sync (NM-P7.2)

public protocol ProfileSyncing: Sendable {
    func save(_ data: Data)
    func load() -> Data?
}

/// iCloud key-value sync (the profile is well under the 1 MB KVS limit).
/// Without the iCloud entitlement on this build the store is a local no-op,
/// which is exactly the pre-account behavior; sandbox verification is the
/// maintainer's (§8.2).
public final class ICloudSync: ProfileSyncing, @unchecked Sendable {
    public init() {}

    public func save(_ data: Data) {
        #if canImport(UIKit) || canImport(AppKit)
        NSUbiquitousKeyValueStore.default.set(data, forKey: "profile")
        NSUbiquitousKeyValueStore.default.synchronize()
        #endif
    }

    public func load() -> Data? {
        #if canImport(UIKit) || canImport(AppKit)
        return NSUbiquitousKeyValueStore.default.data(forKey: "profile")
        #else
        return nil
        #endif
    }
}

/// Deterministic fake: an in-memory store for tests and fallbacks.
public final class MockSync: ProfileSyncing, @unchecked Sendable {
    private var storage: Data?
    private let lock = NSLock()

    public init() {}

    public func save(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    public func load() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
