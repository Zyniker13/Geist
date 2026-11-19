import XCTest
@testable import MUCore

/// P3.2 / R-13: solo-objective regions (no rival). The goal is to roost a
/// target number of birds; the day is won when the settled count meets the
/// target at day end. Versus regions (soloTargetBirds == 0) keep the roost
/// tally rules unchanged.
final class SoloObjectiveTests: XCTestCase {
    // MARK: - Configuration

    func testSoloTargetDefaultsToZero() {
        let state = makeState(birdCount: 50)
        XCTAssertEqual(state.soloTargetBirds, 0, "versus regions default to no solo target")
    }

    func testSoloTargetSurvivesRoundTrip() throws {
        var state = makeState(birdCount: 50, soloTargetBirds: 12)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded.soloTargetBirds, 12)
    }

    // MARK: - Solo victory (R-13)

    /// Three birds inside the roost radius, target three: the day is won.
    func testSoloVictoryWhenSettledMeetsTarget() {
        var state = makeState(birdCount: 3, roostCount: 1, soloTargetBirds: 3)
        // The single roost is centered at (512, 768) with radius 128.
        state.birds.posX = [512, 512, 512]
        state.birds.posY = [768, 768, 768]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertEqual(victory, .victory(winner: 0), "meeting the target wins the day")
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 3, target: 3)))
        XCTAssertFalse(events.contains(.dayEnd(playerFlocksWon: 0, rivalFlocksWon: 0)),
                       "solo days report the settled count, not a roost tally")
    }

    /// Two birds settled, target three: no winner, the day is simply over.
    func testSoloNoVictoryWhenBelowTarget() {
        var state = makeState(birdCount: 2, roostCount: 1, soloTargetBirds: 3)
        state.birds.posX = [512, 512]
        state.birds.posY = [768, 768]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertNil(victory, "below target there is no winner")
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 2, target: 3)))
    }

    /// Birds outside every roost radius do not count as settled.
    func testSoloOnlyCountsBirdsInsideRoostRadius() {
        var state = makeState(birdCount: 4, roostCount: 1, soloTargetBirds: 3)
        // Two inside (512, 768), two far away (1800, 200).
        state.birds.posX = [512, 512, 1800, 1800]
        state.birds.posY = [768, 768, 200, 200]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertNil(victory, "only the two birds inside the radius count")
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 2, target: 3)))
    }

    /// Roost claims are irrelevant in solo mode: the settled count decides.
    func testSoloIgnoresRoostClaims() {
        var state = makeState(birdCount: 3, roostCount: 1, soloTargetBirds: 3)
        state.birds.posX = [512, 512, 512]
        state.birds.posY = [768, 768, 768]
        // Stale claims must not change the outcome.
        state.roostClaims = [[1]]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertEqual(victory, .victory(winner: 0))
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 3, target: 3)))
        XCTAssertFalse(events.contains(.won(roostIndex: 0, flock: 1)))
    }

    /// Multiple roosts: birds settled in different roosts all count.
    func testSoloCountsBirdsAcrossMultipleRoosts() {
        // makeState spreads two roosts at x = 256 and x = 1792 (y = 768).
        var state = makeState(birdCount: 3, roostCount: 2, soloTargetBirds: 3)
        state.birds.posX = [256, 256, 1792]
        state.birds.posY = [768, 768, 768]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertEqual(victory, .victory(winner: 0))
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 3, target: 3)))
    }

    /// A bird inside two overlapping roost radii counts once, not twice.
    func testSoloBirdInOverlappingRoostsCountsOnce() {
        var state = GameState(
            birdCount: 1,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 2,
            roostCenterX: [512, 640],
            roostCenterY: [768, 768],
            roostRadius: [128, 128],
            falconCount: 1,
            hasRival: false,
            soloTargetBirds: 1,
            windSeedOffset: 0,
            seed: 42
        )
        // (576, 768) is 64 units from both centers: inside both radii.
        state.birds.posX = [576]
        state.birds.posY = [768]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertEqual(victory, .victory(winner: 0))
        XCTAssertTrue(events.contains(.soloDayEnd(settled: 1, target: 1)))
    }

    // MARK: - Versus regression guard

    /// soloTargetBirds == 0 keeps the roost-tally victory rules exactly as
    /// before P3.2.
    func testVersusUnaffectedWhenSoloTargetZero() {
        var state = makeState(birdCount: 50, hasRival: true, roostCount: 2)
        // Rival leads both roosts: flock 0 (player) has no points anywhere.
        state.roostClaims = [[0, 3], [0, 4]]

        let (events, victory) = checkVictory(state: &state)

        XCTAssertEqual(victory, .victory(winner: 1), "rival holds both roosts")
        XCTAssertTrue(events.contains(.dayEnd(playerFlocksWon: 0, rivalFlocksWon: 2)))
        XCTAssertTrue(events.contains(.won(roostIndex: 0, flock: 1)))
        XCTAssertTrue(events.contains(.won(roostIndex: 1, flock: 1)))
        XCTAssertFalse(events.contains {
            if case .soloDayEnd = $0 { return true }; return false
        })
    }

    // MARK: - Reducer integration

    /// A full day in a solo region ends with the solo event and a victory
    /// when the flock roosts enough birds.
    func testSoloDayEndThroughReducer() {
        var state = makeState(birdCount: 4, roostCount: 1, soloTargetBirds: 2)
        var rng = SeededRNG(seed: 42)
        var events: [GameEvent] = []
        for _ in 0..<GameState.dayTicks {
            let (next, tickEvents) = applyTick(to: state, rng: &rng)
            state = next
            events.append(contentsOf: tickEvents)
        }
        let soloEvents = events.compactMap { event -> (settled: Int, target: Int)? in
            if case .roost(.soloDayEnd(let settled, let target)) = event {
                return (settled, target)
            }
            return nil
        }
        XCTAssertEqual(soloEvents.count, 1, "exactly one solo day-end event per day")
        if let (settled, target) = soloEvents.first {
            XCTAssertEqual(target, 2)
            let won = events.contains {
                if case .victory(let winner) = $0 { return winner == 0 }; return false
            }
            XCTAssertEqual(won, settled >= target,
                           "victory iff the settled count met the target")
        }
    }

    // MARK: - Shared settled-count helper (P3.2 tutorial)

    /// The tutorial's roost step and the day-end solo victory must count the
    /// same way: each bird once, the first roost radius containing it.
    func testCountSettledInRoostsCountsEachBirdOnceAcrossOverlappingRoosts() {
        var state = makeState(birdCount: 3, roostCount: 2, soloTargetBirds: 3)
        // Collapse both roosts onto the same center so their radii fully
        // overlap; a bird inside must count once, not twice.
        state.roosts[0].centerX = 512
        state.roosts[0].centerY = 768
        state.roosts[1].centerX = 512
        state.roosts[1].centerY = 768
        state.birds.posX = [512, 100, 1900]
        state.birds.posY = [768, 768, 768]

        XCTAssertEqual(countSettledInRoosts(state: state), 1,
                       "a bird inside two overlapping roost radii counts once; the other two are outside")
    }

    func testCountSettledInRoostsMatchesCheckVictorySettledCount() {
        var state = makeState(birdCount: 4, roostCount: 1, soloTargetBirds: 2)
        state.birds.posX = [512, 512, 1800, 1800]
        state.birds.posY = [768, 768, 768, 768]

        let expected = countSettledInRoosts(state: state)
        let (events, _) = checkVictory(state: &state)
        let solo = events.first { event in
            if case .soloDayEnd = event { return true }; return false
        }
        XCTAssertEqual(expected, 2)
        if case .soloDayEnd(let settled, _)? = solo {
            XCTAssertEqual(settled, expected, "checkVictory and the helper agree")
        } else {
            XCTFail("expected a soloDayEnd event")
        }
    }
}
