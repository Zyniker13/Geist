import XCTest
@testable import MUMeta
import MUContent
import MUCore

final class CampaignTests: XCTestCase {
    /// A minimal region map for carry math: region id -> bird count.
    private func regions(_ counts: [String: Int]) -> [String: Region] {
        Dictionary(
            uniqueKeysWithValues: counts.map { id, count in
                (id, Self.region(id: id, birds: count))
            }
        )
    }

    private static func region(id: String, birds: Int) -> Region {
        Region(
            id: id, name: id,
            worldWidth: 2048, worldHeight: 1536,
            birdCount: birds, falconCount: 0,
            hasRival: false, rivalStartBirds: 0,
            soloTargetBirds: 0,
            windSeedOffset: 0, seed: 1,
            roosts: [], fields: [], palette: RegionPalette.standard,
            obstacles: [], windPattern: .uniform, falconBehavior: .patrol
        )
    }

    func testCarriedSizeFlowsBetweenStages() {
        let campaign = Campaign(route: ["a", "b", "c"])
        let rs = regions(["a": 1000, "b": 1000, "c": 1000])
        let stages = campaign.stages(
            startBirds: 800, endSizes: [900, 700, nil], regions: rs
        )
        XCTAssertEqual(stages[0].regionID, "a")
        XCTAssertEqual(stages[0].carriedBirds, 800)
        XCTAssertEqual(stages[1].carriedBirds, 900, "stage 1 carries stage 0's end size")
        XCTAssertEqual(stages[2].carriedBirds, 700, "stage 2 carries stage 1's end size")
        XCTAssertEqual(stages.count, 3, "all stages present once the next stage is reached")
    }

    func testCarryClampedToFloorAndRegionCap() {
        let campaign = Campaign(route: ["a", "b"], carryFloor: 400)
        let rs = regions(["a": 1000, "b": 600])
        // Wipe out in stage 0 -> floor, not 12.
        var stages = campaign.stages(startBirds: 1000, endSizes: [12, nil], regions: rs)
        XCTAssertEqual(stages[1].carriedBirds, 400, "carry floor")
        // Huge end size -> clamped to the next region's bird count.
        stages = campaign.stages(startBirds: 1000, endSizes: [5000, nil], regions: rs)
        XCTAssertEqual(stages[1].carriedBirds, 600, "region cap")
    }

    func testNextStageAndCompletion() {
        let campaign = Campaign(route: ["a", "b", "c"])
        XCTAssertEqual(campaign.nextStage(endSizes: []), 0)
        XCTAssertEqual(campaign.nextStage(endSizes: [nil, nil, nil]), 0)
        XCTAssertEqual(campaign.nextStage(endSizes: [800, nil, nil]), 1)
        XCTAssertEqual(campaign.nextStage(endSizes: [800, 700, 600]), 3)
        XCTAssertTrue(campaign.isComplete(endSizes: [800, 700, 600]))
        XCTAssertFalse(campaign.isComplete(endSizes: [800, nil, nil]))
        XCTAssertEqual(campaign.finalFlock(endSizes: [800, 700, 600]), 600)
        XCTAssertNil(campaign.finalFlock(endSizes: [nil, nil, nil]))
    }

    func testRouteIsTwelveRegions() {
        // The shipped route: all six regions x the catalog's two-visit
        // split (see docs/STATUS.md P5.1 note) — twelve stages.
        let campaign = Campaign(route: Array(repeating: "meadow", count: 12))
        XCTAssertEqual(campaign.stageCount, 12)
    }
}

final class DailyTests: XCTestCase {
    /// The G5 check: for 30 consecutive dates the derived daily setup is
    /// stable and the modifier cycles through all six.
    func testDailyIdenticalAcrossDatesAndModifierCycle() {
        var seen: Set<DailyModifier> = []
        var previous: [DailyChallenge] = []
        for day in 0..<30 {
            let date = DailyChallenge.epoch.addingTimeInterval(
                TimeInterval(day) * DailyChallenge.secondsPerDay
            )
            let a = DailyChallenge(date: DailyChallenge.epoch, now: date)
            let b = DailyChallenge(date: DailyChallenge.epoch, now: date)
            XCTAssertEqual(a, b, "same date derives the same challenge (day \(day))")
            XCTAssertEqual(a.dayNumber, day)
            seen.insert(a.modifier)
            previous.append(a)
        }
        XCTAssertEqual(seen.count, 6, "all six modifiers appear in 30 days: \(seen)")
        // The wind offset is stable per date and unique across the 30.
        let offsets = Set(previous.map(\.windSeedOffset))
        XCTAssertEqual(offsets.count, 30, "each date carries its own wind map")
    }

