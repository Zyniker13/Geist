import XCTest
import MUCore
import MUContent
@testable import MUAI

/// P4.1 regression tests for regrowth-aware foraging: the autoplayer and
/// the rival must leave a spent field immediately instead of sitting on
/// its one-tick trickle, and the rival must not overwrite its flee path
/// with a forage path while the flocks are still coincident.
final class ForageTests: XCTestCase {
    // MARK: - Fixtures

    /// Asymmetric two-field, two-roost region (same shape as MUAITests).
    /// Field A (500, 480) and field B (1560, 1060), both richness 60.
    private func makeRegion() -> Region {
        Region(
            id: "forage", name: "Forage",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1400, falconCount: 1, hasRival: true,
            rivalStartBirds: 600,
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

    /// Day-start state with both flocks split and coincident at the center.
    private func freshState() -> GameState {
        let region = makeRegion()
        let state = region.makeGameState()
        return apply(RegionStarter.startingActions(for: region), to: state)
    }

    private func spend(_ state: inout GameState, field: Int, ramped: Bool) {
        state.fields[field].currentDepletion = state.fields[field].maxDepletion
        state.fields[field].ticksSinceFeed = ramped ? ForageScoring.rampTicks : 0
    }

    // MARK: - Autoplayer

    /// A spent field must be abandoned on the very next tick, not after
    /// the old 480-tick forage interval.
    func testAutoplayerLeavesSpentFieldAtOnce() {
        var state = freshState()
        spend(&state, field: 0, ramped: false)
        var ai = Autoplayer()
        ai.lastTarget = Waypoint(x: 500, y: 480)
        guard case .setLeaderPath(let sf, let waypoints)? = ai.action(for: state) else {
            return XCTFail("expected the autoplayer to leave the spent field at once")
        }
        XCTAssertEqual(sf, 0)
        XCTAssertEqual(waypoints, [Waypoint(x: 1560, y: 1060)])
    }

    /// While the current field still holds food, the hysteresis bonus keeps
    /// the flock from oscillating to the other field: no re-path (a
    /// condense while the cooldown lapsed is fine — it never moves the
    /// leader).
    func testAutoplayerHoldsWhileFoodRemains() {
        var state = freshState()
        // Field A keeps most of its budget; the flock is already there.
        state.fields[0].currentDepletion = state.fields[0].maxDepletion - 1000
        var ai = Autoplayer()
        ai.lastTarget = Waypoint(x: 500, y: 480)
        if case .setLeaderPath? = ai.action(for: state) {
            return XCTFail(
                "expected the autoplayer to hold a field that still has food")
        }
    }

    /// With both fields spent and the flock sitting on the one whose ramp
    /// is still running, the scorer must keep it there (waiting out the
    /// ramp) instead of oscillating to the other spent field.
    func testForageScoringWaitsOutRampInsteadOfOscillating() {
        var state = freshState()
        spend(&state, field: 0, ramped: true)
        spend(&state, field: 1, ramped: false)
        // The flock is sitting on field B (its centroid is at B).
        let pick = ForageScoring.bestField(
            state, nearX: 1560, nearY: 1060, birds: 1400,
            current: Waypoint(x: 1560, y: 1060))
        XCTAssertEqual(pick?.centerX, 1560,
                       "expected the flock to wait out the ramp on its own field")
    }

    // MARK: - Rival

    /// The rival re-decides immediately when its field runs out, even if
    /// the tier's forage interval has not elapsed. The rival's flock is
    /// placed on field B and the player's flock at the world center (outside
    /// both field radii), so B is the rival's only current field and the
    /// player cannot drain A.
    func testRivalForagesImmediatelyWhenFieldSpent() {
        var state = freshState()
        // Place the rival's flock on field B and the player's flock at the
        // world center, so the only field the rival sits on is B.
        for i in state.birds.posX.indices {
            if state.subFlockAssignments[i] == 1 {
                state.birds.posX[i] = 1560
                state.birds.posY[i] = 1060
            } else {
                state.birds.posX[i] = 1024
                state.birds.posY[i] = 768
            }
            state.birds.velX[i] = 0
            state.birds.velY[i] = 0
        }
        // Pin the player's leader path at the center too, so the rival's
        // avoid penalty is measured from a known point.
        state = apply(
            [.setLeaderPath(subFlock: 0, waypoints: [Waypoint(x: 1024, y: 768)])],
            to: state)
        var rival = GentleRival(difficulty: .gentle)
        rival.lastTargetByFlock[1] = Waypoint(x: 1560, y: 1060)
        rival.lastForageTickByFlock[1] = state.tick // interval not elapsed
        spend(&state, field: 1, ramped: false)
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected the rival to leave its spent field at once")
        }
        XCTAssertEqual(sf, 1)
        XCTAssertEqual(waypoints, [Waypoint(x: 500, y: 480)])
    }

    /// While the flocks are still coincident (within the flee radius), the
    /// rival must keep its standoff path and must not issue a forage path
    /// that steers it back into the player.
    func testRivalDoesNotForageWhileFleeing() {
        let state = freshState()
        var rival = GentleRival(difficulty: .gentle)
        // lastForageTick = noTick, so the forage interval is elapsed and
        // foraging would fire this tick if not suppressed by the flee guard.
        guard case .setLeaderPath(let sf, let waypoints)? = rival.action(for: state) else {
            return XCTFail("expected the rival to issue its flee path")
        }
        XCTAssertEqual(sf, 1)
        let isField = state.fields.contains {
            $0.centerX == waypoints.first?.x && $0.centerY == waypoints.first?.y
        }
        XCTAssertFalse(isField,
                       "the flee path must not be a forage path into a field")
    }

    // MARK: - Scorer

    /// The scorer is deterministic: identical states yield identical picks.
    func testForageScoringIsDeterministic() {
        let state = freshState()
        let a = ForageScoring.bestField(state, nearX: 1024, nearY: 768, birds: 1400, current: nil)
        let b = ForageScoring.bestField(state, nearX: 1024, nearY: 768, birds: 1400, current: nil)
        XCTAssertEqual(a, b)
    }
}

// MARK: - Directive

/// P4.1 pulse-harvest: the shared directive must fly the flock to a field
/// worth stripping, stand it clear of regrowing fields (whose ramp any
/// grazer restarts), and only graze whatever exists when starving.
final class ForageDirectiveTests: XCTestCase {
    private func makeRegion() -> Region {
        Region(
            id: "forage", name: "Forage",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1400, falconCount: 1, hasRival: true,
            rivalStartBirds: 600,
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

    private func spend(_ state: inout GameState, field: Int, ramped: Bool) {
        state.fields[field].currentDepletion = state.fields[field].maxDepletion
        state.fields[field].ticksSinceFeed = ramped ? ForageScoring.rampTicks : 0
    }

    private func assertClearOfFields(
        _ point: Waypoint, _ fields: [FieldState],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for field in fields {
            let dx = Int64(point.x) - Int64(field.centerX)
            let dy = Int64(point.y) - Int64(field.centerY)
            let d = isqrt64(UInt64(max(0, dx * dx + dy * dy)))
            XCTAssertGreaterThanOrEqual(
                d, Int64(field.radius) + Int64(ForageScoring.standoffMargin),
                "standoff point \(point) sits \(d) from field center \(field.centerX),\(field.centerY)",
                file: file, line: line)
        }
    }

    func testDirectiveForagesFreshField() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        let directive = ForageScoring.directive(
            state, bank: 400,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        guard case .forage(let point) = directive else {
            return XCTFail("expected .forage, got \(directive)")
        }
        let centers: [(x: Int32, y: Int32)] = [(500, 480), (1560, 1060)]
        XCTAssertTrue(
            centers.contains { $0.x == point.x && $0.y == point.y },
            "expected a field center, got \(point)")
    }

    func testDirectiveStandsOffFromSpentFields() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        spend(&state, field: 0, ramped: true)
        spend(&state, field: 1, ramped: true)
        let directive = ForageScoring.directive(
            state, bank: 400,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        guard case .standoff(let point) = directive else {
            return XCTFail("expected .standoff, got \(directive)")
        }
        assertClearOfFields(point, state.fields)
    }

    func testDirectiveStandoffHoldsPointWhileFieldsRegrow() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        spend(&state, field: 0, ramped: true)
        spend(&state, field: 1, ramped: true)
        guard case .standoff(let first) = ForageScoring.directive(
            state, bank: 400,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        else { return XCTFail("expected first .standoff") }
        // With the previous standoff point still clear, the directive must
        // return the same point so the flock does not chase a moving goal.
        let second = ForageScoring.directive(
            state, bank: 380,
            flock: (x: 1030, y: 770, birds: 100),
            pilot: .init(current: first, standoff: first))
        XCTAssertEqual(second, .standoff(first))
    }

    func testDirectiveReturnsWhenFieldRearms() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        spend(&state, field: 0, ramped: true)
        spend(&state, field: 1, ramped: true)
        guard case .standoff = ForageScoring.directive(
            state, bank: 400,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        else { return XCTFail("expected initial .standoff") }
        // Field 0 has refilled to 60% of its budget: worth a strip trip.
        state.fields[0].currentDepletion =
            state.fields[0].maxDepletion * 4 / 10
        let directive = ForageScoring.directive(
            state, bank: 350,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        guard case .forage(let point) = directive else {
            return XCTFail("expected .forage, got \(directive)")
        }
        XCTAssertEqual(point.x, 500)
        XCTAssertEqual(point.y, 480)
    }

    func testDirectiveStarvingGrazesWhateverExists() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        // Field A spent and ramped with a real meal regrown (300 left);
        // field B fully spent. A starving flock flies for the meal —
        // with every field below the starve floor it would stand off.
        spend(&state, field: 1, ramped: true)
        var meal = state.fields[0]
        meal.currentDepletion = meal.maxDepletion - 300
        state.fields[0] = meal
        let directive = ForageScoring.directive(
            state, bank: 50,
            flock: (x: 1024, y: 768, birds: 100),
            pilot: .init(current: nil, standoff: nil))
        guard case .forage(let point) = directive else {
            return XCTFail("expected starving .forage, got \(directive)")
        }
        XCTAssertEqual(point.x, meal.centerX)
        XCTAssertEqual(point.y, meal.centerY)
    }

    func testStandoffPointClampsToWorld() {
        let region = Region(
            id: "forage", name: "Forage",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 1400, falconCount: 1, hasRival: true,
            rivalStartBirds: 600,
            windSeedOffset: 0, seed: 7,
            roosts: [.init(x: 1000, y: 1400, radius: 120)],
            fields: [.init(x: 10, y: 10, radius: 128, richness: 60)],
            palette: .standard
        )
        let state = region.makeGameState()
        let blocked = ForageScoring.blockedFields(state, nearX: 10, nearY: 10)
        let point = ForageScoring.standoffPoint(
            clearOf: blocked, nearX: 10, nearY: 10,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight)
        XCTAssertGreaterThanOrEqual(point.x, 0)
        XCTAssertGreaterThanOrEqual(point.y, 0)
        XCTAssertLessThan(point.x, state.worldWidth)
        XCTAssertLessThan(point.y, state.worldHeight)
        assertClearOfFields(point, blocked)
    }

    /// Commitment: while the pilot's current target still holds a
    /// worthwhile meal, the directive keeps it even when another field
    /// scores higher — re-deciding every tick teleported the leader
    /// between fields and the flock orbited instead of arriving
    /// (ADR-0029). Only once the target drops below worth does the
    /// directive re-decide.
    func testDirectiveKeepsCurrentTargetWhileWorth() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        // Both fields full; the flock stands on field A but its current
        // target is the far field B. Even though A scores higher, the
        // directive must commit to B.
        let committed = ForageScoring.directive(
            state, bank: 400,
            flock: (x: 500, y: 480, birds: 1400),
            pilot: .init(current: Waypoint(x: 1560, y: 1060), standoff: nil))
        XCTAssertEqual(committed, .forage(Waypoint(x: 1560, y: 1060)))
        // Once B is spent the commitment lapses and the directive
        // re-decides — to field A, which is full and near.
        var spent = state
        spend(&spent, field: 1, ramped: true)
        let redecided = ForageScoring.directive(
            spent, bank: 400,
            flock: (x: 1560, y: 1060, birds: 1400),
            pilot: .init(current: Waypoint(x: 1560, y: 1060), standoff: nil))
        guard case .forage(let point) = redecided else {
            return XCTFail("expected re-decision to field A, got \(redecided)")
        }
        XCTAssertEqual(point.x, 500)
        XCTAssertEqual(point.y, 480)
    }

    /// A starving flock must not orbit empty fields: with every field
    /// stripped and no food expected by arrival, the directive stands
    /// off and waits for the regrowth ramp instead of chasing crumbs
    /// that do not exist (the old starve branch picked the least-bad
    /// empty field every tick, so the leader teleported among spent
    /// fields while the bank drained to zero — ADR-0029).
    func testDirectiveStarvingStandsOffWhenNothingYields() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        spend(&state, field: 0, ramped: false)
        spend(&state, field: 1, ramped: false)
        let directive = ForageScoring.directive(
            state, bank: 50,
            flock: (x: 1024, y: 900, birds: 1400),
            pilot: .init(current: nil, standoff: nil))
        guard case .standoff = directive else {
            return XCTFail("expected standoff while all fields are spent, got \(directive)")
        }
    }

