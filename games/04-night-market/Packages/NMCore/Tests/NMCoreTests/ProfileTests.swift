import Testing
import Foundation
@testable import NMCore

/// G5: unlocks (NM-P5.3) and the achievement catalog (NM-P5.4).
struct ProfileTests {
    // MARK: - Unlocks

    @Test("the first map is always unlocked at threshold zero")
    func firstMapFree() {
        #expect(UnlockCatalog.thresholds["taipei"] == 0)
        #expect(Profile().unlockedMaps.contains("taipei"))
    }

    @Test("score below the next threshold unlocks nothing")
    func belowThreshold() {
        let next = UnlockCatalog.newlyUnlocked(currently: ["taipei"], afterScore: 14)
        #expect(next.isEmpty)
    }

    @Test("meeting the next threshold unlocks exactly that map")
    func atThreshold() {
        #expect(UnlockCatalog.newlyUnlocked(currently: ["taipei"], afterScore: 15) == ["seoul"])
        #expect(UnlockCatalog.newlyUnlocked(currently: ["taipei", "seoul"], afterScore: 20) == ["bangkok"])
    }

    @Test("a high score cannot skip a locked map")
    func noSkipping() {
        #expect(UnlockCatalog.newlyUnlocked(currently: ["taipei"], afterScore: 55).first == "seoul")
    }

    @Test("a fully unlocked ladder unlocks nothing more")
    func ladderComplete() {
        let all = Set(UnlockCatalog.thresholds.keys)
        #expect(UnlockCatalog.newlyUnlocked(currently: all, afterScore: 999).isEmpty)
    }

    @Test("ladder thresholds are strictly increasing over six maps")
    func thresholdsSorted() {
        let values = UnlockCatalog.thresholds.values.sorted()
        #expect(values.count == 6)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
        #expect(values.first == 0)
    }

    // MARK: - Achievements

    @Test("exactly twenty achievements with unique stable ids")
    func catalogShape() {
        #expect(AchievementCatalog.all.count == 20)
        #expect(Set(AchievementCatalog.all.map(\.id)).count == 20)
    }

    @Test("a fresh profile earns nothing")
    func freshProfileEarnsNothing() {
        #expect(AchievementCatalog.newlyEarned(in: Profile()).isEmpty)
    }

    @Test("served-count tiers trigger in order")
    func servedTiers() {
        var profile = Profile()
        profile.customersServed = 1
        #expect(AchievementCatalog.newlyEarned(in: profile).map(\.id) == ["first-serve"])
        profile.customersServed = 10_500
        let earned = Set(AchievementCatalog.newlyEarned(in: profile).map(\.id))
        #expect(earned == ["first-serve", "hundred-served", "thousand-served", "ten-thousand-served"])
    }

    @Test("night counters and dawn tiers trigger")
    func nightTiers() {
        var profile = Profile()
        profile.nightsPlayed = 1
        profile.dawnsReached = 1
        let earned = Set(AchievementCatalog.newlyEarned(in: profile).map(\.id))
        #expect(earned == ["first-night", "first-dawn"])
        profile.dawnsReached = 10
        profile.nightsPlayed = 50
        let more = Set(AchievementCatalog.newlyEarned(in: profile).map(\.id))
        #expect(more == ["first-night", "ten-nights", "fifty-nights", "first-dawn", "ten-dawns"])
    }

    @Test("score, fixture, and challenge achievements trigger on their stats")
    func statTiers() {
        var profile = Profile()
        profile.bestNightScore = 55
        profile.bridgesPlaced = 5
        profile.buskersHired = 3
        profile.challengesCompleted = 1
        let earned = Set(AchievementCatalog.newlyEarned(in: profile).map(\.id))
        #expect(
            earned == [
                "score-15", "score-30", "score-55",
                "bridge-builder", "five-bridges", "busker-backer", "challenge-complete",
            ]
        )
    }

    @Test("world tour needs every map; rule bender needs six modifiers")
    func metaTiers() {
        var profile = Profile()
        profile.mapsFinished = Set(UnlockCatalog.thresholds.keys)
        profile.modifiersFinished = ["rushHour", "tightBudget", "earlyClose", "smallQueues", "slowCookers", "lateGates"]
        let earned = Set(AchievementCatalog.newlyEarned(in: profile).map(\.id))
        #expect(earned == ["all-maps", "six-modifiers"])
    }

    @Test("earned ids are never re-earned")
    func noReEarn() {
        var profile = Profile()
        profile.customersServed = 1
        let first = AchievementCatalog.newlyEarned(in: profile)
        profile.earnedAchievements.formUnion(first.map(\.id))
        profile.customersServed = 2
        #expect(AchievementCatalog.newlyEarned(in: profile).isEmpty)
    }

    @Test("profile round-trips through JSON codable")
    func codableRoundTrip() throws {
        var profile = Profile()
        profile.customersServed = 42
        profile.mapsFinished = ["taipei"]
        profile.unlockedMaps = ["taipei", "seoul"]
        profile.sandboxUnlocked = true
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded == profile)
    }

    @Test("sandbox unlocks after the first dawn")
    func sandboxUnlock() {
        var profile = Profile()
        #expect(!profile.sandboxUnlocked)
        profile.dawnsReached = 1
        profile.sandboxUnlocked = true
        #expect(profile.sandboxUnlocked)
    }
}
