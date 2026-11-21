import XCTest
import MUCore
import MUContent
@testable import MUAI

/// The ADR-0035 rival dusk tunables: `claimGate` (separate from the field
/// standoff), `contestRatio`, and `splitMinBirds`, plus their legacy-save
/// decode defaults. Moved out of `MUAITests` to keep class bodies under the
/// 400-line lint limit.
final class RivalTierTunablesTests: XCTestCase {
    // MARK: - Fixtures

    /// Asymmetric two-field, two-roost region (same shape as MUAITests').
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

    // MARK: - ADR-0035 tunables

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

    func testHardRoutesTwoExistingFlocksToTwoRoosts() throws {
        // ADR-0035: a falcon forcedSplit during the day leaves the rival side
        // with two flocks at dusk; the per-side cap rejects a further split,
        // so the plan routes the existing flocks to the two roosts the
        // player is least likely to reach instead.
        let region = makeTestRegion()
        var state = region.makeGameState()
        state = apply(RegionStarter.startingActions(for: region), to: state)
        let (splitState, _) = applyAction(.splitFlock(from: 1, ratio: 0.5), to: state)
        state = splitState
        XCTAssertEqual(state.subFlockCount, 3, "the rival side now fields two flocks")
        state.tick = GameState.duskStart

        var hard = GentleRival(difficulty: .hard)
        // The halved flock (300 birds) must still clear the contest guard
        // and the split threshold for the two-flock routing to arm.
        hard.contestRatio = 3
        hard.splitMinBirds = 200
        // Tick 1: the plan arms the routing (no split action — it would be
        // rejected by the per-side cap).
        XCTAssertNil(hard.action(for: state), "no split: the side already has two flocks")
        // Tick 2: flock 1 to the far roost.
        guard case .setLeaderPath(let firstSF, let firstWaypoints)? = hard.action(for: state) else {
            return XCTFail("expected flock 1's roost path")
        }
        XCTAssertEqual(firstSF, 1)
        XCTAssertEqual(firstWaypoints, [Waypoint(x: 1648, y: 1200)], "the far roost")
        // Tick 3: flock 2 to the near roost.
        guard case .setLeaderPath(let secondSF, let secondWaypoints)? = hard.action(for: state) else {
            return XCTFail("expected flock 2's roost path")
        }
        XCTAssertEqual(secondSF, 2)
        XCTAssertEqual(secondWaypoints, [Waypoint(x: 400, y: 400)], "the near roost")
    }

    func testLegacyDecodeDefaultsADR0035TunablesToTierTable() throws {
        // A pre-ADR-0035 save (no claimGate/contestRatio/splitMinBirds keys)
        // decodes each tunable to its tier's table value.
        let legacy = Data("""
        {"forageInterval":480,"fleeInterval":60,"fleeRadius":320,
         "standoffDistance":640,"difficulty":"hard",
         "lastForageTick":-1,"lastFleeCheckTick":-1,"issuedDuskPlan":false,
         "splitStage":0}
        """.utf8)
        let rival = try JSONDecoder().decode(GentleRival.self, from: legacy)
        XCTAssertEqual(rival.difficulty, .hard)
        XCTAssertEqual(rival.claimGate, 0)
        XCTAssertEqual(rival.contestRatio, 2)
        XCTAssertEqual(rival.splitMinBirds, 500)
    }
}
