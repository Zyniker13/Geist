/// Customer movement along flow fields with density slowdown (R-8, R-11).
public enum Movement {
    /// Move all customers one step toward their target.
    public static func moveAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = FlowFields.ensureCurrent(for: state)
        var events: [Event] = []

        // Tile occupancy for the density slowdown (R-11).
        var occupancy: [Tile: Int] = [:]
        for customer in s.customers {
            occupancy[s.tileOf(customer.position), default: 0] += 1
        }

        for idx in s.customers.indices {
            var customer = s.customers[idx]
            let speed = Self.speed(for: customer, in: s, occupancy: occupancy)

            switch customer.state {
            case .atGateWaiting:
                // Try to find a reachable open stall of the customer's color (R-8).
                let tile = s.tileOf(customer.position)
                if s.pathFields.steps(toColor: customer.color, at: tile) != nil {
                    if let stall = s.openStalls.first(where: { $0.color == customer.color }) {
                        customer.state = .walkingToStall
                        customer.targetStall = stall.id
                        customer.waitAtGate = 0
                    }
                } else {
                    customer.waitAtGate += 1
                }

            case .walkingToStall:
                guard let stall = s.stall(id: customer.targetStall ?? -1), stall.isOpen else {
                    customer.state = .atGateWaiting
                    customer.targetStall = nil
                    break
                }
                let target = s.stallTile(stall)
                if customer.position.distanceSquared(to: target) <= 1024 * 1024 {
                    // Arrived at the stall tile: join the queue if there is room (R-12).
                    let capacity = queueCapacity(for: stall, in: s)
                    if stall.queue.count < capacity {
                        customer.state = .inQueue
                        if let i = s.stalls.firstIndex(where: { $0.id == stall.id }) {
                            s.stalls[i].queue.append(customer.id)
                        }
                    }
                    // Queue full: linger at the stall tile and retry next tick.
                } else if let next = nextTileTowardColor(customer.color, from: s.tileOf(customer.position), in: s) {
                    customer.position = moveToward(customer.position, GameState.center(of: next), speed: speed)
                } else {
                    // No path (field stale or edited): fall back to waiting at the gate.
                    customer.state = .atGateWaiting
                    customer.targetStall = nil
                }

            case .inQueue, .beingServed:
                // Service moves the customer onward when served.
                break

            case .walkingToSeat:
                if let seatID = customer.targetSeatID,
                    let fixture = s.fixtures.first(where: { $0.id == seatID })
                {
                    if !s.isTraversable(fixture.position) {
                        // The seat sits on a tile that is no longer reachable.
                        customer.state = .walkingToExit
                        customer.targetSeatID = nil
                    } else {
                        let seatPos = GameState.center(of: fixture.position)
                        if customer.position.distanceSquared(to: seatPos) <= 1024 * 1024 {
                            customer.state = .seated
                            customer.seatTimer = 300
                        } else {
                            let candidate = moveToward(customer.position, seatPos, speed: speed)
                            if s.isTraversable(s.tileOf(candidate)) {
                                customer.position = candidate
                            } else {
                                // Straight-line seat walking never leaves the
                                // traversable area; give the seat up instead.
                                customer.state = .walkingToExit
                                customer.targetSeatID = nil
                            }
                        }
                    }
                } else {
                    customer.state = .walkingToExit
                }

            case .seated:
                customer.seatTimer -= 1
                if customer.seatTimer <= 0 {
                    customer.targetSeatID = nil
                    customer.state = .walkingToExit
                }

            case .walkingToExit:
                if isAtAnyGate(customer.position, in: s) {
                    customer.state = .despawned
                } else if let next = nextTileTowardGate(from: s.tileOf(customer.position), in: s) {
                    customer.position = moveToward(customer.position, GameState.center(of: next), speed: speed)
                }

            case .walkingToGate, .despawned:
                break
            }

            s.customers[idx] = customer
        }

        // Despawn customers that reached a gate.
        let leaving = s.customers.filter { $0.state == .despawned }
        if !leaving.isEmpty {
            events.append(.customersLeft(leaving.count))
            s.customers.removeAll { $0.state == .despawned }
        }

        return (s, events)
    }

    /// Queue capacity: 6 plus the stall's upgrade bonus plus waiting gate
    /// customers attributed to this stall (R-12, ADR-0010); the small-queues
    /// modifier offsets the base.
    public static func queueCapacity(for stall: Stall, in state: GameState) -> Int {
        max(1, 6 + stall.queueCapacityBonus + state.queueCapacityMod + Overflow.attributedWaiting(for: stall, in: state))
    }

    /// Density slowdown (R-11): base 48 units/tick; on a tile with n customers,
    /// speed = base × (100 − 15 × (n − 1)) / 100, minimum 12. Integer math only.
    public static func speed(for customer: Customer, in state: GameState, occupancy: [Tile: Int]) -> Int32 {
        let tile = state.tileOf(customer.position)
        let n = occupancy[tile] ?? 1
        let scaled = 48 * (100 - 15 * (n - 1)) / 100
        return Int32(max(12, scaled))
    }

    /// The traversable neighbor tile with the lowest color-field distance.
    /// Returns nil when the customer's own tile is the destination-adjacent
    /// minimum (i.e. no neighbor improves the field).
    public static func nextTileTowardColor(_ color: StallColor, from tile: Tile, in state: GameState) -> Tile? {
        let current = state.pathFields.steps(toColor: color, at: tile) ?? Int.max
        var best: (Tile, Int)?
        tile.forEachNeighbor(in: state.grid) { candidate in
            guard state.isTraversable(candidate) else { return }
            let d = state.pathFields.steps(toColor: color, at: candidate) ?? Int.max
            if d < current && (best == nil || d < best!.1) {
                best = (candidate, d)
            }
        }
        return best?.0
    }

    /// The traversable neighbor tile with the lowest gate-field distance.
    public static func nextTileTowardGate(from tile: Tile, in state: GameState) -> Tile? {
        let current = state.pathFields.steps(toGateAt: tile) ?? Int.max
        var best: (Tile, Int)?
        tile.forEachNeighbor(in: state.grid) { candidate in
            guard state.isTraversable(candidate) else { return }
            let d = state.pathFields.steps(toGateAt: candidate) ?? Int.max
            if d < current && (best == nil || d < best!.1) {
                best = (candidate, d)
            }
        }
        return best?.0
    }

    private static func isAtAnyGate(_ position: FixedPoint2, in state: GameState) -> Bool {
        state.openGates.contains { gate in state.gateTile(gate).distanceSquared(to: position) <= 1024 * 1024 }
    }

    /// Move `position` toward `target` by at most `speed` units (integer math).
    public static func moveToward(_ position: FixedPoint2, _ target: FixedPoint2, speed: Int32) -> FixedPoint2 {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distSq = Int64(dx) * Int64(dx) + Int64(dy) * Int64(dy)
        if distSq == 0 { return position }
        let dist = integerSqrt(distSq)
        let move = Int64(speed)
        if dist <= move { return target }
        return FixedPoint2(
            x: position.x + Int32((Int64(dx) * move) / dist),
            y: position.y + Int32((Int64(dy) * move) / dist)
        )
    }

    /// Exact-enough integer square root (Newton), deterministic everywhere.
    private static func integerSqrt(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        var x: Int64 = value
        var y: Int64 = (x + 1) / 2
        while y < x {
            x = y
            y = (x + value / x) / 2
        }
        return x
    }
}
