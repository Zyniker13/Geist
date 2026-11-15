/// Customer movement with density slowdown.
public enum Movement {
    /// Move all customers one step toward their target.
    public static func moveAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        let baseSpeed: Int32 = 48  // units per tick

        for idx in s.customers.indices {
            var customer = s.customers[idx]

            switch customer.state {
            case .atGateWaiting:
                // Try to find a stall
                if let stall = findNearestStall(of: customer.color, in: s, from: customer.position) {
                    customer.state = .walkingToStall
                    customer.targetStall = stall.id
                }

            case .walkingToStall:
                let stall = s.stalls.first(where: { $0.id == customer.targetStall })
                if let stall, stall.isOpen {
                    let stallPos = FixedPoint2(x: Int32(stall.position.col) * 1024, y: Int32(stall.position.row) * 1024)
                    let dist = customer.position.distanceSquared(to: stallPos)
                    if dist <= 1024 * 1024 {  // reached stall
                        customer.state = .inQueue
                        if let i = s.stalls.firstIndex(where: { $0.id == stall.id }) {
                            s.stalls[i].queue.append(customer.id)
                        }
                    } else {
                        customer.position = moveOneStep(customer, toward: stallPos, speed: baseSpeed)
                    }
                } else {
                    customer.state = .atGateWaiting
                    customer.targetStall = nil
                }

            case .inQueue, .beingServed:
                break

            case .walkingToSeat:
                if let seatPos = findNearestSeat(in: s, from: customer.position) {
                    let dist = customer.position.distanceSquared(to: seatPos)
                    if dist <= 1024 * 1024 {
                        customer.state = .seated
                        customer.seatTimer = 300
                    } else {
                        customer.position = moveOneStep(customer, toward: seatPos, speed: baseSpeed)
                    }
                } else {
                    customer.state = .walkingToExit
                }

            case .seated:
                customer.seatTimer -= 1
                if customer.seatTimer <= 0 {
                    customer.state = .walkingToExit
                }

            case .walkingToExit:
                if let gate = s.gates.first(where: { $0.isOpen }) {
                    let gatePos = FixedPoint2(x: Int32(gate.position.col) * 1024, y: Int32(gate.position.row) * 1024)
                    let dist = customer.position.distanceSquared(to: gatePos)
                    if dist <= 1024 * 1024 {
                        customer.state = .despawned
                    } else {
                        customer.position = moveOneStep(customer, toward: gatePos, speed: baseSpeed)
                    }
                }

            case .walkingToGate, .despawned:
                break
            }

            s.customers[idx] = customer
        }

        // Clean up despawned customers
        s.customers.removeAll { $0.state == .despawned }

        return (s, [])
    }

    private static func moveOneStep(_ customer: Customer, toward: FixedPoint2, speed: Int32) -> FixedPoint2 {
        let dx = toward.x - customer.position.x
        let dy = toward.y - customer.position.y
        let dist = Double(dx * dx + dy * dy).squareRoot()
        guard dist > 0 else { return customer.position }

        let moveAmount = min(speed, Int32(dist))
        return FixedPoint2(
            x: customer.position.x + Int32(Double(dx) * Double(moveAmount) / dist),
            y: customer.position.y + Int32(Double(dy) * Double(moveAmount) / dist)
        )
    }

    private static func findNearestStall(of color: StallColor, in state: GameState, from pos: FixedPoint2) -> Stall? {
        state.stalls
            .filter { $0.isOpen && $0.color == color }
            .min { s1, s2 in
                let p1 = FixedPoint2(x: Int32(s1.position.col) * 1024, y: Int32(s1.position.row) * 1024)
                let p2 = FixedPoint2(x: Int32(s2.position.col) * 1024, y: Int32(s2.position.row) * 1024)
                let d1 = pos.distanceSquared(to: p1)
                let d2 = pos.distanceSquared(to: p2)
                return d1 < d2
            }
    }

    private static func findNearestSeat(in state: GameState, from pos: FixedPoint2) -> FixedPoint2? {
        let seats = state.fixtures
            .compactMap { fixture -> FixedPoint2? in
                guard case .seat = fixture.kind else { return nil }
                return FixedPoint2(x: Int32(fixture.position.col) * 1024, y: Int32(fixture.position.row) * 1024)
            }
        return seats.min(by: { a, b in
            a.distanceSquared(to: pos) < b.distanceSquared(to: pos)
        })
    }
}

// Helper extension
private extension Array where Element == Stall {
    mutating func idx(for id: Int, transform: (inout Element) -> Void) {
        if let i = firstIndex(where: { $0.id == id }) {
            transform(&self[i])
        }
    }
}
