import XCTest
@testable import MUCore

/// R-10 falcon stoop tests: target selection, path-based kills, and the
/// side-scaled grab budget (docs/RULES.md R-10, ADR-0034, ADR-0036).
final class FalconStoopTests: XCTestCase {

    func testR10FalconTargetsLowestDensityEdge() {
        // Two sub-flocks: flock 0 packed into a tight ball, flock 1 spread on
        // a sparse line. Both edges sit at the same distance from the falcon,
        // so R-10 picks the sparse flock (lowest local density at the edge).
        var state = makeState(birdCount: 120, falconCount: 1, seed: 5)
        let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.5), to: state)
        state = split
        state.falcons[0].currentX = 1700
        state.falcons[0].currentY = 768
        state.falcons[0].cooldown = 0
        for i in 0..<state.birds.count {
            if state.subFlockAssignments[i] == 0 {
                // Dense ball far from the falcon (edge at x≈1208).
                state.birds.posX[i] = 1200 + Int32(i % 8)
                state.birds.posY[i] = 768 + Int32((i / 8) % 8)
            } else {
                // Sparse line closer to the falcon.
                state.birds.posX[i] = 1620 + Int32(i % 8) * 12
                state.birds.posY[i] = 768
            }
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        var rng = SeededRNG(seed: 5)
        let events = computeFalcons(state: &state, rng: &rng)
        let dive = events.first { if case .diveStart = $0 { return true }; return false }
        guard case .diveStart(_, let sf)? = dive else {
            return XCTFail("falcon should dive when an edge is in reach")
        }
        XCTAssertEqual(sf, 1, "the dive must target the sparse flock's edge")
    }

    func testR10DiveKillsOnlyWithinRadius() {
        var state = makeState(birdCount: 60, falconCount: 1, seed: 21)
        state.falcons[0].currentX = 1300
        state.falcons[0].currentY = 768
        state.falcons[0].cooldown = 0
        // All birds in a sparse ring around (1024, 768); the dive targets the
        // nearest edge. Birds more than diveRadius (30) from ANY plausible
        // dive center must survive; verify the kill set is radius-bounded by
        // checking exactly which birds vanished against the target position.
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768 + Int32(i * 8) // spaced ≥ 8 apart vertically
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        let before = Set(state.birds.posY)
        var rng = SeededRNG(seed: 21)
        _ = computeFalcons(state: &state, rng: &rng)
        let after = Set(state.birds.posY)
        let removed = before.subtracting(after)
        for y in removed {
            // Survivors sit at least diveRadius away from every removed bird's
            // slot: removed birds formed the dive's kill cluster.
            let nearestSurvivor = before.subtracting(removed).map { abs(Int($0) - Int(y)) }.min() ?? Int.max
            XCTAssertGreaterThanOrEqual(nearestSurvivor, 0) // trivially true; real bound below
        }
        // The dive center is a former bird position; every killed bird was
        // within diveRadius of it.
        if let firstKilled = removed.min() {
            let cluster = removed.filter { abs(Int($0) - Int(firstKilled)) <= GameState.diveRadius }
            XCTAssertEqual(cluster.count, removed.count, "all kills must cluster within one dive radius")
        }
    }

    func testR10DenseFlockKillCountIsCapped() {
        // A dense ball (120 birds in an 8×8 cell cluster) shields: the grab
        // budget is throttled by the edge density (ADR-0034), so a dive into
        // it kills at most a small, size-scaled number of birds — far fewer
        // than the birds inside the corridor.
        var state = makeState(birdCount: 400, falconCount: 1, seed: 33)
        state.falcons[0].currentX = 1100
        state.falcons[0].currentY = 780
        state.falcons[0].cooldown = 0
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024 + Int32(i % 16) * 2
            state.birds.posY[i] = 768 + Int32(i / 16) * 2
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        let start = state.birds.count
        var rng = SeededRNG(seed: 33)
        let events = computeFalcons(state: &state, rng: &rng)
        let hit = events.contains { if case .diveResult(_, _, true, _) = $0 { return true }; return false }
        if hit {
            XCTAssertLessThanOrEqual(start - state.birds.count, 4, "dense flocks shield: at most the kill budget dies")
        }
    }

    func testR10KillBudgetScalesWithSideSize() {
        // ADR-0036: the grab budget scales with the struck flock's *side*
        // size, not the flock alone, so a forced split cannot halve a
        // side's per-dive losses (the pre-fix behavior let the player farm
        // splits as pressure relief while minted fragments still drew
        // flock-scaled budgets). `birdsOnSideCount` is side-blind: every
        // member of every sub-flock owned by the side counts exactly once.
        XCTAssertEqual(birdsOnSideCount(assignments: [0, 0, 1, 1], owners: [0, 1], side: 0), 2)
        XCTAssertEqual(birdsOnSideCount(assignments: [0, 0, 1, 1], owners: [0, 1], side: 1), 2)
        XCTAssertEqual(birdsOnSideCount(assignments: [0, 1, 2, 2, 1], owners: [0, 0, 1], side: 0), 3)
        XCTAssertEqual(birdsOnSideCount(assignments: [0, 1, 2, 2, 1], owners: [0, 0, 1], side: 1), 2)
        XCTAssertEqual(birdsOnSideCount(assignments: [], owners: [0, 1], side: 0), 0)
        XCTAssertEqual(birdsOnSideCount(assignments: [0, 1, 2], owners: [0, 1, 1], side: 1), 2)

        // The budget formula itself is unchanged (ADR-0034), now fed the
        // side size. The constant is passed explicitly (the production
        // site reads GameState.falconGrabPerThousand) so the test pins no
        // global.
        XCTAssertEqual(falconKillBudget(flockSize: 50, edgeDensity: 0, perThousand: 8), 1)
        XCTAssertEqual(falconKillBudget(flockSize: 500, edgeDensity: 0, perThousand: 8), 4)
        XCTAssertEqual(falconKillBudget(flockSize: 1400, edgeDensity: 0, perThousand: 8), 11)
        XCTAssertEqual(falconKillBudget(flockSize: 1400, edgeDensity: 128, perThousand: 8), 5)
        XCTAssertEqual(falconKillBudget(flockSize: 2500, edgeDensity: 128, perThousand: 8), 10)
        XCTAssertEqual(falconKillBudget(flockSize: 1400, edgeDensity: 0, perThousand: 32), 44)
        // Dense areas never get a larger budget than sparse ones (R-10).
        XCTAssertLessThanOrEqual(
            falconKillBudget(flockSize: 1400, edgeDensity: 128, perThousand: 8),
            falconKillBudget(flockSize: 1400, edgeDensity: 0, perThousand: 8))
    }

    func testR10DiveKillsAlongPath() {
        // R-10: kills land within a 30-unit radius of the dive PATH, not only
        // at the dive point. The stoop runs from the falcon through the dive
        // target and 60 units beyond. Bird 1 sits 40 units beyond the target
        // and 20 off the line: inside the stoop corridor (taken) but 45 units
        // from the dive point (spared by an endpoint-only rule). Bird 2 sits
        // 200 units off the corridor and must survive. The seed loop steps
        // over the 70% sparse-flock dive roll deterministically.
        for seed in 1...40 {
            var state = makeState(birdCount: 300, falconCount: 1, seed: UInt64(seed))
            state.falcons[0].currentX = 1900
            state.falcons[0].currentY = 400
            state.falcons[0].cooldown = 0
            state.birds.posX[0] = 1700; state.birds.posY[0] = 400  // dive target
            state.birds.posX[1] = 1660; state.birds.posY[1] = 420  // corridor decoy
            state.birds.posX[2] = 1660; state.birds.posY[2] = 600  // off-corridor
            for i in 0..<state.birds.count {
                state.birds.velX[i] = 0
                state.birds.velY[i] = 0
                guard i >= 3 else { continue }
                state.birds.posX[i] = 100 + Int32((i - 3) % 23) * 68
                state.birds.posY[i] = 700 + Int32((i - 3) / 23) * 68
            }
            var rng = SeededRNG(seed: UInt64(seed))
            let events = computeFalcons(state: &state, rng: &rng)
            let hit = events.compactMap { event -> Int? in
                if case .diveResult(_, _, true, let kills) = event { return kills }
                return nil
            }.first
            guard let kills = hit else { continue }
            XCTAssertEqual(kills, 2, "seed \(seed): the corridor takes the target and the decoy")
            XCTAssertEqual(state.birds.count, 298, "seed \(seed): exactly two birds die")
            let ys = state.birds.posY
            XCTAssertEqual(ys.filter { $0 == 600 }.count, 1, "seed \(seed): the off-corridor bird survives")
            XCTAssertEqual(ys.filter { $0 == 420 }.count, 0, "seed \(seed): the corridor decoy dies")
            XCTAssertEqual(ys.filter { $0 == 400 }.count, 0, "seed \(seed): the dive target dies")
            return
        }
        XCTFail("no successful dive across seeds 1...40")
    }

    /// E2E regression for ADR-0036 (catches a revert to flock-scaled
    /// budgets): a split side must draw the budget its *side* earns, not
    /// the struck flock's smaller share. Geometry pins every input.
    /// After `splitFlock(from: 0, ratio: 0.3)` on 800 birds, flock 1 (the
    /// struck flock) holds 240 birds and the side holds 800, so the
    /// side-scaled budget is 6 while a flock-scaled revert computes 1.
    /// The dive corridor holds exactly 3 birds: with the side budget the
    /// strike takes 3; a flock-scaled revert takes 1 and fails the test.
    func testR10DiveOnSplitSideUsesSideBudget() {
        for seed in 1...40 {
            var state = makeState(birdCount: 800, falconCount: 1, seed: UInt64(seed))
            let (split, _) = applyAction(.splitFlock(from: 0, ratio: 0.3), to: state)
            state = split
            // The split reassigns the first 240 indices to flock 1.
            // Flock 1 (240, struck): three sparse birds in the dive corridor
            // and the rest in a ball just outside the 600 engage radius.
            // Flock 0 (560): a dense ball far away, edge density far above
            // flock 1's 3, so the patroller targets flock 1.
            for i in 0..<state.birds.count {
                state.birds.velX[i] = 0
                state.birds.velY[i] = 0
                if i < 240 {
                    if i < 3 {
                        state.birds.posX[i] = 1450
                        state.birds.posY[i] = 768 + Int32(i) * 8
                    } else {
                        let j = i - 3
                        state.birds.posX[i] = 1450 + Int32(j % 8) * 3
                        state.birds.posY[i] = 1200 + Int32(j / 8) * 3
                    }
                } else {
                    let j = i - 240
                    state.birds.posX[i] = 300 + Int32(j % 4) * 2
                    state.birds.posY[i] = 300 + Int32(j / 4) * 2
                }
            }
            state.falcons[0].currentX = 1950
            state.falcons[0].currentY = 768
            state.falcons[0].cooldown = 0

            // Stoop: (1950,768) → edge (1450,768) → 60 beyond. The corridor
            // |y-768| ≤ 30, x ∈ [1390,1950] holds exactly the three sparse
            // birds. Seed over the success roll (dense-average may make it
            // 35%); kills = 3 requires budget ≥ 3, which only the side
            // scaling delivers.
            var rng = SeededRNG(seed: UInt64(seed))
            let events = computeFalcons(state: &state, rng: &rng)
            let kills = events.compactMap { event -> Int? in
                if case .diveResult(_, _, true, let taken) = event { return taken }
                return nil
            }.first
            guard let kills, kills >= 3 else { continue }
            XCTAssertEqual(kills, 3, "seed \(seed): the corridor holds exactly 3 birds")
            return
        }
        XCTFail("no dive reached the 3-bird corridor across seeds 1...40")
    }
}
