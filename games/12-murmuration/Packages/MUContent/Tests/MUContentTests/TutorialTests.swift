import XCTest
import MUCore
@testable import MUContent

/// Tutorial engine and shipped P3.2 content tests (S3.2). The engine is
/// deterministic: it samples a `GameState` per frame and reports when the
/// current step's goal is met. The shipped-content tests load the real JSON
/// from `Resources/Content` so content and validation stay in lock-step.
final class TutorialTests: XCTestCase {
    /// Game root, derived from this source file's path.
    private var gameRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    // MARK: - Synthetic state builder

    private func makeState(birdCount: Int = 10, soloTargetBirds: Int = 0) -> GameState {
        GameState(
            birdCount: birdCount,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [10],
            fieldRadius: [128],
            fieldCenterX: [1024],
            fieldCenterY: [768],
            roostCount: 1,
            roostCenterX: [512],
            roostCenterY: [768],
            roostRadius: [128],
            falconCount: 0,
            hasRival: false,
            soloTargetBirds: soloTargetBirds,
            windSeedOffset: 0,
            seed: 42
        )
    }

    private func steps(_ goals: [TutorialGoal]) -> [TutorialStep] {
        goals.enumerated().map { index, goal in
            TutorialStep(id: "step-\(index)", title: "Step \(index)", body: "Body \(index)", goal: goal)
        }
    }

    // MARK: - Engine: per-step goals

    func testEngineStartsAtFirstStep() {
        let engine = TutorialEngine(steps: steps([.drawPath(minPoints: 8)]))
        XCTAssertFalse(engine.isComplete)
        XCTAssertEqual(engine.currentStep?.id, "step-0")
    }

    func testDrawPathStepCompletesAtMinPoints() {
        var engine = TutorialEngine(steps: steps([.drawPath(minPoints: 8)]))
        var state = makeState()
        state.leaderPaths = [LeaderPath(points: (0..<7).map { Waypoint(x: Int32($0), y: 0) })]
        XCTAssertFalse(engine.progress(state: state), "7 points < 8 must not complete")
        state.leaderPaths[0].points.append(Waypoint(x: 7, y: 0))
        XCTAssertTrue(engine.progress(state: state), "8 points must complete the step")
        XCTAssertTrue(engine.isComplete)
    }

    func testFeedStepCompletesOnEnergyGain() {
        var engine = TutorialEngine(steps: steps([.feed(minEnergyGain: 300)]))
        var state = makeState()
        state.energy = [100, 100]

        XCTAssertFalse(engine.progress(state: state), "first sample sets the baseline; no gain yet")
        state.energy = [100, 399]  // total 499 vs baseline 200: gain 299
        XCTAssertFalse(engine.progress(state: state), "gain 299 < 300 must not complete")
        state.energy = [100, 400]  // gain 300
        XCTAssertTrue(engine.progress(state: state), "gain 300 must complete the step")
    }

    func testFeedStepCountsGainAcrossGrowthDips() {
        // R-9 growth spends 200 energy whenever the total reaches 800, so the
        // total dips mid-step; gain must accumulate across the dips (a plain
        // total-vs-baseline comparison is unsatisfiable here).
        var engine = TutorialEngine(steps: steps([.feed(minEnergyGain: 150)]))
        var state = makeState()
        state.energy = [800, 0]  // total 800: baseline
        XCTAssertFalse(engine.progress(state: state))
        state.energy = [900, 0]  // +100
        XCTAssertFalse(engine.progress(state: state), "gain 100 < 150 must not complete")
        state.energy = [700, 0]  // growth spent 200: a dip, not negative gain
        XCTAssertFalse(engine.progress(state: state))
        state.energy = [850, 0]  // +150 more: cumulative 250
        XCTAssertTrue(engine.progress(state: state), "cumulative gain 250 >= 150 must complete")
    }

    func testSplitStepCompletesAtTwoSubFlocks() {
        var engine = TutorialEngine(steps: steps([.splitFlock(subFlocks: 2)]))
        var state = makeState()
        state.subFlockAssignments = [0, 0]
        XCTAssertFalse(engine.progress(state: state))
        state.subFlockAssignments = [0, 1]  // max assignment 1 -> two sub-flocks
        XCTAssertTrue(engine.progress(state: state))
    }

    func testCondenseStepCompletesWhenCooldownSet() {
        var engine = TutorialEngine(steps: steps([.condense]))
        var state = makeState()
        state.condenseCooldown = 0
        XCTAssertFalse(engine.progress(state: state))
        state.condenseCooldown = 30
        XCTAssertTrue(engine.progress(state: state))
    }

