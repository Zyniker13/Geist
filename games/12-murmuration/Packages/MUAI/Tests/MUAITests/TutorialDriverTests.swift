import XCTest
import MUCore
import MUContent
@testable import MUAI

/// TutorialDriver tests (P3.2). The driver maps the current tutorial goal to
/// the `GameAction` a player would perform: one-shot goals (draw, split,
/// condense) issue exactly once; continuous goals (feed, roost) re-issue
/// while the goal is incomplete. Same goal + same state → same action (INV-3).
final class TutorialDriverTests: XCTestCase {
    // MARK: - Fixtures

    /// A simple region: one field at (500, 480, richness 60) and one roost at
    /// (400, 400, radius 120), no rival or falcon. `includeRich` adds a richer
    /// (90) field at (1560, 1060); `richDepleted` drains it; `depletedAll`
    /// drains the base field. Depleted variants mutate the built `GameState`
    /// directly, since content defs always start undepleted.
    private func makeState(
        includeRich: Bool = false,
        richDepleted: Bool = false,
        depletedAll: Bool = false
    ) -> GameState {
        var fields: [Region.FieldDef] = [
            .init(x: 500, y: 480, radius: 128, richness: 60)
        ]
        if includeRich {
            fields.append(.init(x: 1560, y: 1060, radius: 128, richness: 90))
        }
        let region = Region(
            id: "driver-test", name: "Driver Test",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 40, falconCount: 0, hasRival: false,
            rivalStartBirds: 0, soloTargetBirds: 0, windSeedOffset: 0,
            seed: 7,
            roosts: [.init(x: 400, y: 400, radius: 120)],
            fields: fields,
            palette: .standard
        )
        var state = region.makeGameState()
        if richDepleted {
            state.fields[1].currentDepletion = state.fields[1].maxDepletion
        }
        if depletedAll {
            state.fields[0].currentDepletion = state.fields[0].maxDepletion
        }
        return state
    }

    private var feedGoal: TutorialGoal { .feed(minEnergyGain: 300) }

    // MARK: - drawPath

    func testDrawPathIssuesOnceWithMinPointsWaypoints() {
        var driver = TutorialDriver()
        let state = makeState()

        guard case let .setLeaderPath(subFlock, waypoints)? = driver.action(
            goal: .drawPath(minPoints: 8), state: state
        ) else {
            return XCTFail("the draw step should issue a leader path")
        }
        XCTAssertEqual(subFlock, 0)
        XCTAssertEqual(waypoints.count, 8)
        XCTAssertNil(
            driver.action(goal: .drawPath(minPoints: 8), state: state),
            "the draw step is one-shot and must not re-issue"
        )
    }

    func testDrawPathWaypointsSpanTheSky() {
        var driver = TutorialDriver()
        let state = makeState()
        guard case let .setLeaderPath(_, waypoints)? = driver.action(
            goal: .drawPath(minPoints: 8), state: state
        ) else {
            return XCTFail("the draw step should issue a leader path")
        }
        // Waypoints ascend in x across the world at mid-height.
        let y = Int32(state.worldHeight / 2)
        for (index, point) in waypoints.enumerated() {
            XCTAssertEqual(point.y, y, "waypoint \(index) should sit at mid-height")
            if index > 0 {
                XCTAssertGreaterThan(
                    point.x, waypoints[index - 1].x,
                    "waypoints should ascend in x"
                )
            }
        }
        XCTAssertLessThanOrEqual(waypoints[waypoints.count - 1].x, state.worldWidth)
    }

    // MARK: - feed

    func testFeedSteersToTheRichestFieldAndReissues() {
        var driver = TutorialDriver()
        let state = makeState(includeRich: true)
        guard case let .setLeaderPath(_, waypoints)? = driver.action(
            goal: feedGoal, state: state
        ) else {
            return XCTFail("the feed step should steer to a field")
        }
        // The richer field (90 vs 60) wins.
        XCTAssertEqual(waypoints, [Waypoint(x: 1560, y: 1060)])
        // Feeding is continuous: the driver re-issues until the goal completes.
        XCTAssertNotNil(driver.action(goal: feedGoal, state: state))
    }

    func testFeedSkipsADepletedField() {
        var driver = TutorialDriver()
        let state = makeState(includeRich: true, richDepleted: true)
        // The richer field is fully depleted; the driver picks the only
        // field that still holds energy.
        guard case let .setLeaderPath(_, waypoints)? = driver.action(
            goal: feedGoal, state: state
        ) else {
            return XCTFail("the feed step should steer to the remaining field")
        }
        XCTAssertEqual(waypoints, [Waypoint(x: 500, y: 480)])
    }

    func testFeedNilWhenEveryFieldIsDepleted() {
        var driver = TutorialDriver()
        let state = makeState(depletedAll: true)
        XCTAssertNil(driver.action(goal: feedGoal, state: state))
    }

    // MARK: - split / condense

