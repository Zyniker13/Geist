/// NMAI: customer behavior, stall management.
/// Depends on NMCore + NMContent.
import Foundation
import NMCore
import NMContent

// MARK: - AI Types

/// Customer behavior parameters (tunable).
public struct CustomerBehavior: Codable, Sendable, Equatable, Hashable {
    public var patience: Int  // ticks before leaving
    public var speed: Int  // movement speed multiplier
    public var queueTolerance: Int  // max queue length before turning away

    public static let `default` = CustomerBehavior(patience: 600, speed: 1, queueTolerance: 8)
}

/// Stall management strategy.
public struct StallStrategy: Codable, Sendable, Equatable, Hashable {
    public var maxQueue: Int
    public var serviceSpeed: Int  // base service ticks
    public var overflowGrace: Int  // ticks before overflow penalty

    public static let `default` = StallStrategy(maxQueue: 6, serviceSpeed: 90, overflowGrace: 100)
}
