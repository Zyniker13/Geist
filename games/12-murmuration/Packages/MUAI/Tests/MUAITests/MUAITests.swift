import XCTest
import MUCore
import MUContent
@testable import MUAI

/// Autoplayer and GentleRival tests (P2.3). Decision tests use an
/// asymmetric test region so every choice is unambiguous; integration tests
/// verify the day-start split does not trip the R-5 merge and that a full
/// AI-driven day is deterministic.
final class MUAITests: XCTestCase {
    // MARK: - Fixtures

    /// Asymmetric two-field, two-roost region. Field A (500, 480) is nearer
    /// the world center than field B (1560, 1060); roost A (400, 400) is
    /// nearer than roost B (1648, 1200).
    private func makeTestRegion(birdCount: Int = 1400) -> Region {
        Region(
            id: "test", name: "Test",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: birdCount, falconCount: 1, hasRival: true,
            rivalStartBirds: birdCount * 3 / 7,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
    }

    private func apply(_ actions: [GameAction], to state: GameState) -> GameState {
        var state = state
        for action in actions {
            let (next, _) = applyAction(action, to: state)
            state = next
        }
        return state
    }

    private func count(_ state: GameState, subFlock: UInt8) -> Int {
        state.subFlockAssignments.filter { $0 == subFlock }.count
    }

    /// One model-loop step: AI actions first, then the tick (matches the app
    /// and `runReplay` ordering).
    private func step(
        _ state: GameState,
        rng: inout SeededRNG,
        autoplayer: inout Autoplayer,
        rival: inout GentleRival
    ) -> (GameState, [GameEvent]) {
        var state = state
        var events: [GameEvent] = []
        if let action = autoplayer.action(for: state) {
            let (next, evts) = applyAction(action, to: state)
            state = next
            events.append(contentsOf: evts)
        }
        if let action = rival.action(for: state) {
            let (next, evts) = applyAction(action, to: state)
            state = next
            events.append(contentsOf: evts)
        }
        let (next, evts) = applyTick(to: state, rng: &rng)
        return (next, events + evts)
    }

    // MARK: - RegionStarter

    func testStartingActionsSplitRival() throws {
        let region = makeTestRegion()
        let actions = RegionStarter.startingActions(for: region)
        XCTAssertEqual(actions.count, 1)

        var state = region.makeGameState()
        XCTAssertEqual(state.subFlockCount, 1)
        for action in actions {
            let (next, _) = applyAction(action, to: state)
            state = next
        }
        XCTAssertEqual(state.subFlockCount, 2)
        let rivalCount = count(state, subFlock: 1)
        XCTAssertEqual(
            rivalCount, region.rivalStartBirds,
            accuracy: 2,
            "rival should start with ~\(region.rivalStartBirds) birds, got \(rivalCount)"
        )
        XCTAssertEqual(
            count(state, subFlock: 0), region.birdCount - rivalCount,
            "the player keeps the remainder"
        )
    }

    func testStartingActionsEmptyWithoutRival() {
        var region = makeTestRegion()
        region = Region(
            id: "solo", name: "Solo",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 800, falconCount: 1, hasRival: false, rivalStartBirds: 0,
            windSeedOffset: 0, seed: 7,
            roosts: [.init(x: 1024, y: 768, radius: 120)],
            fields: [.init(x: 700, y: 600, radius: 128, richness: 60)],
            palette: .standard
        )
        XCTAssertEqual(RegionStarter.startingActions(for: region), [])
    }

    // MARK: - Autoplayer

    func testAutoplayerForagesAtTickZero() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        guard case .setLeaderPath(let sf, let waypoints)? = ai.action(for: state) else {
            return XCTFail("expected a forage path at tick 0")
        }
        XCTAssertEqual(sf, 0)
        XCTAssertEqual(waypoints, [Waypoint(x: 500, y: 480)], "nearest best field")
    }

