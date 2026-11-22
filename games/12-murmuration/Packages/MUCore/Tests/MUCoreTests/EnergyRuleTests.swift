import XCTest
@testable import MUCore

/// Energy rule tests (R-8 drain/feeding, R-9 growth/starvation).
final class EnergyRuleTests: XCTestCase {
    /// R-8: 1 energy per tick per 100 birds drains while flying.
    func testR8EnergyDrain() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [800]

        let drainEvents = computeEnergyDrain(state: &state)

        // With 100 birds, drain = 100 * 1 / 100 = 1
        XCTAssertEqual(drainEvents.count, 1)
        XCTAssertEqual(state.energy[0], 799)
    }

    /// R-8: zero birds drain nothing.
    func testR8EnergyDrainZeroBirds() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 0,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [800]

        let drainEvents = computeEnergyDrain(state: &state)

        // With 0 birds, drain = 0
        XCTAssertEqual(drainEvents.count, 0)
        XCTAssertEqual(state.energy[0], 800)
    }

    /// R-8 regression (ADR-0032): the drain applies only "while flying" — a
    /// sub-flock settled at a roost (centroid inside the roost radius) must
    /// not drain, otherwise every flock starves through the 900-tick dusk
    /// because no region's roosts overlap feeding fields.
    func testR8EnergyDrainSkippedWhenSettledAtRoost() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // All 100 birds inside the roost radius → settled, no drain.
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 512
            state.birds.posY[i] = 768
        }
        state.energy = [800]

        let drainEvents = computeEnergyDrain(state: &state)

        XCTAssertEqual(drainEvents.count, 0, "a settled flock must not drain")
        XCTAssertEqual(state.energy[0], 800)
    }

    /// R-8 (ADR-0032): the settled exemption is anchored on the sub-flock
    /// centroid — a split flock whose settled half is at the roost still
    /// drains its flying half, so the exemption cannot be exploited by
    /// parking one bird at the roost while the flock forages.
    func testR8EnergyDrainAppliesWhenCentroidOutsideRoost() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // All birds far from the roost (centroid far outside 2× radius).
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1600
            state.birds.posY[i] = 1200
        }
        state.energy = [800]

        _ = computeEnergyDrain(state: &state)

        XCTAssertEqual(state.energy[0], 799, "a flying flock of 100 drains 1/tick")
    }

    /// R-8: birds inside a field's radius feed by field richness; the field
    /// depletes as it is fed.
    func testR8EnergyFeeding() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [50],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [100]

        // Place all birds inside the field
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768
        }

        var rng = SeededRNG(seed: 1)
        let feedEvents = computeFeeding(state: &state, rng: &rng)

        // Birds should feed from the field
        XCTAssertGreaterThan(feedEvents.count, 0)
        XCTAssertTrue(state.energy[0] > 100)
    }

    /// R-8 + INV-3 regression: when two flocks share a nearly-full field, the
    /// residual capacity goes to the LOWEST flock deterministically. The old
    /// Set-based candidate list iterated in unspecified order, so the last
    /// units of a nearly-full field went to whichever flock Swift's Set
    /// happened to visit first — run A and run B of the same seed diverged.
    func testR8FeedingResidualGoesToLowestFlock() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 20,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // Two flocks of 10, both inside the field.
        state.subFlockAssignments = (0..<20).map { UInt8($0 % 2) }
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768
            state.birds.subFlock[i] = state.subFlockAssignments[i]
        }
        state.energy = [100, 100]
        // Exactly 2 units of capacity remain: gain = min(10, 2) for the first
        // flock visited; the second gets nothing once the field is full.
        state.fields[0].currentDepletion = state.fields[0].maxDepletion - 2

        var rng = SeededRNG(seed: 1)
        let feedEvents = computeFeeding(state: &state, rng: &rng)

        XCTAssertEqual(state.energy[0], 102, "flock 0 (lowest) takes the residual")
        XCTAssertEqual(state.energy[1], 100, "flock 1 gets nothing once the field is full")
        XCTAssertEqual(state.fields[0].currentDepletion, state.fields[0].maxDepletion)
        XCTAssertEqual(feedEvents.count, 1)
    }

    /// R-9: every 200 energy above 600 grows the flock by 5%.
    func testR9EnergyGrowth() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // Set energy above growth threshold
        state.energy = [800] // 800 > 600 threshold, excess = 200

        var rng = SeededRNG(seed: 1)
        let growthEvents = computeGrowth(state: &state, rng: &rng)

        // Should trigger growth
        XCTAssertGreaterThan(growthEvents.count, 0)
        if case .grow(_, let newBirds) = growthEvents[0] {
            _ = newBirds // Growth produced new birds
        } else {
            XCTFail("Expected .grow event")
        }
    }

    /// R-9: at 0 energy, exactly 1% of the flock drops out per starvation
    /// event (applyTick fires the event every 10 ticks).
    func testR9EnergyStarvation() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [0]

        var rng = SeededRNG(seed: 1)
        let starveEvents = computeStarvation(state: &state, rng: &rng)

        // Exactly 1% (one bird) drops out.
        XCTAssertEqual(starveEvents.count, 1)
        XCTAssertEqual(state.birds.count, 99)
    }

    /// R-9: no starvation while energy is positive.
    func testR9NoStarvationWhenPositive() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 100,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        state.energy = [10]

        var rng = SeededRNG(seed: 1)
        let starveEvents = computeStarvation(state: &state, rng: &rng)

        // No starvation when energy > 0
        XCTAssertEqual(starveEvents.count, 0)
        XCTAssertEqual(state.birds.count, 100)
    }

    /// R-8 regression: feeding gain counts the birds actually inside the
    /// field's radius, not the whole sub-flock. The old implementation used
    /// the whole-flock count whenever any bird grazed the edge, so a single
    /// straggler drained the field at the full flock's rate and reset the
    /// regrowth clock every tick — spent fields never re-armed and flocks
    /// starved. See ADR-0028.
    func testR8FeedingCountsBirdsInField() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 20,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        // 5 birds inside the field, 15 far outside it (all flock 0).
        for i in 0..<state.birds.count {
            state.birds.subFlock[i] = 0
            state.subFlockAssignments[i] = 0
            if i < 5 {
                state.birds.posX[i] = 1024
                state.birds.posY[i] = 768
            } else {
                state.birds.posX[i] = 100
                state.birds.posY[i] = 100
            }
        }
        state.energy = [100]

        var rng = SeededRNG(seed: 1)
        let feedEvents = computeFeeding(state: &state, rng: &rng)

        // gain = birdsInField * richness / 7 = 5 * 10 / 7 = 7 (ADR-0032: the
        // feed divisor is engine tuning, not a roadmap-pinned rule; the /7
        // rate keeps grazing ahead of flight drain so flocks can reach the
        // G4 dusk-flock window).
        XCTAssertEqual(feedEvents.count, 1)
        guard case .feed(_, let amount, _) = feedEvents[0] else {
            return XCTFail("expected a feed event")
        }
        XCTAssertEqual(amount, 7)
        XCTAssertEqual(state.energy[0], 107)
        XCTAssertEqual(state.fields[0].currentDepletion, 7)
    }

    /// Regrowth clock pin: a flock grazing a fully spent field gains nothing,
    /// so the clock keeps running (the field can begin to regrow).
    func testRegrowthClockRunsWhenSpentFieldGrazed() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768
        }
        state.fields[0].currentDepletion = state.fields[0].maxDepletion

        var rng = SeededRNG(seed: 1)
        for _ in 0..<50 {
            _ = computeFeeding(state: &state, rng: &rng)
        }

        XCTAssertEqual(state.fields[0].ticksSinceFeed, 50, "grazing a spent field gains nothing and must not reset the clock")
        XCTAssertEqual(state.fields[0].currentDepletion, state.fields[0].maxDepletion)
    }

    /// Regrowth clock pin: actual gain resets the clock — grazing a regrowing
    /// field interrupts regrowth (rivals can deny regrowth by grazing).
    func testGainResetsRegrowthClock() {
        let params = BoidsParams()
        var state = GameState(
            birdCount: 10,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [10],
            fieldRadius: [200],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: 42
        )
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 1024
            state.birds.posY[i] = 768
        }
        // Field partially spent with the clock already halfway to regrowth.
        state.fields[0].currentDepletion = 20
        state.fields[0].ticksSinceFeed = 50

        var rng = SeededRNG(seed: 1)
        _ = computeFeeding(state: &state, rng: &rng)

        XCTAssertGreaterThan(state.energy[0], 100, "the flock must gain energy while the field has capacity")
        // The feed resets the clock to 0; the same call's regrowth block then
        // increments it once, so a feed tick leaves the clock at 1.
        XCTAssertEqual(state.fields[0].ticksSinceFeed, 1, "a real feed restarts the regrowth clock")
        // gain = 10 birds * richness 10 / 7 = 14 (ADR-0032 feed divisor)
        XCTAssertEqual(state.fields[0].currentDepletion, 34)
    }
}
