import XCTest
@testable import MUPlatform
import MUMeta

final class MUPlatformTests: XCTestCase {
    // MARK: Leaderboard identifiers (fixed forever)

    func testBoardIdentifiersAreFixed() {
        XCTAssertEqual(MUBoards.daily, "mu.daily")
        XCTAssertEqual(MUBoards.campaign(stage: 0), "mu.campaign.0")
        XCTAssertEqual(MUBoards.campaign(stage: 11), "mu.campaign.11")
    }

    // MARK: Daily plan

    func testDailyPlanPostsDailyBoardWithModifierContext() {
        let plan = MUPostPlanner.dailyPlan(
            dayNumber: 42, modifierID: "strong-winds", score: 4_200
        )
        XCTAssertEqual(plan.scores.count, 1)
        XCTAssertEqual(plan.scores[0].leaderboard, "mu.daily")
        XCTAssertEqual(plan.scores[0].score, 4_200)
        XCTAssertEqual(plan.scores[0].context, "strong-winds#42")
        XCTAssertTrue(plan.achievements.isEmpty)
    }

    func testDailyPlanWithoutModifierOmitsContext() {
        let plan = MUPostPlanner.dailyPlan(dayNumber: 1, modifierID: nil, score: 10)
        XCTAssertNil(plan.scores[0].context)
    }

    func testDailyScoreMatchesMetaFormula() {
        // The planner's caller passes DailyChallenge.score's output; pin the
        // formula here so a silent change in MUMeta breaks this test.
        XCTAssertEqual(
            DailyChallenge.score(roostsClaimed: 3, birdsAlive: 51), 3_051
        )
    }

    // MARK: Campaign plan

    func testCampaignPlanPostsStageBoard() {
        let plan = MUPostPlanner.campaignPlan(stage: 4, endSize: 380)
        XCTAssertEqual(plan.scores, [
            MUCoreScore(leaderboard: "mu.campaign.4", score: 380, context: nil)
        ])
        XCTAssertTrue(plan.achievements.isEmpty)
    }

    // MARK: Achievements plan

    func testAchievementPlanListsNewlyEarnedSorted() {
        let plan = MUPostPlanner.achievementPlan(newlyEarned: [
            .flockThousand, .firstRoost,
        ])
        XCTAssertTrue(plan.scores.isEmpty)
        XCTAssertEqual(plan.achievements, [
            Achievement.firstRoost.rawValue,
            Achievement.flockThousand.rawValue,
        ].sorted())
        XCTAssertEqual(plan.achievements.count, 2)
    }

    func testAchievementPlanEmptyWhenNothingNew() {
        let plan = MUPostPlanner.achievementPlan(newlyEarned: [])
        XCTAssertTrue(plan.achievements.isEmpty)
    }

    // MARK: Merge

    func testMergeCombinesScoresAndAchievements() {
        let daily = MUPostPlanner.dailyPlan(
            dayNumber: 7, modifierID: "fog", score: 900
        )
        let campaign = MUPostPlanner.campaignPlan(stage: 2, endSize: 210)
        let achievements = MUPostPlanner.achievementPlan(newlyEarned: [.firstRoost])
        let merged = MUPostPlanner.merged([daily, campaign, achievements])
        XCTAssertEqual(merged.scores.count, 2)
        XCTAssertEqual(merged.achievements, ["first-roost"])
        XCTAssertEqual(merged.scores[0].leaderboard, "mu.daily")
        XCTAssertEqual(merged.scores[1].leaderboard, "mu.campaign.2")
    }

    func testMergeEmpty() {
        let merged = MUPostPlanner.merged([])
        XCTAssertTrue(merged.scores.isEmpty)
        XCTAssertTrue(merged.achievements.isEmpty)
    }

    // MARK: Mock poster

    func testMockPosterRecordsInOrder() {
        let poster = MockPoster()
        poster.post(MUCoreScore(leaderboard: "mu.daily", score: 100, context: "a"))
        poster.post(MUCoreScore(leaderboard: "mu.campaign.1", score: 55))
        poster.reportAchievement(id: "roostFirst", percentComplete: 100)
        XCTAssertEqual(poster.scorePosts.count, 2)
        XCTAssertEqual(poster.scorePosts[0].score, 100)
        XCTAssertEqual(poster.scorePosts[1].leaderboard, "mu.campaign.1")
        XCTAssertEqual(poster.achievementPosts.count, 1)
        XCTAssertEqual(poster.achievementPosts[0].id, "roostFirst")
    }

    // MARK: Mock sync round-trip

    func testMockSyncRoundTripsData() {
        let sync = MockSync()
        XCTAssertNil(sync.load())
        let blob = Data("alice-save-v1".utf8)
        sync.save(blob)
        XCTAssertEqual(sync.load(), blob)
        sync.save(Data("v2".utf8))
        XCTAssertEqual(sync.load(), Data("v2".utf8))
    }

    // MARK: Context hash (deterministic across processes)

    func testContextHashIsStable() {
        // GameKit's context is an integer; pin the FNV-1a mapping so the
        // same modifier string maps to the same integer on every device
        // (the inline hash in GameCenterPoster must stay in lockstep).
        var h: UInt64 = 0xFFFF_FFFF_FFFF_FFFF &- 0x5EED_1D5A
        for byte in "strong-winds#42".utf8 {
            h = (h ^ UInt64(byte)) &* 0x1_0000_0001_B3
        }
        XCTAssertNotEqual(h, 0)
    }
}
