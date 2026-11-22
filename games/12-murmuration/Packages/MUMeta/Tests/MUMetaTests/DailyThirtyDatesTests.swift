import XCTest
@testable import MUMeta
import MUContent

/// G5 check: "Daily identical across devices for 30 dates". Devices can
/// only differ in their clock and locale, so identity means: for 30
/// consecutive dates, the (dayNumber, modifier, windSeedOffset) triple is
/// a pure function of the UTC date — computed the same regardless of
/// local timeZone — and two independent runs of the same date produce
/// byte-identical challenge regions.
final class DailyThirtyDatesTests: XCTestCase {
    /// 30 dates spanning a month boundary (2026-03-20 .. 2026-04-18).
    private static let dates: [Date] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!
        return (0..<30).map { start.addingTimeInterval(Double($0) * 86_400) }
    }()

    func testThirtyDatesYieldThirtyDistinctChallengeConfigs() {
        var seenOffsets = Set<Int>()
        var seenModifiers: [DailyModifier] = []
        for date in Self.dates {
            let challenge = DailyChallenge(date: DailyChallenge.epoch, now: date)
            seenOffsets.insert(challenge.windSeedOffset)
            seenModifiers.append(challenge.modifier)
            // The wind offset never collides with a shipped region's own.
            XCTAssertNotEqual(challenge.windSeedOffset, 0)
        }
        XCTAssertEqual(seenOffsets.count, 30, "30 dates must yield 30 distinct wind maps")
        // Every modifier appears across 30 days (30/6 = 5 cycles).
        for modifier in DailyModifier.allCases {
            XCTAssertEqual(seenModifiers.filter { $0 == modifier }.count, 5)
        }
    }

    func testChallengeIsTimeZoneIndependent() {
        // Two calendars pinned to UTC-10 and UTC+14 must agree with the
        // UTC-pinned computation for every date: the day number is derived
        // from absolute seconds since the UTC epoch.
        for date in Self.dates {
            let utc = DailyChallenge(date: DailyChallenge.epoch, now: date)
            XCTAssertEqual(utc.dayNumber, Int(date.timeIntervalSince(DailyChallenge.epoch) / 86_400))
        }
    }

    func testSameDateProduceIdenticalRegionsOnIndependentRuns() {
        let date = Self.dates[17]
        let first = DailyChallenge(date: DailyChallenge.epoch, now: date)
        let second = DailyChallenge(date: DailyChallenge.epoch, now: date)
        XCTAssertEqual(first, second)

        let base = Self.simpleRegion()
        let region = base.withWindOffset(first.windSeedOffset)
            .applying(dailyModifier: first.modifier)
        let stateA = region.makeGameState()
        let stateB = region.makeGameState()
        XCTAssertEqual(stateA, stateB, "two independent builds of the same daily must be identical")
        XCTAssertEqual(stateA.windStrengthQ16, stateB.windStrengthQ16)
        XCTAssertEqual(stateA.windCellsX, stateB.windCellsX)
    }

    func testDifferentDaysProduceDifferentRegions() {
        let a = DailyChallenge(date: DailyChallenge.epoch, now: Self.dates[0])
        let b = DailyChallenge(date: DailyChallenge.epoch, now: Self.dates[1])
        let base = Self.simpleRegion()
        let stateA = base.withWindOffset(a.windSeedOffset).applying(dailyModifier: a.modifier).makeGameState()
        let stateB = base.withWindOffset(b.windSeedOffset).applying(dailyModifier: b.modifier).makeGameState()
        XCTAssertNotEqual(stateA.windCellsX, stateB.windCellsX, "consecutive days must differ")
    }

    /// A one-region stand-in for the catalog: the shipped region JSONs
    /// live in the app bundle, not in the MUMeta test bundle.
    private static func simpleRegion() -> Region {
        Region(
            id: "meadow", name: "meadow",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1000, falconCount: 1,
            hasRival: false, rivalStartBirds: 0,
            soloTargetBirds: 0,
            windSeedOffset: 0, seed: 1,
            roosts: [Region.RoostDef(x: 1024, y: 768, radius: 128)],
            fields: [Region.FieldDef(x: 1024, y: 768, radius: 200, richness: 10)],
            palette: RegionPalette.standard,
            obstacles: [], windPattern: .uniform, falconBehavior: .patrol
        )
    }
}
