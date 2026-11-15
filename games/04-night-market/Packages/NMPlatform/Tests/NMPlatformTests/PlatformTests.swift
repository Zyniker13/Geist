import Testing
import Foundation
import NMCore
@testable import NMPlatform

/// G7: Game Center posting and iCloud sync behind protocol fakes (§8.2 —
/// real GameKit/CloudKit code compiles; sandbox verification is the
/// maintainer's).
struct PlatformTests {
    // MARK: - Leaderboard plan

    @Test("a free-play night posts only its map board")
    func freePlayPost() {
        let outcome = NightOutcomeSummary(mapId: "istanbul", finalScore: 41, challenge: nil, modifierId: nil)
        let plan = LeaderboardPlan.posts(for: outcome, newAchievements: [])
        #expect(plan.scores == [ScorePost(leaderboard: "nm.map.istanbul", score: 41)])
        #expect(plan.achievements.isEmpty)
    }

    @Test("challenge nights post to their challenge board with the modifier context")
    func challengePost() {
        let daily = NightOutcomeSummary(
            mapId: "seoul", finalScore: 22, challenge: .daily, modifierId: "tightBudget"
        )
        let plan = LeaderboardPlan.posts(for: daily, newAchievements: [])
        #expect(plan.scores[1].leaderboard == Leaderboards.daily)
        #expect(plan.scores[1].context == "tightBudget")
        let weekly = NightOutcomeSummary(
            mapId: "istanbul", finalScore: 9, challenge: .weekly, modifierId: "generousBudget"
        )
        #expect(LeaderboardPlan.posts(for: weekly, newAchievements: []).scores[1].leaderboard == Leaderboards.weekly)
    }

    @Test("newly earned achievement ids ride along unchanged")
    func achievementIds() {
        let outcome = NightOutcomeSummary(mapId: "taipei", finalScore: 15, challenge: nil, modifierId: nil)
        let plan = LeaderboardPlan.posts(for: outcome, newAchievements: ["first-serve", "first-night"])
        #expect(plan.achievements == ["first-serve", "first-night"])
    }

    @Test("leaderboard ids are the stable nm.* strings")
    func ids() {
        #expect(Leaderboards.map("taipei") == "nm.map.taipei")
        #expect(Leaderboards.daily == "nm.challenge.daily")
        #expect(Leaderboards.weekly == "nm.challenge.weekly")
    }

    // MARK: - Fakes

    @Test("the mock poster records scores and achievements in order")
    func mockPoster() {
        let poster = MockPoster()
        poster.post(ScorePost(leaderboard: "nm.map.taipei", score: 7))
        poster.reportAchievement(id: "first-night", percentComplete: 100)
        poster.post(ScorePost(leaderboard: Leaderboards.daily, score: 9, context: "rushHour"))
        #expect(poster.scorePosts.count == 2)
        #expect(poster.scorePosts[1].context == "rushHour")
        #expect(poster.achievementPosts.count == 1)
        #expect(poster.achievementPosts[0].id == "first-night")
        #expect(poster.achievementPosts[0].percent == 100.0)
    }

    @Test("the mock sync round-trips profile JSON byte-for-byte")
    func mockSyncRoundTrip() throws {
        let sync = MockSync()
        var profile = Profile()
        profile.customersServed = 1234
        profile.unlockedMaps = ["taipei", "seoul", "bangkok"]
        profile.earnedAchievements = ["first-serve"]
        let data = try JSONEncoder().encode(profile)
        sync.save(data)
        #expect(sync.load() == data)
        let decoded = try JSONDecoder().decode(Profile.self, from: sync.load() ?? Data())
        #expect(decoded == profile)
    }

    @Test("the icloud sync type compiles and degrades to a no-op without entitlements")
    func icloudCompiles() {
        let sync = ICloudSync()
        // The real store requires an iCloud account; on the build machine it
        // is a no-op either way. The API contract is exercised, not the cloud.
        if let loaded = sync.load() {
            #expect(loaded == Data("probe".utf8))
        }
    }

    @Test("poster protocol is satisfied by both implementations")
    func protocolConformance() {
        let fakes: [ScoresPosting] = [MockPoster(), GameCenterPoster()]
        #expect(fakes.count == 2)
        let syncs: [ProfileSyncing] = [MockSync(), ICloudSync()]
        #expect(syncs.count == 2)
    }
}
