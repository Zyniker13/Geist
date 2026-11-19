import Foundation
import MUCore

/// The goal a tutorial step waits for (P3.2, five-step tutorial).
///
/// Each goal is a pure predicate over a `GameState` sample; the engine
/// reports completion exactly once, on the frame the predicate first holds.
public enum TutorialGoal: Codable, Equatable, Sendable {
    /// Draw a leader path with at least `minPoints` waypoints (R-4).
    case drawPath(minPoints: Int)
    /// Feed the flock until total energy is at least `minEnergyGain` above
    /// the total at the step's first sample (R-5).
    case feed(minEnergyGain: Int)
    /// Split the flock into at least `subFlocks` sub-flocks (R-6).
    case splitFlock(subFlocks: Int)
    /// Trigger a condense (R-7); complete once the condense cooldown is set.
    case condense
    /// Roost the solo target (R-13 / P3.2); complete once the settled count
    /// meets `soloTargetBirds` (counted by `countSettledInRoosts`).
    case roostTarget

    private enum CodingKeys: String, CodingKey {
        case type, minPoints, minEnergyGain, subFlocks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "drawPath":
            self = .drawPath(minPoints: try c.decode(Int.self, forKey: .minPoints))
        case "feed":
            self = .feed(minEnergyGain: try c.decode(Int.self, forKey: .minEnergyGain))
        case "splitFlock":
            self = .splitFlock(subFlocks: try c.decode(Int.self, forKey: .subFlocks))
        case "condense":
            self = .condense
        case "roostTarget":
            self = .roostTarget
        default:
            throw DecodingError.keyNotFound(
                CodingKeys.type,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "unknown tutorial goal type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .drawPath(let minPoints):
            try c.encode("drawPath", forKey: .type)
            try c.encode(minPoints, forKey: .minPoints)
        case .feed(let minEnergyGain):
            try c.encode("feed", forKey: .type)
            try c.encode(minEnergyGain, forKey: .minEnergyGain)
        case .splitFlock(let subFlocks):
            try c.encode("splitFlock", forKey: .type)
            try c.encode(subFlocks, forKey: .subFlocks)
        case .condense:
            try c.encode("condense", forKey: .type)
        case .roostTarget:
            try c.encode("roostTarget", forKey: .type)
        }
    }
}

/// One step of the tutorial: its copy and the goal it waits for.
public struct TutorialStep: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let goal: TutorialGoal

    public init(id: String, title: String, body: String, goal: TutorialGoal) {
        self.id = id
        self.title = title
        self.body = body
        self.goal = goal
    }
}

/// The five-step tutorial (P3.2): the region it plays in and its steps in
/// order. Loaded from `Resources/Content/tutorial/tutorial.json`.
public struct Tutorial: Codable, Sendable {
    public let region: String
    public let steps: [TutorialStep]

    public init(region: String, steps: [TutorialStep]) {
        self.region = region
        self.steps = steps
    }

    public static func load(from url: URL) throws -> Tutorial {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Tutorial.self, from: data)
    }
}

/// Deterministic tutorial progression (P3.2). The UI samples the live
/// `GameState` once per frame and calls `progress`; it returns `true` exactly
/// once, on the frame the current step's goal is met, and advances to the
/// next step. All goals use integer math (INV-3) and the same observables as
/// the sim (e.g. `countSettledInRoosts` for the roost step).
public struct TutorialEngine: Equatable, Sendable {
    public private(set) var stepIndex: Int
    private let steps: [TutorialStep]
    /// Total energy at the previous feed sample (for delta accounting).
    private var lastFeedTotal: Int?
    /// Energy gained since the feed step's first sample, summed from
    /// positive deltas. Growth (R-9) spends 200 energy whenever the total
    /// reaches 800, and the 1000 cap bounds the total, so a plain
    /// total-vs-baseline comparison can be unsatisfiable; cumulative gain
    /// is the honest measure of "the flock fed".
    private var feedGain: Int

    public init(steps: [TutorialStep]) {
        precondition(!steps.isEmpty, "a tutorial needs at least one step")
        self.steps = steps
        self.stepIndex = 0
        self.lastFeedTotal = nil
        self.feedGain = 0
    }

    public var isComplete: Bool { stepIndex >= steps.count }

    public var currentStep: TutorialStep? {
        isComplete ? nil : steps[stepIndex]
    }

    /// Sample the sim state; returns `true` when the current step just
    /// completed (and the engine advanced). A completed tutorial returns
    /// `false` for every sample.
    public mutating func progress(state: GameState) -> Bool {
        guard let step = currentStep else { return false }
        let done: Bool
        switch step.goal {
        case .drawPath(let minPoints):
            done = state.leaderPaths.contains { $0.points.count >= minPoints }
        case .feed(let minEnergyGain):
            let total = state.energy.reduce(0, +)
            if let last = lastFeedTotal {
                let delta = total - last
                if delta > 0 { feedGain += delta }
            }
            lastFeedTotal = total
            done = feedGain >= minEnergyGain
        case .splitFlock(let subFlocks):
            done = state.subFlockCount >= subFlocks
        case .condense:
            done = state.condenseCooldown > 0 || state.condenseActive > 0
        case .roostTarget:
            done =
                state.soloTargetBirds > 0
                && countSettledInRoosts(state: state) >= state.soloTargetBirds
        }
        guard done else { return false }
        lastFeedTotal = nil
        feedGain = 0
        stepIndex += 1
        return true
    }
}

/// Errors thrown while loading the tutorial.
public enum TutorialError: Error, Equatable {
    case missingTutorial
}

extension Tutorial {
    /// Load the bundled tutorial (app layout: `Content/tutorial` directory,
    /// then `tutorial/`, then the bundle root).
    public static func loadBundled() throws -> Tutorial {
        guard
            let url = Bundle.main.url(
                forResource: "tutorial", withExtension: "json", subdirectory: "Content/tutorial"
            ) ?? Bundle.main.url(
                forResource: "tutorial", withExtension: "json", subdirectory: "tutorial"
            ) ?? Bundle.main.url(forResource: "tutorial", withExtension: "json")
        else {
            throw TutorialError.missingTutorial
        }
        return try load(from: url)
    }
}
