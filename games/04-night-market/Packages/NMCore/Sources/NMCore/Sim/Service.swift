/// Queue service and overflow logic (R-12).
public enum Service {
    /// Advance service timers for all stalls.
    public static func serviceAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = FlowFields.ensureCurrent(for: state)
        var events: [Event] = []

        for stallIdx in s.stalls.indices {
            var stall = s.stalls[stallIdx]
            guard stall.isOpen, !stall.queue.isEmpty else { continue }

            stall.serviceProgress += 1
            if stall.serviceProgress >= stall.serviceTicks {
                stall.serviceProgress = 0
                let servedID = stall.queue.removeFirst()
                events.append(.served(servedID, stall.color))
                s.score += 1  // R-13: score = customers served

                // Send the served customer to the nearest reachable free seat
                // within 8 path tiles, or straight to the exit (R-8).
                if let idx = s.customers.firstIndex(where: { $0.id == servedID }) {
                    if let seat = nearestFreeSeat(for: s.customers[idx], in: s, withinPathTiles: 8) {
                        s.customers[idx].state = .walkingToSeat
                        s.customers[idx].targetSeatID = seat
                    } else {
                        s.customers[idx].state = .walkingToExit
                    }
                }
            }

            s.stalls[stallIdx] = stall
        }

        return (s, events)
    }

    /// Nearest free seat fixture within `withinPathTiles` path steps (R-8).
    ///
    /// Path distance is approximated with the gate-field-independent manhattan
    /// path metric over traversable tiles: BFS from the customer's tile bounded
    /// by the radius. A seat is free when no seated customer claims it.
    static func nearestFreeSeat(for customer: Customer, in state: GameState, withinPathTiles: Int) -> Int? {
        var claimed: Set<Int> = []
        for other in state.customers where other.state == .seated || other.state == .walkingToSeat {
            if let seat = other.targetSeatID { claimed.insert(seat) }
        }

        // BFS bounded depth over traversable tiles from the customer's tile.
        let start = state.tileOf(customer.position)
        var visited: Set<Tile> = [start]
        var frontier = [start]
        var best: (fixtureID: Int, distance: Int)?

        for depth in 0...withinPathTiles {
            var nextFrontier: [Tile] = []
            for tile in frontier {
                if depth > 0,
                    let fixture = state.fixtures.first(where: {
                        $0.position == tile && isSeat($0.kind) && !claimed.contains($0.id)
                    })
                {
                    if best == nil || depth < best!.distance {
                        best = (fixture.id, depth)
                    }
                }
                tile.forEachNeighbor(in: state.grid) { neighbor in
                    if state.isTraversable(neighbor) && !visited.contains(neighbor) {
                        visited.insert(neighbor)
                        nextFrontier.append(neighbor)
                    }
                }
            }
            frontier = nextFrontier
            if best != nil { break }
        }
        return best?.fixtureID
    }

    private static func isSeat(_ kind: FixtureKind) -> Bool {
        if case .seat = kind { return true }
        return false
    }
}

/// Overflow checking (R-12).
public enum Overflow {
    /// Waiting gate customers attributed to a stall (R-9): every customer
    /// waiting at a gate counts toward its color's nearest open stall.
    public static func attributedWaiting(for stall: Stall, in state: GameState) -> Int {
        var count = 0
        for customer in state.customers where customer.state == .atGateWaiting {
            guard let nearest = nearestOpenStall(of: customer.color, at: customer.position, in: state) else { continue }
            if nearest.id == stall.id { count += 1 }
        }
        return count
    }

    /// Nearest open stall of a color from a position, manhattan in sub-tile
    /// units with a deterministic stall-id tie-break (R-9 attribution).
    public static func nearestOpenStall(of color: StallColor, at position: FixedPoint2, in state: GameState) -> Stall? {
        var best: (stall: Stall, distance: Int64)?
        for stall in state.openStalls where stall.color == color {
            let target = state.stallTile(stall)
            let distance = position.distanceSquared(to: target)
            if best == nil || distance < best!.distance || (distance == best!.distance && stall.id < best!.stall.id) {
                best = (stall, distance)
            }
        }
        return best?.stall
    }

    /// Check all stalls for overflow conditions.
    public static func checkAll(state: GameState, rng: inout SeededRNG) -> (GameState, [Event]) {
        var s = state
        var events: [Event] = []

        for idx in s.stalls.indices {
            var stall = s.stalls[idx]
            guard stall.isOpen else { continue }

            let capacity = 6 + attributedWaiting(for: stall, in: s)
            if stall.queue.count > capacity {
                stall.overflowTimer += 1
                events.append(.overflowWarning(stall.id, progress: stall.overflowTimer))
            } else {
                stall.overflowTimer = 0  // resets when back under capacity
            }

            s.stalls[idx] = stall
        }

        // Timer ≥ 600 ticks (20 s) ends the night (R-12).
        if let overflowing = s.stalls.first(where: { $0.isOpen && $0.overflowTimer >= 600 }) {
            _ = overflowing
            events.append(.nightEnded(score: s.score, survived: false))
        }

        return (s, events)
    }
}