    func testRoostTargetStepCompletesAtTarget() {
        var engine = TutorialEngine(steps: steps([.roostTarget]))
        var state = makeState(birdCount: 3, soloTargetBirds: 3)
        // Two birds inside the roost radius, one far outside.
        state.birds.posX = [512, 512, 1900]
        state.birds.posY = [768, 768, 768]
        XCTAssertFalse(engine.progress(state: state), "2 settled < 3 must not complete")
        state.birds.posX[2] = 512
        XCTAssertTrue(engine.progress(state: state), "3 settled must complete the step")
    }

    func testRoostTargetStepNeverCompletesWithoutSoloTarget() {
        var engine = TutorialEngine(steps: steps([.roostTarget]))
        var state = makeState(birdCount: 3, soloTargetBirds: 0)
        state.birds.posX = [512, 512, 512]
        state.birds.posY = [768, 768, 768]
        XCTAssertFalse(engine.progress(state: state), "no solo target: the step cannot complete")
    }

    // MARK: - Engine: sequential progression

    func testStepsAdvanceSequentiallyToComplete() {
        let all = steps([
            .drawPath(minPoints: 2),
            .feed(minEnergyGain: 100),
            .splitFlock(subFlocks: 2),
            .condense,
            .roostTarget,
        ])
        var engine = TutorialEngine(steps: all)
        var state = makeState(birdCount: 3, soloTargetBirds: 3)
        state.birds.posX = [512, 512, 512]
        state.birds.posY = [768, 768, 768]

        // Step 0: draw a 2-point path.
        state.leaderPaths = [LeaderPath(points: [Waypoint(x: 0, y: 0), Waypoint(x: 1, y: 0)])]
        XCTAssertTrue(engine.progress(state: state))
        XCTAssertEqual(engine.currentStep?.id, "step-1")

        // Step 1: feed (baseline captured on first sample, then gain 100).
        state.energy = [0, 0]
        XCTAssertFalse(engine.progress(state: state))
        state.energy = [0, 100]
        XCTAssertTrue(engine.progress(state: state))
        XCTAssertEqual(engine.currentStep?.id, "step-2")

        // Step 2: split into two sub-flocks.
        state.subFlockAssignments = [0, 1]
        XCTAssertTrue(engine.progress(state: state))
        XCTAssertEqual(engine.currentStep?.id, "step-3")

        // Step 3: condense.
        state.condenseCooldown = 30
        XCTAssertTrue(engine.progress(state: state))
        XCTAssertEqual(engine.currentStep?.id, "step-4")

        // Step 4: roost the target.
        XCTAssertTrue(engine.progress(state: state))
        XCTAssertTrue(engine.isComplete)
        XCTAssertNil(engine.currentStep)
        XCTAssertFalse(engine.progress(state: state), "a completed tutorial reports no further progress")
    }

    // MARK: - Shipped content

    func testShippedTutorialContent() throws {
        let url = gameRoot.appendingPathComponent("Resources/Content/tutorial/tutorial.json")
        let tutorial = try Tutorial.load(from: url)
        XCTAssertEqual(tutorial.region, "tutorial-meadow")
        XCTAssertEqual(tutorial.steps.count, 5, "the tutorial is exactly five steps")
        let goals = tutorial.steps.map { step -> String in
            switch step.goal {
            case .drawPath: return "drawPath"
            case .feed: return "feed"
            case .splitFlock: return "splitFlock"
            case .condense: return "condense"
            case .roostTarget: return "roostTarget"
            }
        }
        XCTAssertEqual(goals, ["drawPath", "feed", "splitFlock", "condense", "roostTarget"])
        for step in tutorial.steps {
            XCTAssertFalse(step.title.isEmpty, "step \(step.id) needs a title")
            XCTAssertFalse(step.body.isEmpty, "step \(step.id) needs body text")
        }
    }

    func testShippedSoloRegions() throws {
        let dir = gameRoot.appendingPathComponent("Resources/Content/solo")
        let catalog = try RegionCatalog.load(from: dir)
        XCTAssertEqual(catalog.regions.count, 2, "two shipped solo regions")
        for region in catalog.regions {
            let issues = RegionCatalog.validate(region)
            XCTAssertTrue(issues.isEmpty, "\(region.id) must validate cleanly: \(issues)")
            XCTAssertFalse(region.hasRival, "\(region.id) is a solo region")
            XCTAssertGreaterThan(region.soloTargetBirds, 0, "\(region.id) needs a target")
        }
        let meadow = try XCTUnwrap(catalog.region(id: "tutorial-meadow"))
        XCTAssertEqual(meadow.falconCount, 0, "the tutorial meadow has no falcons")
        let firstRoost = try XCTUnwrap(catalog.region(id: "first-roost"))
        XCTAssertGreaterThanOrEqual(firstRoost.falconCount, 1, "first-roost keeps the falcon threat")
    }
}