    func testDifferentDatesDeriveDifferentModifiers() {
        let epoch = DailyChallenge.epoch
        let day0 = DailyChallenge(date: epoch, now: epoch)
        let day1 = DailyChallenge(
            date: epoch, now: epoch.addingTimeInterval(DailyChallenge.secondsPerDay)
        )
        XCTAssertNotEqual(day0.modifier, day1.modifier)
        XCTAssertNotEqual(day0.windSeedOffset, day1.windSeedOffset)
    }

    func testScoreAndBestScoreBookkeeping() {
        XCTAssertEqual(DailyChallenge.score(roostsClaimed: 2, birdsAlive: 900), 2_900)
        var scores: [DailyScore] = []
        scores = DailyScores.record(DailyScore(dayNumber: 5, score: 2_900), into: scores)
        scores = DailyScores.record(DailyScore(dayNumber: 5, score: 3_100), into: scores)
        scores = DailyScores.record(DailyScore(dayNumber: 6, score: 1_500), into: scores)
        XCTAssertEqual(DailyScores.best(for: 5, in: scores), 3_100)
        XCTAssertEqual(DailyScores.best(for: 6, in: scores), 1_500)
        XCTAssertNil(DailyScores.best(for: 7, in: scores))
        XCTAssertEqual(scores.count, 2, "one record per day")
    }

    func testUTCDateString() {
        XCTAssertEqual(
            DailyChallenge.utcDateString(DailyChallenge.epoch), "2026-01-01"
        )
    }
}

final class AchievementTests: XCTestCase {
    func testTwentyAchievements() {
        XCTAssertEqual(Achievement.allCases.count, 20)
    }

    func testThresholdsFlipAtExactlyTheBoundary() {
        var stats = LifetimeStats()
        for achievement in Achievement.allCases {
            XCTAssertFalse(achievement.isEarned(stats), "\(achievement.rawValue) starts unearned")
        }
        stats.totalRoostsClaimed = 1
        XCTAssertTrue(Achievement.firstRoost.isEarned(stats))
        XCTAssertFalse(Achievement.roostTen.isEarned(stats))
        stats.largestFlock = 1_000
        XCTAssertTrue(Achievement.flockThousand.isEarned(stats))
        XCTAssertFalse(Achievement.flockTwoThousand.isEarned(stats))
        stats.longestUnbrokenFlight = 7
        XCTAssertTrue(Achievement.unbrokenSeven.isEarned(stats))
        XCTAssertFalse(Achievement.unbrokenThirty.isEarned(stats))
    }

    func testSurvivorRequiresCleanDays() {
        var stats = LifetimeStats(daysCompleted: 5, totalBirdsStarved: 1)
        XCTAssertFalse(Achievement.survivor.isEarned(stats))
        stats.totalBirdsStarved = 0
        XCTAssertTrue(Achievement.survivor.isEarned(stats))
    }

    func testFoldAccumulatesStatsAndStreaks() {
        var stats = LifetimeStats()
        stats.fold(
            session: SessionOutcome(
                peakFlock: 1_500, roostsClaimed: 2, birdsStarved: 40
            ),
            dayCompleted: true
        )
        stats.fold(
            session: SessionOutcome(
                peakFlock: 1_800, roostsClaimed: 1, birdsStarved: 0
            ),
            dayCompleted: true
        )
        stats.fold(
            session: SessionOutcome(
                peakFlock: 1_700, roostsClaimed: 0, birdsStarved: 10, isVersus: true
            ),
            dayCompleted: false
        )
        XCTAssertEqual(stats.largestFlock, 1_800)
        XCTAssertEqual(stats.totalRoostsClaimed, 3)
        XCTAssertEqual(stats.totalBirdsStarved, 50)
        XCTAssertEqual(stats.daysCompleted, 2)
        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.longestUnbrokenFlight, 2)
        XCTAssertEqual(stats.versusPlayed, 1)
        let earned = Achievements.earned(at: stats)
        XCTAssertTrue(earned.contains(.flockThousand))
        XCTAssertTrue(earned.contains(.firstRoost))
        XCTAssertFalse(earned.contains(.roostTen))
    }

    func testCampaignEndFoldsIntoCampaignCount() {
        var stats = LifetimeStats()
        stats.fold(
            session: SessionOutcome(
                peakFlock: 900, roostsClaimed: 3, birdsStarved: 0, isCampaignEnd: true
            ),
            dayCompleted: true
        )
        XCTAssertEqual(stats.campaignsCompleted, 1)
        XCTAssertTrue(Achievement.firstCampaign.isEarned(stats))
    }
}
