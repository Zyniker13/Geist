// Murmuration Meta — achievements and lifetime stats (MU-P5.3).
//
// Twenty achievements over the campaign/daily/solo surfaces, plus the
// two lifetime stats the roadmap names (largest flock, longest unbroken
// flight). Achievement evaluation is a pure function over a stats
// snapshot; persistence lives in the app layer.

import Foundation

/// Lifetime stats accumulated across sessions (pure values; storage is
/// the app's job).
public struct LifetimeStats: Codable, Sendable, Equatable {
    /// Largest flock size ever reached (peak birds alive).
    public var largestFlock: Int
    /// Longest run of consecutive days with at least one completed
    /// session (the "unbroken flight").
    public var longestUnbrokenFlight: Int
    /// Current unbroken streak (to keep the running max computable).
    public var currentStreak: Int
    /// Total days completed.
    public var daysCompleted: Int
    /// Total roosts claimed across all sessions.
    public var totalRoostsClaimed: Int
    /// Total birds starved across all sessions.
    public var totalBirdsStarved: Int
    /// Campaigns completed.
    public var campaignsCompleted: Int
    /// Distinct daily dates played.
    public var dailiesPlayed: Int
    /// Versus sessions played.
    public var versusPlayed: Int

    public init(
        largestFlock: Int = 0,
        longestUnbrokenFlight: Int = 0,
        currentStreak: Int = 0,
        daysCompleted: Int = 0,
        totalRoostsClaimed: Int = 0,
        totalBirdsStarved: Int = 0,
        campaignsCompleted: Int = 0,
        dailiesPlayed: Int = 0,
        versusPlayed: Int = 0
    ) {
        self.largestFlock = largestFlock
        self.longestUnbrokenFlight = longestUnbrokenFlight
        self.currentStreak = currentStreak
        self.daysCompleted = daysCompleted
        self.totalRoostsClaimed = totalRoostsClaimed
        self.totalBirdsStarved = totalBirdsStarved
        self.campaignsCompleted = campaignsCompleted
        self.dailiesPlayed = dailiesPlayed
        self.versusPlayed = versusPlayed
    }

    /// Fold one completed session into the stats. `dayCompleted` marks a
    /// session that ran to dusk (any mode); streaks count consecutive
    /// completed days within the folded sequence.
    public mutating func fold(
        session: SessionOutcome, dayCompleted: Bool
    ) {
        largestFlock = max(largestFlock, session.peakFlock)
        totalRoostsClaimed += session.roostsClaimed
        totalBirdsStarved += session.birdsStarved
        if session.isVersus { versusPlayed += 1 }
        if session.isDaily { dailiesPlayed += 1 }
        if session.isCampaignEnd { campaignsCompleted += 1 }
        guard dayCompleted else { return }
        daysCompleted += 1
        currentStreak += 1
        longestUnbrokenFlight = max(longestUnbrokenFlight, currentStreak)
    }
}

/// One completed session's counters, as the app reports them.
public struct SessionOutcome: Sendable, Equatable {
    public var peakFlock: Int
    public var roostsClaimed: Int
    public var birdsStarved: Int
    public var isVersus: Bool
    public var isDaily: Bool
    public var isCampaignEnd: Bool

    public init(
        peakFlock: Int,
        roostsClaimed: Int,
        birdsStarved: Int,
        isVersus: Bool = false,
        isDaily: Bool = false,
        isCampaignEnd: Bool = false
    ) {
        self.peakFlock = peakFlock
        self.roostsClaimed = roostsClaimed
        self.birdsStarved = birdsStarved
        self.isVersus = isVersus
        self.isDaily = isDaily
        self.isCampaignEnd = isCampaignEnd
    }
}

/// The twenty achievements (MU-P5.3).
public enum Achievement: String, CaseIterable, Codable, Sendable {
    case firstRoost = "first-roost"
    case roostTen = "roost-ten"
    case roostFifty = "roost-fifty"
    case roostHundred = "roost-hundred"
    case flockThousand = "flock-thousand"
    case flockTwoThousand = "flock-two-thousand"
    case flockThreeThousand = "flock-three-thousand"
    case unbrokenThree = "unbroken-three"
    case unbrokenSeven = "unbroken-seven"
    case unbrokenThirty = "unbroken-thirty"
    case daysTen = "days-ten"
    case daysFifty = "days-fifty"
    case daysHundred = "days-hundred"
    case firstCampaign = "first-campaign"
    case campaignThree = "campaign-three"
    case dailyFirst = "daily-first"
    case dailyTen = "daily-ten"
    case versusFirst = "versus-first"
    case versusTen = "versus-ten"
    case survivor = "survivor"

    public var displayName: String {
        switch self {
        case .firstRoost: return "First Roost"
        case .roostTen: return "Settler"
        case .roostFifty: return "Landlord"
        case .roostHundred: return "Roost Baron"
        case .flockThousand: return "A Thousand Wings"
        case .flockTwoThousand: return "River of Birds"
        case .flockThreeThousand: return "The Whole Sky"
        case .unbrokenThree: return "Three Days Aloft"
        case .unbrokenSeven: return "A Week Aloft"
        case .unbrokenThirty: return "The Long Migration"
        case .daysTen: return "Regular"
        case .daysFifty: return "Devoted"
        case .daysHundred: return "Lifer"
        case .firstCampaign: return "The Migration"
        case .campaignThree: return "Seasoned Traveler"
        case .dailyFirst: return "Daily Winds"
        case .dailyTen: return "Wind Reader"
        case .versusFirst: return "First Duel"
        case .versusTen: return "Rival Wings"
        case .survivor: return "Survivor"
        }
    }

    /// Whether the achievement is earned at a stats snapshot.
    public func isEarned(_ stats: LifetimeStats) -> Bool {
        switch self {
        case .firstRoost: return stats.totalRoostsClaimed >= 1
        case .roostTen: return stats.totalRoostsClaimed >= 10
        case .roostFifty: return stats.totalRoostsClaimed >= 50
        case .roostHundred: return stats.totalRoostsClaimed >= 100
        case .flockThousand: return stats.largestFlock >= 1_000
        case .flockTwoThousand: return stats.largestFlock >= 2_000
        case .flockThreeThousand: return stats.largestFlock >= 3_000
        case .unbrokenThree: return stats.longestUnbrokenFlight >= 3
        case .unbrokenSeven: return stats.longestUnbrokenFlight >= 7
        case .unbrokenThirty: return stats.longestUnbrokenFlight >= 30
        case .daysTen: return stats.daysCompleted >= 10
        case .daysFifty: return stats.daysCompleted >= 50
        case .daysHundred: return stats.daysCompleted >= 100
        case .firstCampaign: return stats.campaignsCompleted >= 1
        case .campaignThree: return stats.campaignsCompleted >= 3
        case .dailyFirst: return stats.dailiesPlayed >= 1
        case .dailyTen: return stats.dailiesPlayed >= 10
        case .versusFirst: return stats.versusPlayed >= 1
        case .versusTen: return stats.versusPlayed >= 10
        case .survivor: return stats.totalBirdsStarved == 0 && stats.daysCompleted >= 5
        }
    }
}

/// Which achievements flip on at a stats snapshot (pure; the app diffs
/// its earned set to award new ones).
public enum Achievements {
    public static func earned(at stats: LifetimeStats) -> Set<Achievement> {
        Set(Achievement.allCases.filter { $0.isEarned(stats) })
    }
}
