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
        XCTAssertNil(ai.action(for: state), "interval not due")
        state.tick = 480
        XCTAssertNil(ai.action(for: state), "same best field: do not teleport the leader")
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

    func testAutoplayerCondensesInsideRoost() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        state.tick = GameState.duskStart
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 400
            state.birds.posY[i] = 400
        }
        _ = ai.action(for: state)  // issues the dusk path to the roost
        guard case .condense(let sf)? = ai.action(for: state) else {
            return XCTFail("expected a condense inside the roost")
        }
        XCTAssertEqual(sf, 0)
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
        XCTAssertEqual(state.subFlockCount, 2)
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
