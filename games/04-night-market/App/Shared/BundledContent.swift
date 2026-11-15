/// BundledContent — loads the packaged map and schedule definitions
/// (NM-P5.1). Content JSONs are flattened at the bundle root by the
/// resources build phase, so lookups need no subdirectory.
import Foundation
import NMCore

public enum BundledContent {
    /// All packaged maps in ladder order.
    public static let mapIds = ["taipei", "seoul", "bangkok", "marrakesh", "istanbul", "oaxaca"]
    /// All packaged schedules.
    public static let scheduleIds = ["schedule_standard", "schedule_festival", "schedule_monsoon"]

    public static func map(_ id: String, bundle: Bundle = .main) throws -> MapDefinition {
        guard let url = bundle.url(forResource: id, withExtension: "json") else {
            throw NSError(domain: "BundledContent", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "map \(id) not found in bundle",
            ])
        }
        return try JSONDecoder().decode(MapDefinition.self, from: Data(contentsOf: url))
    }

    public static func schedule(_ id: String, bundle: Bundle = .main) throws -> ScheduleDefinition {
        guard let url = bundle.url(forResource: id, withExtension: "json") else {
            throw NSError(domain: "BundledContent", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "schedule \(id) not found in bundle",
            ])
        }
        return try JSONDecoder().decode(ScheduleDefinition.self, from: Data(contentsOf: url))
    }

    /// UTC calendar strings for the daily and weekly challenges.
    public enum ChallengeClock {
        public static func yyyymmddUTC(_ date: Date = Date()) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMdd"
            return formatter.string(from: date)
        }

        public static func isoWeekUTC(_ date: Date = Date()) -> String {
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
            let week = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return String(format: "%04d-W%02d", year, week)
        }
    }
}
