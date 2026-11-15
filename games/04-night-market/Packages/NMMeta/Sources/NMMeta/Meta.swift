/// NMMeta: metadata, analytics, telemetry.
/// Depends on NMCore.
import Foundation

// MARK: - Meta Types

/// Game telemetry event.
public struct TelemetryEvent: Codable, Sendable, Equatable, Hashable {
    public let kind: TelemetryKind
    public let tick: Int
    public let extra: [String: String]

    public enum TelemetryKind: Codable, Sendable, Equatable, Hashable {
        case stepCost(durationMs: Int)
        case fps(durationMs: Int, frames: Int)
        case customerSpawn
        case customerServed
        case customerOverflow
        case actionApplied(String)
    }
}

/// Analytics provider protocol.
public protocol AnalyticsProvider: Sendable {
    func record(event: TelemetryEvent)
    func flush()
}