    func testAutoplayerSkipsRepathToSameTarget() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        _ = ai.action(for: state)  // tick 0: path to field A
        state.tick = 1
        if case .setLeaderPath? = ai.action(for: state) {
            return XCTFail("interval not due: no re-path")
        }
        state.tick = 480
        if case .setLeaderPath? = ai.action(for: state) {
            return XCTFail("same best field: do not teleport the leader")
        }
    }

    func testAutoplayerRepathsWhenBestFieldChanges() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        _ = ai.action(for: state)  // tick 0: path to field A
        state.tick = 480
        state.fields[0].currentDepletion = state.fields[0].maxDepletion
        guard case .setLeaderPath(_, let waypoints)? = ai.action(for: state) else {
            return XCTFail("expected a re-path once field A is spent")
        }
        XCTAssertEqual(waypoints, [Waypoint(x: 1560, y: 1060)], "moves to field B")
    }

    func testAutoplayerDuskPathsToNearestRoostOnce() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        state.tick = GameState.duskStart
        guard case .setLeaderPath(let sf, let waypoints)? = ai.action(for: state) else {
            return XCTFail("expected a dusk roost path")
        }
        XCTAssertEqual(sf, 0)
        XCTAssertEqual(waypoints, [Waypoint(x: 400, y: 400)], "nearest roost")
        XCTAssertNil(ai.action(for: state), "the dusk path is issued once")
    }

    // MARK: - GentleRival

    func testGentleRivalIdleWithoutRival() {
        let state = makeTestRegion().makeGameState()
        var rival = GentleRival()
        XCTAssertNil(rival.action(for: state), "no rival flock yet")
    }

    func testGentleRivalFleesWhenCloudsCoincide() {
        var state = makeTestRegion().makeGameState()
        state = apply(RegionStarter.startingActions(for: makeTestRegion()), to: state)
        var rival = GentleRival()
        // Coincident centroids right after the split: flee to the standoff.
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected a flee path")
        }
        XCTAssertEqual(sf, 1)
        XCTAssertEqual(waypoints, [Waypoint(x: 1664, y: 768)], "standoff, +x from the player")
    }

    func testGentleRivalForagesAwayFromPlayerLeader() {
        var state = makeTestRegion().makeGameState()
        state = apply(RegionStarter.startingActions(for: makeTestRegion()), to: state)
        // Park the rival flock near field B so the flee check stays quiet and
        // the forage decision is exercised on its own.
        for i in 0..<state.birds.count where state.subFlockAssignments[i] == 1 {
            state.birds.posX[i] = 1800
            state.birds.posY[i] = 1200
        }
        var ai = Autoplayer()
        var rival = GentleRival()
        // The player decides first; the rival responds.
        if let action = ai.action(for: state) {
            let (next, _) = applyAction(action, to: state)
            state = next
        }
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected a rival forage path")
        }
        XCTAssertEqual(sf, 1)
        XCTAssertEqual(waypoints, [Waypoint(x: 1560, y: 1060)], "the far field, not the player's")
    }

    func testGentleRivalDuskClaimsUncontestedRoost() {
        var state = makeTestRegion().makeGameState()
        state = apply(RegionStarter.startingActions(for: makeTestRegion()), to: state)
        var ai = Autoplayer()
        var rival = GentleRival()
        state.tick = GameState.duskStart
        if let action = ai.action(for: state) {
            let (next, _) = applyAction(action, to: state)
            state = next
        }
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected a rival roost path")
        }
        XCTAssertEqual(sf, 1)
        XCTAssertEqual(waypoints, [Waypoint(x: 1648, y: 1200)], "the far roost")
    }

    func testGentleRivalHoldsWithSingleRoost() {
        let region = Region(
            id: "solo-roost", name: "Solo Roost",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 600, falconCount: 1, hasRival: true, rivalStartBirds: 200,
            windSeedOffset: 0, seed: 7,
            roosts: [.init(x: 1024, y: 768, radius: 120)],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        var rival = GentleRival()
        state.tick = GameState.duskStart
        // Coincident centroids: the pilot holds a standoff, fleeing +x.
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected a standoff path")
        }
        XCTAssertEqual(sf, 1)
        XCTAssertEqual(waypoints, [Waypoint(x: 1664, y: 768)])
    }

    // MARK: - Integration

    /// The day-start split starts the two clouds coincident; the pilots must
    /// open more than the R-5 merge distance (200) within the 30-tick streak
    /// window. 60 ticks with both pilots active must not merge the rival.
    func testSixtyTicksWithPilotsDoesNotMerge() {
        let region = makeTestRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        var rng = SeededRNG(seed: region.seed)
        var ai = Autoplayer()
        var rival = GentleRival()

        for _ in 0..<60 {
            let (next, events) = step(state, rng: &rng, autoplayer: &ai, rival: &rival)
            state = next
            for event in events {
                guard case .merge = event else { continue }
                return XCTFail("the rival merged within 60 ticks")
            }
        }
        // ADR-0033: a qualifying falcon dive mints a second flock on the
        // struck flock's own side, so the count may exceed 2. The invariant
        // under test is: no merge, and the rival's flock still has birds.
        XCTAssertGreaterThanOrEqual(state.subFlockCount, 2)
        XCTAssertLessThanOrEqual(state.subFlockCount, 4)
        XCTAssertGreaterThan(count(state, subFlock: 1), 0, "the rival is still alive")
    }

    /// A full AI-driven day must be deterministic: two identical runs end at
    /// the same state hash.
    func testAutoplayDayIsDeterministic() {
        let region = makeTestRegion(birdCount: 200)
        var hashes: [UInt64] = []
        for _ in 0..<2 {
            var state = region.makeGameState()
            state = apply(RegionStarter.startingActions(for: region), to: state)
            var rng = SeededRNG(seed: region.seed)
            var ai = Autoplayer()
            var rival = GentleRival()
            var dayEnded = false
            while !dayEnded {
                let (next, events) = step(state, rng: &rng, autoplayer: &ai, rival: &rival)
                state = next
                for event in events {
                    if case .dayEnd = event { dayEnded = true }
                    if case .roost(let roostEvent) = event, case .dayEnd = roostEvent {
                        dayEnded = true
                    }
                }
            }
            hashes.append(stateHash(state))
        }
        XCTAssertEqual(hashes[0], hashes[1], "two AI days must hash identically")
    }

    // MARK: - P4.1 difficulty tiers

    /// Teleport every bird of one subflock, so centroid-dependent decisions
    /// (standoff, flee radius) are exact regardless of simulation drift.
    private func teleportFlock(
        _ state: inout GameState, subFlock: UInt8, x: Int32, y: Int32
    ) {
        for i in 0..<state.birds.count where state.birds.subFlock[i] == subFlock {
            state.birds.posX[i] = x
            state.birds.posY[i] = y
        }
    }

    /// Three roosts designed so gentle and normal disagree at dusk with the
    /// player leader at the center and the rival parked at the top-right:
    /// gentle takes the Euclidean-farthest roost (C, bottom-right) while
    /// normal scores |roost−player|² − |roost−rival|² and takes A (top-right,
    /// far from the player, next to the rival). Standoff is 640² for gentle
    /// and 520² for normal; A's player distance (0.87M) clears both.
    private func makeThreeRoostRegion() -> Region {
        Region(
            id: "tier", name: "Tier",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1400, falconCount: 1, hasRival: true,
            rivalStartBirds: 600, windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 1800, y: 250, radius: 120),
                .init(x: 200, y: 1300, radius: 120),
                .init(x: 1848, y: 1400, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
    }

    func testGentleRivalDefaultsToGentleTier() throws {
        XCTAssertEqual(GentleRival().difficulty, .gentle)
        let hard = GentleRival(difficulty: .hard)
        XCTAssertEqual(hard.difficulty, .hard)
        // Cadences per tier: hard checks flee more often and forages in
        // shorter hops than gentle, and keeps a tighter standoff. The
        // flee radius is stored as a plain distance and squared at the
        // comparison site.
        XCTAssertEqual(hard.fleeInterval, 30)
        XCTAssertEqual(hard.forageInterval, 240)
        XCTAssertEqual(hard.fleeRadius, 400)
        XCTAssertEqual(hard.standoffDistance, 380)
    }

    func testGentleAndNormalDisagreeAtDusk() throws {
        let region = makeThreeRoostRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart
        teleportFlock(&state, subFlock: 1, x: 1900, y: 200)
        state.leaderPaths[0].currentX = 1024
        state.leaderPaths[0].currentY = 768

        var gentle = GentleRival()
        guard case .setLeaderPath(_, let gentleWaypoints)? = gentle.action(for: state) else {
            return XCTFail("expected a gentle roost path")
        }
        XCTAssertEqual(gentleWaypoints, [Waypoint(x: 1848, y: 1400)], "gentle takes the farthest roost")

        var normal = GentleRival(difficulty: .normal)
        guard case .setLeaderPath(_, let normalWaypoints)? = normal.action(for: state) else {
            return XCTFail("expected a normal roost path")
        }
        XCTAssertEqual(normalWaypoints, [Waypoint(x: 1800, y: 250)], "normal takes the roost next to the rival")
    }

    func testNormalFleesInsideGentleRadius() throws {
        let region = makeThreeRoostRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = 100
        teleportFlock(&state, subFlock: 0, x: 1024, y: 768)
        teleportFlock(&state, subFlock: 1, x: 1364, y: 768)

        var gentle = GentleRival()
        // At centroid distance 340 gentle (flee radius 320) does not flee:
        // it takes its overdue forage hop to the field far from the player.
        guard case .setLeaderPath(_, let gentleWaypoints)? = gentle.action(for: state) else {
            return XCTFail("expected a gentle forage path")
        }
        XCTAssertEqual(gentleWaypoints, [Waypoint(x: 1560, y: 1060)], "forage, not flee")

        var normal = GentleRival(difficulty: .normal)
        guard case .setLeaderPath(_, let normalWaypoints)? = normal.action(for: state) else {
            return XCTFail("expected normal to flee at distance 340 (radius 360)")
        }
        XCTAssertEqual(normalWaypoints, [Waypoint(x: 1543, y: 768)], "flee to standoff distance from the player")
    }

    func testHardSplitsToContestTwoRoosts() throws {
        let region = makeTestRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart
        var hard = GentleRival(difficulty: .hard)

        guard case .splitFlock(let from, let ratio)? = hard.action(for: state) else {
            return XCTFail("expected a hard split at dusk")
        }
        XCTAssertEqual(from, 1)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.001)
        let (afterSplit, _) = applyAction(.splitFlock(from: from, ratio: ratio), to: state)
        state = afterSplit
        XCTAssertEqual(state.subFlockCount, 3, "the split creates a second rival flock")

        let firstAction = hard.action(for: state)
        guard case .setLeaderPath(let firstSF, let firstWaypoints)? = firstAction else {
            return XCTFail("expected a roost path for the first half, got \(String(describing: firstAction))")
        }
        XCTAssertEqual(firstSF, 1)
        XCTAssertEqual(firstWaypoints, [Waypoint(x: 1648, y: 1200)], "the far roost")

        let (afterFirst, _) = applyAction(.setLeaderPath(subFlock: firstSF, waypoints: firstWaypoints), to: state)
        state = afterFirst
        guard case .setLeaderPath(let secondSF, let secondWaypoints)? = hard.action(for: state) else {
            return XCTFail("expected a roost path for the second half")
        }
        XCTAssertEqual(secondSF, 2)
        XCTAssertEqual(secondWaypoints, [Waypoint(x: 400, y: 400)], "the near roost")
    }

    func testHardHoldsStandoffWhenOutnumbered() throws {
        let region = Region(
            id: "hopeless", name: "Hopeless",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1000, falconCount: 1, hasRival: true, rivalStartBirds: 100,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)
        var hard = GentleRival(difficulty: .hard)

        guard case .setLeaderPath(_, let waypoints)? = hard.action(for: state) else {
            return XCTFail("expected a standoff path, not a split (900 > 2 × 100)")
        }
        XCTAssertEqual(waypoints, [Waypoint(x: 1404, y: 768)], "holds a standoff away from the player cloud")
    }

    func testClaimGateIsSeparateFromFieldStandoff() throws {
        // ADR-0035: the dusk claim gate is its own dial. A roost 500 from the
        // player's leader point fails normal's 520 gate (standoff held) but
        // passes once the gate is lowered to 400, with the field standoff
        // unchanged.
        let region = Region(
            id: "gate", name: "Gate",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 600, falconCount: 1, hasRival: true, rivalStartBirds: 300,
            windSeedOffset: 0, seed: 7,
            roosts: [.init(x: 1524, y: 768, radius: 120)],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart
        state.leaderPaths[0].currentX = 1024
        state.leaderPaths[0].currentY = 768

        var normal = GentleRival(difficulty: .normal)
        XCTAssertEqual(normal.claimGate, 520)
        guard case .setLeaderPath(_, let held)? = normal.action(for: state) else {
            return XCTFail("expected a standoff path below the claim gate")
        }
        XCTAssertNotEqual(held, [Waypoint(x: 1524, y: 768)], "the gated roost is not claimed")

        var bold = GentleRival(
            forageInterval: 300, fleeInterval: 45, fleeRadius: 360,
            standoffDistance: 520, difficulty: .normal
        )
        bold.claimGate = 400
        guard case .setLeaderPath(_, let claimed)? = bold.action(for: state) else {
            return XCTFail("expected the gated-in roost to be claimed")
        }
        XCTAssertEqual(claimed, [Waypoint(x: 1524, y: 768)], "claim gate 400 admits the 500-away roost")
    }

    func testContestRatioGatesHardDuskContests() throws {
        // ADR-0035: the hard tier's hopeless guard is a tunable ratio. At
        // 700 vs 300 the 2:1 default holds a standoff (700 > 600); ratio 3
        // contests (700 ≤ 900).
        let region = Region(
            id: "ratio", name: "Ratio",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1000, falconCount: 1, hasRival: true, rivalStartBirds: 300,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)

        var hard2 = GentleRival(difficulty: .hard)
        XCTAssertEqual(hard2.contestRatio, 2)
        guard case .setLeaderPath(_, _)? = hard2.action(for: state) else {
            return XCTFail("expected a standoff path at ratio 2 (700 > 2 × 300)")
        }

        var hard3 = GentleRival(difficulty: .hard)
        hard3.contestRatio = 3
        let bolded = hard3.action(for: state)
        let contests = { () -> Bool in
            switch bolded {
            case .splitFlock, .setLeaderPath: return true
            default: return false
            }
        }()
        XCTAssertTrue(contests, "ratio 3 admits the 700-vs-300 contest, got \(String(describing: bolded))")
    }

    func testSplitMinBirdsGatesTheHardSplit() throws {
        // ADR-0035: the two-roost split threshold is a tunable. A 600-bird
        // rival splits at the 500 default but routes a single flock when the
        // threshold is raised to 700.
        let region = makeTestRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        state.tick = GameState.duskStart

        var highMin = GentleRival(difficulty: .hard)
        highMin.splitMinBirds = 700
        guard case .setLeaderPath(_, _)? = highMin.action(for: state) else {
            return XCTFail("expected a routed flock, not a split, at splitMinBirds 700")
        }
    }

    func testLegacyDecodeDefaultsADR0035TunablesToTierTable() throws {
        // A pre-ADR-0035 save (no claimGate/contestRatio/splitMinBirds keys)
        // decodes each tunable to its tier's table value.
        let legacy = """
        {"forageInterval":480,"fleeInterval":60,"fleeRadius":320,
         "standoffDistance":640,"difficulty":"hard",
         "lastForageTick":-1,"lastFleeCheckTick":-1,"issuedDuskPlan":false,
         "splitStage":0}
        """.data(using: .utf8)!
        let rival = try JSONDecoder().decode(GentleRival.self, from: legacy)
        XCTAssertEqual(rival.difficulty, .hard)
        XCTAssertEqual(rival.claimGate, 0)
        XCTAssertEqual(rival.contestRatio, 2)
        XCTAssertEqual(rival.splitMinBirds, 500)
    }

    func testHardTierCodableRoundTrip() throws {
        var rival = GentleRival(difficulty: .hard)
        _ = rival.action(for: makeTestRegion().makeGameState())
        let data = try JSONEncoder().encode(rival)
        let copy = try JSONDecoder().decode(GentleRival.self, from: data)
        XCTAssertEqual(copy, rival)
        XCTAssertEqual(copy.difficulty, .hard)
    }

    // MARK: - Save/resume support

    func testPilotStateCodableRoundTrip() throws {
        var ai = Autoplayer()
        var rival = GentleRival()
        let state = makeTestRegion(birdCount: 100).makeGameState()
        _ = ai.action(for: state)
        _ = rival.action(for: state)

        let aiData = try JSONEncoder().encode(ai)
        let rivalData = try JSONEncoder().encode(rival)
        let aiCopy = try JSONDecoder().decode(Autoplayer.self, from: aiData)
        let rivalCopy = try JSONDecoder().decode(GentleRival.self, from: rivalData)
        XCTAssertEqual(aiCopy, ai)
        XCTAssertEqual(rivalCopy, rival)
    }
}
