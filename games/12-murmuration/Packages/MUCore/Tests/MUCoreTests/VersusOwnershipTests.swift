import XCTest
@testable import MUCore

/// Versus sub-flock ownership tests (ADR-0033).
///
/// Versus mode keeps two sides: the player's flocks and the rival's. Every
/// mechanism that creates or reassigns a sub-flock must respect side
/// ownership — falcon forced splits, player/rival splits, and the day-end
/// roost tally. Before ADR-0033, a forced split moved player birds into the
/// rival's flock (and vice versa), which let the rival bank claims with
/// birds the player still steered and drained the player's energy bucket.
final class VersusOwnershipTests: XCTestCase {
    /// Minimal versus world: two roosts, no falcons, 30% of the birds rival.
    private func makeVersusState() -> GameState {
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [10, 10],
            fieldRadius: [128, 128],
            fieldCenterX: [1024, 1600],
            fieldCenterY: [768, 768],
            roostCount: 2,
            roostCenterX: [512, 1536],
            roostCenterY: [768, 768],
            roostRadius: [128, 128],
            falconCount: 0,
            hasRival: true,
            windSeedOffset: 0,
            seed: 42
        )
        state.versusMergeSuppressed = true
        let (spawned, _) = applyAction(.spawnRival(ratio: 0.3), to: state)
        return spawned
    }

    /// The starter spawn creates the rival's side: flock 1 is owned by the
    /// rival, flock 0 by the player, and the player keeps its birds.
    func testSpawnRivalCreatesRivalSideFlock() {
        let state = makeVersusState()

        XCTAssertEqual(state.subFlockCount, 2)
        XCTAssertEqual(state.subFlockOwners, [0, 1])
        let player = state.subFlockAssignments.filter { $0 == 0 }.count
        let rival = state.subFlockAssignments.filter { $0 == 1 }.count
        XCTAssertEqual(player, 70)
        XCTAssertEqual(rival, 30)
        XCTAssertEqual(state.energy.count, 2)
        XCTAssertEqual(state.roostClaims[0].count, 2)
    }

    /// A falcon forced split on the player's flock must stay on the player's
    /// side: it creates (or targets) a player-owned flock and never hands
    /// birds to the rival (this was the G4 balance-sweep inversion bug).
    func testForcedSplitPlayerSideStaysPlayer() {
        var state = makeVersusState()
        let before = state.subFlockAssignments

        let to = forceSplit(state: &state, from: 0)
        let owner = state.subFlockOwners[Int(to)]

        XCTAssertEqual(owner, 0, "forced split must not cross sides")
        XCTAssertEqual(state.subFlockCount, 3)
        for i in before.indices {
            let was = Int(before[i])
            let now = Int(state.subFlockAssignments[i])
            if was != now {
                XCTAssertEqual(state.subFlockOwners[now], 0, "bird \(i) crossed sides")
            }
        }
        // The new flock gets an energy bucket and a claims row (R-12).
        XCTAssertEqual(state.energy.count, 3)
        XCTAssertEqual(state.roostClaims[0].count, 3)
    }

    /// A forced split on the rival's flock must stay on the rival's side.
    func testForcedSplitRivalSideStaysRival() {
        var state = makeVersusState()
        let before = state.subFlockAssignments

        let to = forceSplit(state: &state, from: 1)

        XCTAssertEqual(state.subFlockOwners[Int(to)], 1)
        XCTAssertEqual(state.subFlockCount, 3)
        for i in before.indices {
            let was = Int(before[i])
            let now = Int(state.subFlockAssignments[i])
            if was != now {
                XCTAssertEqual(state.subFlockOwners[now], 1, "bird \(i) crossed sides")
            }
        }
    }

    /// When the side already has a second flock, the forced split toggles
    /// birds into it instead of creating a third flock for that side.
    func testForcedSplitTogglesWithinSide() {
        var state = makeVersusState()
        // Give the player a second flock (flock 2) via a scripted split.
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        XCTAssertEqual(state.subFlockOwners, [0, 1, 0])

        let playerBefore = state.subFlockAssignments.filter {
            state.subFlockOwners[Int($0)] == 0
        }.count
        let to = forceSplit(state: &state, from: 0)

        XCTAssertEqual(to, 2)
        XCTAssertEqual(state.subFlockCount, 3, "no third flock on one side")
        XCTAssertEqual(state.energy.count, 3, "no new energy bucket")
        let playerAfter = state.subFlockAssignments.filter {
            state.subFlockOwners[Int($0)] == 0
        }.count
        // Same-side redistribution: the player side keeps all 70 birds; the
        // struck flock 0 halves by index order (18 stay, 17 move to flock 2).
        // Before ADR-0033 the target was the rival's flock 1: the player side
        // dropped to 18 and the rival grew to 47.
        XCTAssertEqual(playerAfter, playerBefore, "birds stay on their side")
        XCTAssertEqual(playerAfter, 70)
        let f0 = state.subFlockAssignments.filter { $0 == 0 }.count
        let f2 = state.subFlockAssignments.filter { $0 == 2 }.count
        XCTAssertEqual(f0, 18)
        XCTAssertEqual(f2, 52)
    }

    /// Each side may split to a second flock of its own; a third flock per
    /// side is refused. Before ADR-0033 the global `<= 2` guard blocked the
    /// rival's split once the player had split (and vice versa).
    func testSplitCapIsPerSide() {
        var state = makeVersusState()

        let (playerSplit, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = playerSplit
        XCTAssertEqual(state.subFlockOwners, [0, 1, 0])

        let (rivalSplit, _) = applyAction(.splitFlock(from: 1, ratio: 0.5), to: state)
        state = rivalSplit
        XCTAssertEqual(state.subFlockOwners, [0, 1, 0, 1])
        XCTAssertEqual(state.energy.count, 4)

        // Third flock on the player's side: refused.
        let (refused, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        XCTAssertEqual(refused.subFlockOwners, [0, 1, 0, 1])
        XCTAssertEqual(refused.subFlockCount, 4)
    }

    /// The day-end roost tally counts by side ownership: a roost led by a
    /// player-owned second flock counts for the player (before ADR-0033 any
    /// claimant above 0 counted for the rival).
    func testRoostTallyCountsByOwnership() {
        var state = makeVersusState()
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split

        // Player's second flock (2) leads roost 1; rival (1) leads roost 0.
        state.roostClaims[0] = [0, 10, 0]
        state.roostClaims[1] = [0, 0, 10]

        let (events, victory) = checkVictory(state: &state)

        // Before ADR-0033 the claimant==0 check counted flock 2 for the
        // rival: dayEnd would be (0, 2) and the rival wins outright. With
        // ownership the tally is 1-1; player side has 70 birds (35 + 35)
        // against the rival's 30, so the tiebreak goes to the player.
        let dayEnd = events.first { if case .dayEnd = $0 { return true }; return false }
        XCTAssertEqual(dayEnd, .dayEnd(playerFlocksWon: 1, rivalFlocksWon: 1))
        XCTAssertEqual(victory, .victory(winner: 0))
    }

    /// The birds-alive tiebreak counts by side: birds in a player-owned
    /// second flock belong to the player's total, not the rival's.
    func testRoostTiebreakCountsByOwnership() {
        var state = makeVersusState()
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.2), to: state)
        state = split

        // One roost each: flock 1 (rival) takes roost 0, flock 2 (player
        // side) takes roost 1. The split moved 20% of flock 0 (14 of 70)
        // into flock 2; flock 1 kept its 30 from the spawn.
        state.roostClaims[0] = [0, 10, 0]
        state.roostClaims[1] = [0, 0, 10]

        let (_, victory) = checkVictory(state: &state)

        // Player side: 56 + 14 = 70 birds; rival side: 30. The tally is
        // 1-1, so the tiebreak decides: the player's second flock's birds
        // count for the player. Before ADR-0033 the tally itself read
        // (0, 2) and the rival won without reaching the tiebreak.
        XCTAssertEqual(victory, .victory(winner: 0))
    }
}
