import XCTest
import MUCore
import MUContent
@testable import MUAI

/// The rival sustainability mechanics (ADR-0035): a fat single flock splits
/// once per day onto two different forage destinations (`sustainSplit`), and
/// every rival flock plans its own forage with the other rival flocks'
/// centroids (and the player's leader point) in its avoid set, so split
/// halves strip different fields instead of re-correlating on one and
/// starving the side via R-8.
final class RivalSustainTests: XCTestCase {
    // MARK: - Fixtures

    /// Two-field, two-roost region with a fat rival start. Field B sits at
    /// the exact midpoint-shaped distance from the test positions so the
    /// avoid penalty (not travel cost) decides the flock-2 pick.
    private func makeTestRegion(rivalStartBirds: Int = 1000) -> Region {
        Region(
            id: "test", name: "Test",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1400, falconCount: 1, hasRival: true,
            rivalStartBirds: rivalStartBirds,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1100, y: 900, radius: 128, richness: 60),
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

    private func freshState(_ region: Region) -> GameState {
        apply(RegionStarter.startingActions(for: region), to: region.makeGameState())
    }

    private func teleportFlock(
        _ state: inout GameState, subFlock: UInt8, x: Int32, y: Int32
    ) {
        for i in 0..<state.birds.count where state.birds.subFlock[i] == subFlock {
            state.birds.posX[i] = x
            state.birds.posY[i] = y
        }
    }

    /// The full day-start sustain sequence for a fat flock: split, then the
    /// two routing ticks. Returns (state, targets A and B).
    private func runSustainSplit(
        _ state: GameState, sustain: Int
    ) -> (GameState, Waypoint, Waypoint) {
        var state = state
        var rival = GentleRival(difficulty: .hard)
        rival.sustainSplit = sustain
        guard case .splitFlock(let from, let ratio)? = rival.action(for: state) else {
            XCTFail("expected the fat flock to split for sustainability")
            return (state, .init(x: -1, y: -1), .init(x: -1, y: -1))
        }
        XCTAssertEqual(from, 1)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.0001)
        state = apply([.splitFlock(from: from, ratio: ratio)], to: state)
        guard case .setLeaderPath(1, let pathA)? = rival.action(for: state) else {
            XCTFail("expected flock 1's routing after the sustain split")
            return (state, .init(x: -1, y: -1), .init(x: -1, y: -1))
        }
        state = apply([.setLeaderPath(subFlock: 1, waypoints: pathA)], to: state)
        guard case .setLeaderPath(2, let pathB)? = rival.action(for: state) else {
            XCTFail("expected flock 2's routing after the sustain split")
            return (state, .init(x: -1, y: -1), .init(x: -1, y: -1))
        }
        state = apply([.setLeaderPath(subFlock: 2, waypoints: pathB)], to: state)
        return (state, pathA.first ?? .init(x: -1, y: -1), pathB.first ?? .init(x: -1, y: -1))
    }

    // MARK: - Sustain split

