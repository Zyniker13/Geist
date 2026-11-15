/// ProfileStore — persists the player profile (NM-P5.3/P5.4): stats,
/// unlocks, and earned achievements. A thin JSON file next to the save;
/// all progression logic lives in NMCore (Profile, UnlockCatalog,
/// AchievementCatalog) and is tested there.
import Foundation
import NMCore
import NMPlatform

@MainActor
public final class ProfileStore: ObservableObject {
    public static let shared = ProfileStore()

    @Published public private(set) var profile: Profile

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NightMarket", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profile.json")
    }

    public init() {
        if let data = try? Data(contentsOf: Self.fileURL),
            let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = decoded
        } else {
            profile = Profile()
        }
        // Restore from iCloud when the local file is missing (NM-P7.2);
        // without the entitlement this is a no-op.
        if !hasLocalProfile, let cloudData = ICloudSync().load(),
            let decoded = try? JSONDecoder().decode(Profile.self, from: cloudData),
            decoded.nightsPlayed > profile.nightsPlayed {
            profile = decoded
        }
        cloudSync = ICloudSync()
    }

    private var hasLocalProfile: Bool {
        FileManager.default.fileExists(atPath: Self.fileURL.path)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: Self.fileURL, options: .atomic)
            // Write-through to iCloud when the app wired a backend (NM-P7.2);
            // the profile is tiny, well under the KVS limit.
            cloudSync?.save(data)
        }
    }

    /// The iCloud write-through backend, wired by the app entry points.
    public var cloudSync: ProfileSyncing?

    /// The outcome of one finished night, applied to the profile.
    public struct NightOutcome: Sendable {
        public var served: Int
        public var survived: Bool
        public var finalScore: Int
        public var overflowCount: Int
        public var mapId: String
        public var modifier: ChallengeModifier?
        public var challenge: Bool

        public init(
            served: Int, survived: Bool, finalScore: Int, overflowCount: Int,
            mapId: String, modifier: ChallengeModifier?, challenge: Bool
        ) {
            self.served = served
            self.survived = survived
            self.finalScore = finalScore
            self.overflowCount = overflowCount
            self.mapId = mapId
            self.modifier = modifier
            self.challenge = challenge
        }
    }

    /// Applies a night and returns what it newly earned.
    @discardableResult
    public func applyNight(_ outcome: NightOutcome) -> (achievements: [Achievement], unlockedMaps: [String]) {
        var next = profile
        next.nightsPlayed += 1
        next.customersServed += outcome.served
        next.bestNightScore = max(next.bestNightScore, outcome.finalScore)
        if outcome.survived {
            next.dawnsReached += 1
            next.mapsFinished.insert(outcome.mapId)
            next.sandboxUnlocked = true
            if let modifier = outcome.modifier {
                next.modifiersFinished.insert(modifier.rawValue)
            }
            if outcome.challenge {
                next.challengesCompleted += 1
            }
        }
        if outcome.overflowCount == 0 {
            next.calmNights += 1
        }
        let unlocked = UnlockCatalog.newlyUnlocked(currently: next.unlockedMaps, afterScore: outcome.finalScore)
        next.unlockedMaps.formUnion(unlocked)
        let earned = AchievementCatalog.newlyEarned(in: next)
        next.earnedAchievements.formUnion(earned.map(\.id))
        profile = next
        persist()
        return (earned, unlocked)
    }

    /// Resets the profile (debug/testing helper).
    public func reset() {
        profile = Profile()
        persist()
    }
}
