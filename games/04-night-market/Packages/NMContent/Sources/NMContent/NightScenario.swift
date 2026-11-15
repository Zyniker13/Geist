/// Scripted night scenarios: the deterministic challenge source for the
/// slice (P2 S2.3) and the stress profile used by performance checks.
///
/// A scenario pins the parts of a night that R-3 otherwise seeds randomly
/// (the rain schedule). Spawn pressure itself comes from the rulebook's
/// hourly ramp (R-7); a scenario may only pin weather and timing so every
/// mode stays inside the rules engine's contract.
import Foundation
import NMCore

public struct NightScenario: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    /// Fixed rain showers; empty means a clear night.
    public let rain: [RainShower]

    public init(id: String, name: String, rain: [RainShower]) {
        self.id = id
        self.name = name
        self.rain = rain
    }

    /// The P2 slice night: one shower at 20:00 for 450 in-game seconds.
    public static let taipeiSlice = NightScenario(
        id: "taipei-slice",
        name: "Taipei slice",
        rain: [RainShower(startTick: 3600, durationTicks: 1350)]
    )

    /// A clear night for tests and the perf harness.
    public static let clear = NightScenario(id: "clear", name: "Clear night", rain: [])

    /// Builds initial-state overrides for this scenario.
    public var overrides: GameStateOverrides {
        GameStateOverrides(rainSchedule: rain)
    }
}