    /// A fat single rival flock splits once per day onto two DIFFERENT
    /// fields, and the staged routing survives repeated same-tick calls
    /// (the day reset must not wipe mid-routing state).
    func testSustainSplitFiresAtThresholdAndRoutesDivergent() {
        let region = makeTestRegion()
        var state = freshState(region)
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)
        let (afterSplit, targetA, targetB) = runSustainSplit(state, sustain: 750)
        state = afterSplit
        XCTAssertNotEqual(targetA, targetB, "the halves must strip different fields")
        let fieldCenters: Set<Waypoint> = [
            Waypoint(x: 500, y: 480), Waypoint(x: 1100, y: 900),
        ]
        XCTAssertTrue(fieldCenters.contains(targetA), "A \(targetA) is not a field")
        XCTAssertTrue(fieldCenters.contains(targetB), "B \(targetB) is not a field")
        XCTAssertEqual(state.subFlockCount, 3, "the split must mint flock 2")
    }

    /// Below the threshold the flock stays whole (splitting a small flock
    /// halves its contest strength for no sustainability gain).
    func testSustainSplitDoesNotFireBelowThreshold() {
        let region = makeTestRegion(rivalStartBirds: 600)
        var state = freshState(region)
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)
        var rival = GentleRival(difficulty: .hard)
        rival.sustainSplit = 750
        let action = rival.action(for: state)
        if case .splitFlock? = action {
            XCTFail("600 birds must not trigger a 750-bird sustain split")
        }
    }

    /// Gentle and normal keep the single-flock behavior by default; only
    /// hard starts with the sustain split enabled.
    func testSustainSplitDefaultsToOffForGentle() {
        let region = makeTestRegion()
        var state = freshState(region)
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)
        var rival = GentleRival(difficulty: .gentle)
        XCTAssertEqual(GentleRival.cadence(.gentle).sustain, 0)
        XCTAssertGreaterThanOrEqual(GentleRival.cadence(.hard).sustain, 500)
        let action = rival.action(for: state)
        if case .splitFlock? = action {
            XCTFail("gentle must not sustain-split by default")
        }
    }

    /// The sustain split fires at most once per day (a re-merge plus
    /// regrowth cannot trigger a second split until the next dawn).
    func testSustainSplitOnlyOncePerDay() {
        let region = makeTestRegion()
        var state = freshState(region)
        teleportFlock(&state, subFlock: 1, x: 1024, y: 768)
        var rival = GentleRival(difficulty: .hard)
        rival.sustainSplit = 750
        rival.sustainSplitDone = true
        let action = rival.action(for: state)
        if case .splitFlock? = action {
            XCTFail("the sustain split must fire only once per day")
        }
    }

    // MARK: - Multi-flock forage

    /// A split flock plans foraging for flock 2 with flock 1's centroid in
    /// the avoid set: from the exact midpoint of the two fields, flock 2
    /// must take the field flock 1 is not on, even though the scorer's
    /// field-order tiebreak would otherwise hand it the same field.
    func testFlockTwoForageAvoidsFlockOneField() {
        let region = makeTestRegion()
        let (splitState, targetA, targetB) = runSustainSplit(
            freshState(region), sustain: 750
        )
        var state = splitState
        // Flock 1 works its routed field; flock 2 sits exactly midway
        // between the fields (equal travel cost to both).
        let flockOneField = targetA
        let midpoint = Waypoint(x: 800, y: 690)
        teleportFlock(&state, subFlock: 1, x: flockOneField.x, y: flockOneField.y)
        teleportFlock(&state, subFlock: 2, x: midpoint.x, y: midpoint.y)
        teleportFlock(&state, subFlock: 0, x: 100, y: 100)
        state.energy[1] = 0
        state.energy[2] = 0
        var rival = GentleRival(difficulty: .hard)
        rival.sustainSplit = 750
        rival.lastForageTickByFlock = [1: Autoplayer.noTick, 2: Autoplayer.noTick]
        rival.lastTargetByFlock = [
            1: Waypoint(x: flockOneField.x, y: flockOneField.y),
            2: Waypoint(x: midpoint.x, y: midpoint.y),
        ]
        guard case .setLeaderPath(2, let path)? = rival.action(for: state) else {
            return XCTFail("expected flock 2 to receive its own forage plan")
        }
        let pick = path.first ?? Waypoint(x: -1, y: -1)
        XCTAssertEqual(pick, Waypoint(x: 1100, y: 900),
                       "flock 2 must avoid flock 1's field and take the other one")
        XCTAssertNotEqual(pick, flockOneField)
        XCTAssertNotEqual(targetA, targetB)
    }

    /// A lone rival flock (no split) plans exactly as before: the same
    /// single-avoid directive on flock 1 (behavior preservation).
    func testLoneFlockForageUnchanged() {
        let region = makeTestRegion(rivalStartBirds: 600)
        var state = freshState(region)
        teleportFlock(&state, subFlock: 1, x: 800, y: 690)
        teleportFlock(&state, subFlock: 0, x: 100, y: 100)
        state.energy[1] = 0
        var rival = GentleRival(difficulty: .hard)
        rival.lastForageTickByFlock = [1: Autoplayer.noTick]
        guard case .setLeaderPath(1, let path)? = rival.action(for: state) else {
            return XCTFail("expected a lone flock to forage")
        }
        XCTAssertEqual(path.first, Waypoint(x: 500, y: 480),
                       "the nearer field A is the natural pick for a lone flock")
    }
}
