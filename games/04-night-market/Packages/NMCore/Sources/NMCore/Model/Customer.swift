/// A customer in the simulation.
public struct Customer: Codable, Sendable, Equatable, Hashable {
    public let id: CustomerID
    public let color: StallColor
    public var position: FixedPoint2
    public var state: CustomerState
    public var targetStall: Int?  // stall ID
    public var targetSeatID: Int?  // fixture ID of the claimed seat
    public var waitAtGate: Int = 0
    public var seatTimer: Int = 0

    public init(id: CustomerID, color: StallColor, position: FixedPoint2) {
        self.id = id
        self.color = color
        self.position = position
        self.state = .atGateWaiting
        self.targetStall = nil
        self.targetSeatID = nil
    }
}

/// Customer lifecycle state.
public enum CustomerState: Codable, Sendable, Equatable, Hashable {
    case walkingToGate
    case atGateWaiting
    case walkingToStall
    case inQueue
    case beingServed
    case walkingToSeat
    case seated
    case walkingToExit
    case despawned
}
