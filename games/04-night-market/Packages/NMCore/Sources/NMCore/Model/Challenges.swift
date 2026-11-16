/// Daily and weekly challenge setup (NM-P5.2). The challenge seed is a
/// deterministic string hash — identical across devices for the same UTC
/// date/week — and picks the map, schedule, and one modifier; stall jitter
/// and the rain plan follow from the same seed inside initialisation.
public enum Challenge {
    /// FNV-1a 64-bit over UTF-8 bytes (same convention as StateHash).
    public static func hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// Daily seed: `hash("NM-daily-" + yyyyMMdd)` in UTC.
    public static func dailySeed(yyyymmddUTC: String) -> UInt64 {
        hash("NM-daily-" + yyyymmddUTC)
    }

    /// Weekly seed: `hash("NM-weekly-" + isoWeek)` in UTC (e.g. 2026-W46).
    public static func weeklySeed(isoWeekUTC: String) -> UInt64 {
        hash("NM-weekly-" + isoWeekUTC)
    }

    /// The deterministic challenge draw for a seed: map id, schedule id, and
    /// exactly one modifier. Same seed → same challenge, on every device.
    public static func draw(seed: UInt64, mapIds: [String], scheduleIds: [String]) -> (
        mapId: String, scheduleId: String, modifier: ChallengeModifier
    ) {
        var rng = SeededRNG(seed: seed)
        let map = mapIds.isEmpty ? "taipei" : mapIds[Int(rng.next(upperBound: UInt64(mapIds.count)))]
        let schedule = scheduleIds.isEmpty
            ? "schedule_standard" : scheduleIds[Int(rng.next(upperBound: UInt64(scheduleIds.count)))]
        let all = ChallengeModifier.allCases
        let modifier = all[Int(rng.next(upperBound: UInt64(all.count)))]
        return (map, schedule, modifier)
    }
}

/// One player-chosen night configuration (NM-P5.2/P5.3): free play picks a
/// map and schedule; challenges fix the seed from the UTC date and draw
/// map, schedule, and one modifier deterministically.
public struct NightSetup: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case freePlay, daily, weekly
    }

    public var mode: Mode
    public var mapId: String
    public var scheduleId: String
    public var modifier: ChallengeModifier?
    public var seed: UInt64
    /// Accessibility assist (NM-P8.2): lengthen the overflow grace window 50%.
    public var assist: Bool

    public init(
        mode: Mode, mapId: String, scheduleId: String, modifier: ChallengeModifier?,
        seed: UInt64, assist: Bool = false
    ) {
        self.mode = mode
        self.mapId = mapId
        self.scheduleId = scheduleId
        self.modifier = modifier
        self.seed = seed
        self.assist = assist
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(Mode.self, forKey: .mode)
        mapId = try container.decode(String.self, forKey: .mapId)
        scheduleId = try container.decode(String.self, forKey: .scheduleId)
        modifier = try container.decodeIfPresent(ChallengeModifier.self, forKey: .modifier)
        seed = try container.decode(UInt64.self, forKey: .seed)
        assist = try container.decodeIfPresent(Bool.self, forKey: .assist) ?? false
    }

    /// Resolves a challenge night from the UTC date (daily) or ISO week
    /// (weekly). Same date string on any device → the same night.
    public static func challenge(
        _ mode: Mode, yyyymmddUTC: String, isoWeekUTC: String,
        mapIds: [String], scheduleIds: [String]
    ) -> NightSetup {
        let seed = mode == .daily
            ? Challenge.dailySeed(yyyymmddUTC: yyyymmddUTC)
            : Challenge.weeklySeed(isoWeekUTC: isoWeekUTC)
        let draw = Challenge.draw(seed: seed, mapIds: mapIds, scheduleIds: scheduleIds)
        return NightSetup(
            mode: mode, mapId: draw.mapId, scheduleId: draw.scheduleId,
            modifier: draw.modifier, seed: seed
        )
    }

    /// A free-play night on the chosen map and schedule, with no modifier.
    public static func freePlay(mapId: String, scheduleId: String, seed: UInt64) -> NightSetup {
        NightSetup(mode: .freePlay, mapId: mapId, scheduleId: scheduleId, modifier: nil, seed: seed)
    }
}

/// The twelve challenge modifiers (NM-P5.2). Each one is behavior-affecting
/// state: the active list is hashed with the rest of GameState, and every
/// case applies itself deterministically at initialisation.
public enum ChallengeModifier: String, Codable, CaseIterable, Sendable {
    case lanternsCostDouble
    case twoGatesOnly
    case everyoneWantsTea
    case tightBudget
    case rushHour
    case slowCookers
    case smallQueues
    case earlyClose
    case rainAllNight
    case generousBudget
    case lateGates
    case doubleServes

    public var title: String {
        switch self {
        case .lanternsCostDouble: return "Lanterns cost double"
        case .twoGatesOnly: return "Two gates only"
        case .everyoneWantsTea: return "Everyone wants tea"
        case .tightBudget: return "Tight budget"
        case .rushHour: return "Rush hour"
        case .slowCookers: return "Slow cookers"
        case .smallQueues: return "Small queues"
        case .earlyClose: return "Early close"
        case .rainAllNight: return "Rain all night"
        case .generousBudget: return "Generous budget"
        case .lateGates: return "Late gates"
        case .doubleServes: return "Double serves"
        }
    }

    /// Applies the modifier to a freshly initialised state (before the first
    /// tick). Deterministic; touches only state the rules already define.
    public func apply(to state: inout GameState) {
        switch self {
        case .lanternsCostDouble:
            break  // enforced by the reducer's lantern branch
        case .twoGatesOnly:
            for index in state.gates.indices where index >= 2 {
                state.gates[index].isOpen = false
                state.gates[index].opensAtTick = nil
            }
        case .everyoneWantsTea:
            state.zoneWeights = ["tea": 6]
        case .tightBudget:
            state.walkwayBudget = 20
        case .rushHour:
            state.spawnRates = state.spawnRates.map { max(1, $0 * 5 / 4) }
        case .slowCookers:
            for index in state.stalls.indices {
                state.stalls[index].serviceTicks += 30
            }
        case .smallQueues:
            state.queueCapacityMod = -2
        case .earlyClose:
            state.clock.nightHours = 9  // 18:00 + 9 h = 03:00
        case .rainAllNight:
            state.rainSchedule = [RainShower(startTick: 0, durationTicks: state.clock.ticksPerHour * 12)]
        case .generousBudget:
            state.walkwayBudget = 50
        case .lateGates:
            for index in state.gates.indices {
                if let open = state.gates[index].opensAtTick {
                    state.gates[index].opensAtTick = max(open, 7200)
                }
            }
        case .doubleServes:
            state.scorePerServe = 2
        }
    }
}