    func testSplitIssuesOnceAtHalfRatio() {
        var driver = TutorialDriver()
        let state = makeState()
        guard case let .splitFlock(from, ratio)? = driver.action(
            goal: .splitFlock(subFlocks: 2), state: state
        ) else {
            return XCTFail("the split step should issue a split")
        }
        XCTAssertEqual(from, 0)
        XCTAssertEqual(ratio, 0.5)
        XCTAssertNil(
            driver.action(goal: .splitFlock(subFlocks: 2), state: state),
            "the split step is one-shot and must not re-issue"
        )
    }

    func testCondenseIssuesOnce() {
        var driver = TutorialDriver()
        let state = makeState()
        XCTAssertEqual(
            driver.action(goal: .condense, state: state), .condense(subFlock: 0)
        )
        XCTAssertNil(
            driver.action(goal: .condense, state: state),
            "the condense step is one-shot and must not re-issue"
        )
    }

    // MARK: - roostTarget

    func testRoostHoldsUntilDusk() {
        var driver = TutorialDriver()
        var state = makeState()
        state.tick = GameState.duskStart - 1
        XCTAssertNil(
            driver.action(goal: .roostTarget, state: state),
            "the roost step must not steer before dusk"
        )
    }

    func testRoostSteersToTheFirstRoostAtDuskAndReissues() {
        var driver = TutorialDriver()
        var state = makeState()
        state.tick = GameState.duskStart
        guard case let .setLeaderPath(_, waypoints)? = driver.action(
            goal: .roostTarget, state: state
        ) else {
            return XCTFail("the roost step should steer to a roost at dusk")
        }
        XCTAssertEqual(waypoints, [Waypoint(x: 400, y: 400)])
        // Roosting is continuous: the driver re-issues until the target is met.
        XCTAssertNotNil(driver.action(goal: .roostTarget, state: state))
    }

    // MARK: - Determinism

    func testSameGoalAndStateGiveTheSameAction() {
        let state = makeState(includeRich: true)
        var a = TutorialDriver()
        var b = TutorialDriver()
        XCTAssertEqual(
            a.action(goal: feedGoal, state: state),
            b.action(goal: feedGoal, state: state)
        )
        XCTAssertEqual(
            a.action(goal: .drawPath(minPoints: 8), state: state),
            b.action(goal: .drawPath(minPoints: 8), state: state)
        )
    }

    // MARK: - Full pipeline (headless)

    /// The tutorial-meadow region: 40 birds, no falcon or rival, one field at
    /// (1024, 500, r160, richness 90), one roost at (1024, 1100, r160), and a
    /// solo target of 5 (mirrors `Resources/Content/solo/tutorial-meadow.json`,
    /// which unit tests cannot load from the app bundle).
    private func makeMeadowState() -> GameState {
        GameState(
            birdCount: 40,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [90],
            fieldRadius: [160],
            fieldCenterX: [1024],
            fieldCenterY: [500],
            roostCount: 1,
            roostCenterX: [1024],
            roostCenterY: [1100],
            roostRadius: [160],
            falconCount: 0,
            hasRival: false,
            soloTargetBirds: 5,
            windSeedOffset: 12,
            seed: 7
        )
    }

    private static let tutorialSteps: [TutorialStep] = [
        .init(id: "draw", title: "Draw a path", body: "…",
              goal: .drawPath(minPoints: 8)),
        .init(id: "feed", title: "Feed the flock", body: "…",
              goal: .feed(minEnergyGain: 150)),
        .init(id: "split", title: "Split the flock", body: "…",
              goal: .splitFlock(subFlocks: 2)),
        .init(id: "condense", title: "Condense", body: "…",
              goal: .condense),
        .init(id: "roost", title: "Roost the flock", body: "…",
              goal: .roostTarget),
    ]

    /// The driver drives the exact pipeline GameModel runs (issue the step's
    /// action, tick, then sample) — so if the tutorial cannot complete within
    /// one day, this fails headlessly instead of waiting on a 10-minute UI run.
    func testDriverCompletesTheFullTutorialWithinOneDay() {
        var state = makeMeadowState()
        var engine = TutorialEngine(steps: Self.tutorialSteps)
        var driver = TutorialDriver()
        var rng = SeededRNG(seed: 7)

        var stall: String = "the day ended before the tutorial completed"
        for tick in 1...4800 {
            if let step = engine.currentStep,
               let action = driver.action(goal: step.goal, state: state) {
                state = applyAction(action, to: state).0
            }
            let (next, events) = applyTick(to: state, rng: &rng)
            state = next
            if engine.progress(state: state) {
                if engine.isComplete {
                    XCTAssertLessThanOrEqual(
                        state.tick, GameState.duskStart + 900,
                        "the tutorial should complete shortly after dusk"
                    )
                    return
                }
                stall = "advanced past step \(engine.stepIndex - 1) at tick \(tick)"
            }
            let dayOver = events.contains { event in
                if case .dayEnd = event { return true }
                if case .roost(let roostEvent) = event {
                    if case .dayEnd = roostEvent { return true }
                    if case .soloDayEnd = roostEvent { return true }
                }
                return false
            }
            if dayOver {
                stall += "; the day ended at tick \(state.tick) on step \(engine.stepIndex)"
                break
            }
        }
        XCTFail(stall)
    }
}
