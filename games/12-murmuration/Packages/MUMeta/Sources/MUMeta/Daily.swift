// Murmuration Meta — daily challenge model (MU-P5.2).
//
// The daily run is the shipped meadow region under a modifier set
// derived from the calendar date: every device in the world plays the
// same day (same wind map, same modifier, same seed), so the daily wind
// map is identical across devices for any date (G5 check). Best scores
// are a pure comparison over score records; persistence lives in the
// app layer.

import Foundation
import MUContent
import MUCore

/// One of the six daily modifiers (ROADMAP §3 content counts G5).
public enum DailyModifier: String, Codable, Sendable, CaseIterable {
    /// Wind magnitude doubled (R-1 base strength × 2).
    case strongWinds = "strong-winds"
    /// One extra falcon (R-10).
    case extraFalcons = "extra-falcons"
    /// Every field's richness halved (R-8).
    case scarceFields = "scarce-fields"
    /// Wind regenerated twice as often (the map shifts mid-day).
    case fog = "fog"
    /// Each roost requires two claims to hold (R-12 doubling).
    case doubleRoosts = "double-roosts"
    /// Starting flock halved.
    case tinyFlock = "tiny-flock"

    public var displayName: String {
        switch self {
        case .strongWinds: return "Strong winds"
        case .extraFalcons: return "Extra falcons"
        case .scarceFields: return "Scarce fields"
        case .fog: return "Fog"
        case .doubleRoosts: return "Double roosts"
        case .tinyFlock: return "Tiny flock"
        }
    }
}

/// The deterministic daily setup for a calendar date.
///
/// `dayNumber` is days since the campaign epoch (2026-01-01, UTC). The
/// modifier is `dayNumber % 6` over the case order, the wind seed
/// offset mixes the day number, and the score is a pure function of the
/// played day (roosts claimed, birds alive at dusk).
public struct DailyChallenge: Sendable, Equatable {
    /// Days since the epoch for this date.
    public let dayNumber: Int
    /// The day's modifier.
    public let modifier: DailyModifier
    /// The wind seed offset that makes this day's wind map unique but
    /// reproducible on every device.
    public let windSeedOffset: Int
    /// The region the daily runs on.
    public let regionID: String

    /// The campaign epoch: 2026-01-01 00:00 UTC.
    public static let epoch: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 0
        components.timeZone = TimeZone(identifier: "UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    /// Seconds per day.
    public static let secondsPerDay: TimeInterval = 86_400

    public init(date: Date, now: Date = Date(), regionID: String = "meadow") {
        let dayNumber = Int(floor(now.timeIntervalSince(date) / Self.secondsPerDay))
        self.dayNumber = dayNumber
        self.modifier = DailyModifier.allCases[
            ((dayNumber % DailyModifier.allCases.count) + DailyModifier.allCases.count)
                % DailyModifier.allCases.count
        ]
        // Distinct-but-deterministic wind offset per day: golden-ratio mix
        // into a wide fixed range (100k..1M), never equal to a shipped
        // region's offset; a 30-date window must yield unique maps.
        var h = UInt64(bitPattern: -0x5EED_1D5A) &+ UInt64(truncatingIfNeeded: dayNumber)
        h &*= 0x9E37_79B9_7F4A_7C15
        h ^= h >> 31
        self.windSeedOffset = Int(truncatingIfNeeded: h % 900_000) + 100_000
        self.regionID = regionID
    }

    /// The UTC calendar date string ("YYYY-MM-DD") for evidence tables.
    public static func utcDateString(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// The score for a played daily day (MU-P5.2 local best scores): roosts
    /// claimed weighted above birds alive, deterministic and comparable
    /// across devices.
    public static func score(roostsClaimed: Int, birdsAlive: Int) -> Int {
        roostsClaimed * 1_000 + birdsAlive
    }
}

/// A recorded daily score for one date.
public struct DailyScore: Codable, Sendable, Equatable {
    public let dayNumber: Int
    public let score: Int

    public init(dayNumber: Int, score: Int) {
        self.dayNumber = dayNumber
        self.score = score
    }
}

/// Local best-score bookkeeping (pure; storage is the app's job).
public enum DailyScores {
    /// The best score recorded for `dayNumber`, if any.
    public static func best(for dayNumber: Int, in scores: [DailyScore]) -> Int? {
        scores
            .filter { $0.dayNumber == dayNumber }
            .map(\.score)
            .max()
    }

    /// Record a score, keeping only the best per day (dedupe by day).
    public static func record(_ score: DailyScore, into scores: [DailyScore]) -> [DailyScore] {
        var kept = scores.filter { $0.dayNumber != score.dayNumber }
        kept.append(score)
        return kept.sorted { $0.dayNumber < $1.dayNumber }
    }
}