    /// Regrowth-by-arrival is dishonest for a starving flock: flying to
    /// a ramped crumb and nibbling its trickle restarts the field's
    /// regrowth ramp, so the counted regrowth never materialises — the
    /// flock milked ~36 food per visit while every field stayed pinned
    /// near empty (ADR-0029). A starving flock only flies for food the
    /// field HOLDS now; otherwise it stands off and lets fields rebuild.
    func testDirectiveStarvingIgnoresRegrowthOnCrumbs() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        spend(&state, field: 0, ramped: false)
        var crumb = state.fields[1]
        crumb.currentDepletion = crumb.maxDepletion - 13
        crumb.ticksSinceFeed = ForageScoring.rampTicks
        state.fields[1] = crumb
        // The flock stands a field-trip away: the ramped crumb plus
        // regrowth-by-arrival once scored ~170, enough to lure a trip
        // that would milk the trickle and pin the field.
        let directive = ForageScoring.directive(
            state, bank: 50,
            flock: (x: 1013, y: 335, birds: 1400),
            pilot: .init(current: nil, standoff: nil))
        guard case .standoff = directive else {
            return XCTFail("expected standoff on a ramped crumb, got \(directive)")
        }
    }

    /// The standoff point prefers the nearest grid point that clears
    /// every field by the margin, so the wait phase's travel is short;
    /// when no point clears that far it falls back to the greatest
    /// clearance. Either way the point never sits inside a field's
    /// exclusion radius (ADR-0029).
    func testStandoffPointPrefersNearbyClearPoint() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        // Both fields spent, so the standoff branch runs.
        spend(&state, field: 0, ramped: false)
        spend(&state, field: 1, ramped: false)
        let point = ForageScoring.standoffPoint(
            clearOf: state.fields, nearX: 700, nearY: 750,
            worldWidth: state.worldWidth, worldHeight: state.worldHeight)
        assertClearOfFields(point, state.fields)
        // Nearer than the far corner the old max-min-only scan picked.
        let dx = Int64(point.x) - 700
        let dy = Int64(point.y) - 750
        let dist = isqrt64(UInt64(dx * dx + dy * dy))
        XCTAssertLessThan(
            dist, 900,
            "standoff point should be near the flock, got dist \(dist)")
    }

    /// A starving flock standing on a field with food left finishes the
    /// meal: abandoning mid-meal left food behind and re-issued a path
    /// every tick. A crumb is only worth finishing when the flock is
    /// already there — chasing a distant crumb milks a trickle and
    /// resets the field's ramp, so that stays forbidden (ADR-0029).
    func testDirectiveStarvingFinishesMealOnCrumbTarget() {
        var state = makeRegion().makeGameState()
        state.tick = 1
        // All fields spent except the current target, which holds a
        // little food; the flock stands on it and must finish the meal.
        spend(&state, field: 0, ramped: false)
        var crumb = state.fields[1]
        crumb.currentDepletion = crumb.maxDepletion - 100
        state.fields[1] = crumb
        let directive = ForageScoring.directive(
            state, bank: 50,
            flock: (x: crumb.centerX, y: crumb.centerY, birds: 1400),
            pilot: .init(
                current: Waypoint(x: crumb.centerX, y: crumb.centerY),
                standoff: nil))
        XCTAssertEqual(
            directive, .forage(Waypoint(x: crumb.centerX, y: crumb.centerY)))
    }
}
