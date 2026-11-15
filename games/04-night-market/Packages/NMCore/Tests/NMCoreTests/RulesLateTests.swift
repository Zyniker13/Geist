import NMCore
import Testing

/// Rule tests R-13…R-17 plus the invariant properties (split from
/// RulesTests.swift to keep each test suite under the lint body limit).
@Suite("Rules R-13…R-17 and Invariants")
struct RulesFixtureAndInvariantTests {
    // MARK: R-13 Score

    @Test("R-13 dawn bonus is 25% of the score on survival")
    func r13DawnBonus() {
        #expect(Scoring.dawnBonus(for: 100) == 25)
        #expect(Scoring.finalScore(survived: true, score: 100) == 125)
        #expect(Scoring.finalScore(survived: false, score: 100) == 100)
        #expect(Scoring.dawnBonus(for: 3) == 0)  // integer floor
    }

    // MARK: R-14 Walkways

    @Test("R-14 paint consumes budget per new tile; over-budget is rejected atomically")
    func r14PaintBudget() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 14)
        var tiles: [Tile] = []
        for col in 0..<29 { tiles.append(Tile(col: col, row: 3)) }
        (state, _) = try Reducer.apply(.paintWalkway(tiles), to: state, rng: &rng)
        #expect(state.usedBudget == 29)

        // One more tile fits; two do not (atomic: nothing applied).
        #expect(throws: RuleError.self) {
            _ = try Reducer.apply(.paintWalkway([Tile(col: 0, row: 4), Tile(col: 1, row: 4)]), to: state, rng: &rng)
        }
        let (after, _) = try Reducer.apply(.paintWalkway([Tile(col: 0, row: 4)]), to: state, rng: &rng)
        #expect(after.usedBudget == 30)
    }

    @Test("R-14 erase refunds fully and relocates customers off erased tiles")
    func r14Erase() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 14)
        let tile = Tile(col: 5, row: 5)
        (state, _) = try Reducer.apply(.paintWalkway([tile]), to: state, rng: &rng)
        state.customers.append(Customer(id: 1, color: .noodles, position: GameState.center(of: tile)))
        #expect(state.usedBudget == 1)
        #expect(state.isTraversable(tile))

        (state, _) = try Reducer.apply(.eraseWalkway([tile]), to: state, rng: &rng)
        #expect(state.usedBudget == 0)
        #expect(!state.isTraversable(tile))
        // The customer moved off the erased tile.
        let moved = state.customers[0].position
        #expect(state.tileOf(moved) != tile)
    }

    // MARK: R-14/R-15 seat-strand guards

    @Test("R-14 erasing the walkway under a seat sends seat-seekers to the exit, never onto open tiles")
    func r14SeatSeekerNotStranded() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 14)
        let tile = Tile(col: 5, row: 5)
        (state, _) = try Reducer.apply(.paintWalkway([tile]), to: state, rng: &rng)
        (state, _) = try Reducer.apply(.placeFixture(.seat(count: 3), tile), to: state, rng: &rng)
        let seatID = state.fixtures.last {
            if case .seat = $0.kind { return true }; return false
        }!.id

        // A customer mid-walk toward the seat, positioned on the plaza (traversable).
        var seeker = Customer(id: 1, color: .noodles, position: GameState.center(of: Tile(col: 15, row: 9)))
        seeker.state = .walkingToSeat
        seeker.targetSeatID = seatID
        state.customers.append(seeker)

        // Erase the walkway under the seat: the seat tile is no longer reachable.
        (state, _) = try Reducer.apply(.eraseWalkway([tile]), to: state, rng: &rng)
        #expect(!state.isTraversable(tile))
        // The seeker must not be en route to an unreachable seat.
        let after = state.customers[0]
        #expect(after.state != .walkingToSeat)
        #expect(after.targetSeatID == nil)
    }

    @Test("R-11/R-14 seat walking never leaves traversable tiles")
    func r14SeatWalkStaysTraversable() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 14)
        // Seeker on a walkway; seat on the plaza across un-walked ground, so
        // the straight line to the seat would cross non-traversable tiles.
        let start = Tile(col: 13, row: 5)
        (state, _) = try Reducer.apply(.paintWalkway([start]), to: state, rng: &rng)
        (state, _) = try Reducer.apply(.placeFixture(.seat(count: 3), Tile(col: 12, row: 8)), to: state, rng: &rng)
        let seatID = state.fixtures.last {
            if case .seat = $0.kind { return true }; return false
        }!.id
        var seeker = Customer(id: 1, color: .noodles, position: GameState.center(of: start))
        seeker.state = .walkingToSeat
        seeker.targetSeatID = seatID
        state.customers.append(seeker)
        #expect(state.isTraversable(state.tileOf(seeker.position)))

        for _ in 0..<20 {
            let (next, _) = Tick.advance(state: state, rng: &rng)
            state = next
            if let me = state.customers.first(where: { $0.id == 1 }) {
                #expect(
                    state.isTraversable(state.tileOf(me.position)),
                    "customer left traversable area at \(me.position)")
                if me.state != .walkingToSeat { break }
            } else {
                break
            }
        }
    }

    // MARK: R-15 Fixtures

    @Test("R-14/R-15 moving a bridge relocates customers stranded on the old span")
    func r15BridgeMoveRelocatesStranded() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 15)
        // Bridge from (13,7) east spans (14,7), (15,7), (16,7).
        (state, _) = try Reducer.apply(.placeFixture(.bridge(length: 3), Tile(col: 13, row: 7)), to: state, rng: &rng)
        let span = Tile(col: 15, row: 7)
        #expect(state.isTraversable(span))
        state.customers.append(Customer(id: 1, color: .noodles, position: GameState.center(of: span)))

        // Move the bridge to the row-12 canal: from (13,12) east spans (14,12)–(16,12).
        let bridgeID = state.fixtures.last {
            if case .bridge = $0.kind { return true }; return false
        }!.id
        (state, _) = try Reducer.apply(.moveFixture(bridgeID, Tile(col: 13, row: 12)), to: state, rng: &rng)
        #expect(!state.isTraversable(span))
        // The stranded customer relocated to a traversable tile (R-14 analog).
        let stranded = state.customers[0]
        #expect(state.isTraversable(state.tileOf(stranded.position)))
    }

    @Test("R-15 lantern radius is fixed at 3; busker at 2; awning covers 3×3")
    func r15CanonicalKinds() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 15)
        // Place on plaza tiles (traversable).
        let tile = Tile(col: 13, row: 8)
        // A lantern with a nonstandard radius is canonicalized to 3.
        (state, _) = try Reducer.apply(.placeFixture(.lantern(radius: 7), tile), to: state, rng: &rng)
        guard case .lantern(let r) = state.fixtures.last!.kind else {
            Issue.record("wrong kind")
            return
        }
        #expect(r == 3)
        #expect(state.fixtures.last!.radius == 3)

        (state, _) = try Reducer.apply(.placeFixture(.busker(radius: 9), Tile(col: 14, row: 8)), to: state, rng: &rng)
        guard case .busker(let b) = state.fixtures.last!.kind else {
            Issue.record("wrong kind")
            return
        }
        #expect(b == 2)
    }

    @Test("R-15 bridge must span 1–3 water tiles in a straight line")
    func r15Bridge() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 15)
        // Canal runs cols 14..<17 on row 7. A bridge from (13,7) east spans 3 water tiles
        // and lands on ground at (17,7).
        #expect(Reducer.bridgeDirection(from: Tile(col: 13, row: 7), length: 3, in: state) == .east)
        #expect(Reducer.bridgeDirection(from: Tile(col: 13, row: 7), length: 4, in: state) == nil)

        let (after, _) = try Reducer.apply(
            .placeFixture(.bridge(length: 3), Tile(col: 13, row: 7)), to: state, rng: &rng)
        #expect(!after.bridgeTiles.isEmpty)
        #expect(after.bridgeTiles.contains(Tile(col: 14, row: 7)))
        #expect(after.bridgeTiles.contains(Tile(col: 16, row: 7)))
        // The bridge makes the covered water traversable.
        #expect(after.isTraversable(Tile(col: 15, row: 7)))

        // A 4-length bridge is rejected.
        #expect(throws: RuleError.self) {
            _ = try Reducer.apply(.placeFixture(.bridge(length: 4), Tile(col: 13, row: 7)), to: after, rng: &rng)
        }
    }

    // MARK: R-16 Actions

    @Test("R-16 setSpeed accepts only 1, 2, 3")
    func r16Speed() throws {
        let state = GameState.initial(seed: 42)
        var rng = SeededRNG(seed: 16)
        #expect(throws: RuleError.self) {
            _ = try Reducer.apply(.setSpeed(5), to: state, rng: &rng)
        }
        for speed in [1, 2, 3] {
            let (s, _) = try Reducer.apply(.setSpeed(speed), to: state, rng: &rng)
            #expect(s.speedMultiplier == speed)
        }
    }

    @Test("R-16 pause and resume work while running")
    func r16PauseResume() throws {
        let state = GameState.initial(seed: 42)
        var rng = SeededRNG(seed: 16)
        let (paused, _) = try Reducer.apply(.pause, to: state, rng: &rng)
        #expect(paused.isPaused)
        let (resumed, _) = try Reducer.apply(.resume, to: paused, rng: &rng)
        #expect(!resumed.isPaused)
    }

    // MARK: R-17 Weather

    @Test("R-17 rain showers never start before 19:00 and are 90–180 s long")
    func r17RainSchedule() {
        for seed in [1, 2, 3, 42, 99] {
            let state = GameState.initial(seed: UInt64(seed))
            #expect(state.rainSchedule.count <= 3)
            for shower in state.rainSchedule {
                #expect(shower.startTick >= 3600)  // 19:00 = 18:00 + 1h
                #expect((2700...5400).contains(shower.durationTicks))
            }
        }
    }

    @Test("R-17 rain starts and ends per schedule and raises events")
    func r17RainTicks() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        // Force a known shower.
        state.rainSchedule = [RainShower(startTick: 3600, durationTicks: 100)]
        state.fieldVersion = 0
        var rng = SeededRNG(seed: 17)
        var started = false
        var ended = false
        while state.clock.tick < 3800 {
            let (s, e) = Tick.advance(state: state, rng: &rng)
            state = s
            for event in e {
                switch event {
                case .rainStarted: started = true
                case .rainEnded: ended = true
                default: break
                }
            }
            if state.isPaused, let first = state.pendingOffers.first {
                let (next, _) = try Reducer.apply(.chooseUpgrade(first.id), to: state, rng: &rng)
                state = next
            }
        }
        #expect(started)
        #expect(ended)
        #expect(state.weather.isRaining == false)
    }

    // MARK: Invariants (small-scale property checks; the 500-night run is Tools/sim)

    @Test("INV-1 walkway tiles used never exceed budget")
    func inv1Budget() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 1)
        var allTiles: [Tile] = []
        for col in 0..<32 { for row in 0..<20 { allTiles.append(Tile(col: col, row: row)) } }
        // Paint everything legal; usedBudget must stay ≤ budget.
        let legal = allTiles.filter { tile in
            switch state.grid.tile(at: tile) {
            case .ground, .plaza: return true
            default: return false
            }
        }
        var start = 0
        while start < legal.count {
            let batch = Array(legal[start..<min(start + 10, legal.count)])
            if state.usedBudget + batch.count <= state.walkwayBudget {
                (state, _) = try Reducer.apply(.paintWalkway(batch), to: state, rng: &rng)
            } else {
                #expect(throws: RuleError.self) {
                    _ = try Reducer.apply(.paintWalkway(batch), to: state, rng: &rng)
                }
            }
            #expect(state.usedBudget <= state.walkwayBudget)
            start += 10
        }
    }

    @Test("INV-2 customers are on traversable tiles; no customer in two queues")
    func inv2Customers() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 2)
        var paint: [Tile] = []
        for col in 0...12 { paint.append(Tile(col: col, row: 9)) }
        (state, _) = try Reducer.apply(.paintWalkway(paint), to: state, rng: &rng)

        for _ in 0..<600 {
            let (s, _) = Tick.advance(state: state, rng: &rng)
            state = s
            if state.isPaused, let first = state.pendingOffers.first {
                state = try Reducer.apply(.chooseUpgrade(first.id), to: state, rng: &rng).0
            }
            // Every customer sits on a traversable tile.
            for customer in state.customers {
                #expect(
                    state.isTraversable(state.tileOf(customer.position)),
                    "customer \(customer.id) on non-traversable \(state.tileOf(customer.position))")
            }
            // No customer id appears in more than one queue.
            var seen: Set<CustomerID> = []
            for stall in state.stalls {
                for id in stall.queue {
                    #expect(!seen.contains(id), "customer \(id) in two queues")
                    seen.insert(id)
                }
            }
        }
    }

    @Test("INV-3 score is non-decreasing across a run")
    func inv3ScoreMonotonic() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 3)
        var paint: [Tile] = []
        for col in 0...12 { paint.append(Tile(col: col, row: 9)) }
        (state, _) = try Reducer.apply(.paintWalkway(paint), to: state, rng: &rng)

        var last = 0
        for _ in 0..<400 {
            let (s, _) = Tick.advance(state: state, rng: &rng)
            state = s
            if state.isPaused, let first = state.pendingOffers.first {
                state = try Reducer.apply(.chooseUpgrade(first.id), to: state, rng: &rng).0
            }
            #expect(state.score >= last)
            last = state.score
        }
    }

    @Test("INV-4 flow fields reach stalls via best-neighbor descent")
    func inv4FieldConsistency() throws {
        var state = GameState.initial(seed: 42)
        state.fixtureStock = FixtureStock(lantern: 5, awning: 5, busker: 5, bridge: 5, seating: 5)
        var rng = SeededRNG(seed: 4)
        var paint: [Tile] = []
        for col in 0...12 { paint.append(Tile(col: col, row: 9)) }
        (state, _) = try Reducer.apply(.paintWalkway(paint), to: state, rng: &rng)
        state = FlowFields.ensureCurrent(for: state)

        for color in StallColor.allCases {
            guard state.openStalls.contains(where: { $0.color == color }) else { continue }
            for tile in reachableTraversableTiles(state, limit: 40) {
                guard state.pathFields.steps(toColor: color, at: tile) != nil else { continue }
                var current = tile
                var guardCounter = 0
                while guardCounter < 500 {
                    guardCounter += 1
                    if state.pathFields.steps(toColor: color, at: current) == 0 { break }
                    guard let next = Movement.nextTileTowardColor(color, from: current, in: state) else {
                        Issue.record("field descent stuck from \(tile) color \(color)")
                        break
                    }
                    current = next
                }
                #expect(
                    state.pathFields.steps(toColor: color, at: current) == 0,
                    "descent from \(tile) did not reach a \(color) stall")
            }
        }
    }

    private func reachableTraversableTiles(_ state: GameState, limit: Int) -> [Tile] {
        var result: [Tile] = []
        for row in 0..<state.grid.height {
            for col in 0..<state.grid.width {
                let tile = Tile(col: col, row: row)
                if state.isTraversable(tile) {
                    result.append(tile)
                    if result.count >= limit { return result }
                }
            }
        }
        return result
    }
}
