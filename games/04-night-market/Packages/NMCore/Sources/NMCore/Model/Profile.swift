/// Profile progression (NM-P5.3/P5.4): unlock thresholds, the stats ledger,
/// and the twenty achievements. Pure functions over a value type — the app
/// layer persists it; the engine layer tests it.
public struct Profile: Codable, Equatable, Sendable {
    /// Total customers served across all nights.
    public var customersServed: Int = 0
    /// Nights played to completion (any schedule).
    public var nightsPlayed: Int = 0
    /// Nights where every open stall was still serving at dawn (ADR-0011).
    public var dawnsReached: Int = 0
    /// Nights finished without an overflow warning firing.
    public var calmNights: Int = 0
    /// Highest single-night score.
    public var bestNightScore: Int = 0
    /// Bridges placed across canals.
    public var bridgesPlaced: Int = 0
    /// Buskers hired.
    public var buskersHired: Int = 0
    /// Challenges completed to dawn (daily or weekly).
    public var challengesCompleted: Int = 0
    /// Distinct maps finished to dawn.
    public var mapsFinished: Set<String> = []
    /// Modifier combos finished to dawn.
    public var modifiersFinished: Set<String> = []
    /// Achievement ids already earned (never revoked).
    public var earnedAchievements: Set<String> = []
    /// Map ids unlocked so far (the first map is always unlocked).
    public var unlockedMaps: Set<String> = ["taipei"]
    /// True once the player has finished any night at dawn.
    public var sandboxUnlocked: Bool = false

    public init() {}
}

/// The map unlock ladder (NM-P5.3): each map needs a best-night score at or
/// above its threshold on any earlier map. Order mirrors the build order;
/// `taipei` is unlocked from the start.
public enum UnlockCatalog {
    /// Threshold in night score required on any previously unlocked map.
    public static let thresholds: [String: Int] = [
        "taipei": 0,
        "seoul": 15,
        "bangkok": 20,
        "marrakesh": 30,
        "istanbul": 40,
        "oaxaca": 55,
    ]

    /// The next map in ladder order unlocks when a night's score reaches its
    /// threshold; nothing unlocks while an earlier map is still locked.
    public static func newlyUnlocked(currently unlocked: Set<String>, afterScore score: Int) -> [String] {
        for (mapId, threshold) in thresholds.sorted(by: { $0.value < $1.value }) {
            if unlocked.contains(mapId) { continue }
            return score >= threshold ? [mapId] : []
        }
        return []
    }
}

/// One achievement: a stable id, a player-facing title, and a predicate over
/// the profile snapshot taken at dawn.
public struct Achievement: Sendable {
    public let id: String
    public let title: String
    public let isEarned: @Sendable (Profile) -> Bool

    public init(id: String, title: String, isEarned: @escaping @Sendable (Profile) -> Bool) {
        self.id = id
        self.title = title
        self.isEarned = isEarned
    }
}

/// The twenty achievements (NM-P5.4), fixed order for stable ids.
public enum AchievementCatalog {
    public static let all: [Achievement] = [
        Achievement(id: "first-serve", title: "First Serve") { $0.customersServed >= 1 },
        Achievement(id: "hundred-served", title: "Century Stalls") { $0.customersServed >= 100 },
        Achievement(id: "thousand-served", title: "Night Market Legend") { $0.customersServed >= 1_000 },
        Achievement(id: "ten-thousand-served", title: "Market Mogul") { $0.customersServed >= 10_000 },
        Achievement(id: "first-night", title: "Opening Night") { $0.nightsPlayed >= 1 },
        Achievement(id: "ten-nights", title: "Regular") { $0.nightsPlayed >= 10 },
        Achievement(id: "fifty-nights", title: "Fixture of the Block") { $0.nightsPlayed >= 50 },
        Achievement(id: "first-dawn", title: "In It For The Long Haul") { $0.dawnsReached >= 1 },
        Achievement(id: "ten-dawns", title: "Dawn Patrol") { $0.dawnsReached >= 10 },
        Achievement(id: "calm-night", title: "Cool Under Pressure") { $0.calmNights >= 1 },
        Achievement(id: "five-calm", title: "Unflappable") { $0.calmNights >= 5 },
        Achievement(id: "score-15", title: "Warming Up") { $0.bestNightScore >= 15 },
        Achievement(id: "score-30", title: "Bazaar Boss") { $0.bestNightScore >= 30 },
        Achievement(id: "score-55", title: "Sovereign of Snacks") { $0.bestNightScore >= 55 },
        Achievement(id: "bridge-builder", title: "Bridge Builder") { $0.bridgesPlaced >= 1 },
        Achievement(id: "five-bridges", title: "Crossing Authority") { $0.bridgesPlaced >= 5 },
        Achievement(id: "busker-backer", title: "Busker Backer") { $0.buskersHired >= 3 },
        Achievement(id: "challenge-complete", title: "Challenge Accepted") { $0.challengesCompleted >= 1 },
        Achievement(id: "all-maps", title: "World Tour") { $0.mapsFinished.count >= UnlockCatalog.thresholds.count },
        Achievement(id: "six-modifiers", title: "Rule Bender") { $0.modifiersFinished.count >= 6 },
    ]

    /// Achievements newly earned by a profile snapshot (id order stable).
    public static func newlyEarned(in profile: Profile) -> [Achievement] {
        all.filter { !profile.earnedAchievements.contains($0.id) && $0.isEarned(profile) }
    }
}
