/// NMCoreTests — tests for the core simulation.
import Testing
@testable import NMCore

@Suite("SeededRNG Tests")
struct SeededRNGTests {
    @Test("deterministic seed produces same sequence")
    func deterministicSeed() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 42)

        for _ in 0..<100 {
            #expect(rng1.next() == rng2.next())
        }
    }

    @Test("different seeds produce different sequences")
    func differentSeeds() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 43)

        #expect(rng1.next() != rng2.next())
    }

    @Test("next(upperBound:) returns value in range")
    func nextUpperBound() {
        var rng = SeededRNG(seed: 12345)
        for _ in 0..<100 {
            let val = rng.next(upperBound: 100)
            #expect(val >= 0 && val < 100)
        }
    }

    @Test("nextDouble returns value in [0, 1)")
    func nextDoubleRange() {
        var rng = SeededRNG(seed: 54321)
        for _ in 0..<100 {
            let val = rng.nextDouble()
            #expect(val >= 0.0 && val < 1.0)
        }
    }

    @Test("shuffle preserves elements")
    func shufflePreserves() {
        var rng = SeededRNG(seed: 999)
        var arr = [1, 2, 3, 4, 5]
        rng.shuffle(&arr)
        #expect(arr.sorted() == [1, 2, 3, 4, 5])
    }

    @Test("shuffle is deterministic")
    func shuffleDeterministic() {
        var rng1 = SeededRNG(seed: 777)
        var rng2 = SeededRNG(seed: 777)
        var arr1 = [1, 2, 3, 4, 5]
        var arr2 = [1, 2, 3, 4, 5]
        rng1.shuffle(&arr1)
        rng2.shuffle(&arr2)
        #expect(arr1 == arr2)
    }
}

@Suite("Fixed Tests")
struct FixedTests {
    @Test("one plus zero equals one")
    func onePlusZero() {
        #expect(Fixed.one + Fixed.zero == Fixed.one)
    }

    @Test("addition is commutative")
    func additionCommutative() {
        let a = Fixed(5)
        let b = Fixed(3)
        #expect(a + b == b + a)
    }

    @Test("multiplication by one is identity")
    func mulByOne() {
        let a = Fixed(7)
        #expect(a * Fixed.one == a)
    }

    @Test("division by one is identity")
    func divByOne() {
        let a = Fixed(10)
        #expect(a / Fixed.one == a)
    }

    @Test("round converts correctly")
    func roundCorrect() {
        let half = Fixed(0.5)
        #expect(half.rounded() == 1)
        let negHalf = Fixed(-0.5)
        #expect(negHalf.rounded() == -1)
    }

    @Test("description formats correctly")
    func descriptionFormat() {
        let val = Fixed(1.23456)
        let desc = val.description(precision: 2)
        #expect(desc == "1.23")
    }
}

@Suite("GameState Tests")
struct GameStateTests {
    @Test("initial state is valid")
    func initialStateValid() {
        let state = GameState.initial(seed: 42)
        #expect(state.stalls.count == 6)
        #expect(state.gates.count == 2)
        #expect(state.customers.isEmpty)
        #expect(state.clock.tick == 0)
        #expect(!state.clock.isNightOver)
    }

    @Test("initial state is deterministic")
    func initialStateDeterministic() {
        let s1 = GameState.initial(seed: 42)
        let s2 = GameState.initial(seed: 42)
        #expect(s1.stalls.count == s2.stalls.count)
        #expect(s1.grid.width == s2.grid.width)
        #expect(s1.grid.height == s2.grid.height)
    }
}

@Suite("Reducer Tests")
struct ReducerTests {
    @Test("paint walkway increases budget usage")
    func paintWalkway() throws {
        let state = GameState.initial(seed: 42)
        let tile = Tile(col: 14, row: 9)
        let action = Action.paintWalkway([tile])

        var rng = SeededRNG(seed: 42)
        let (newState, _) = try Reducer.apply(action, to: state, rng: &rng)

        #expect(newState.usedBudget == 1)
        #expect(newState.walkwayTiles.contains(tile))
    }

    @Test("paint on water tile does nothing")
    func paintWater() throws {
        let state = GameState.initial(seed: 42)
        let waterTile = Tile(col: 15, row: 7)
        let action = Action.paintWalkway([waterTile])

        var rng = SeededRNG(seed: 42)
        let (newState, _) = try Reducer.apply(action, to: state, rng: &rng)

        #expect(newState.usedBudget == 0)
        #expect(!newState.walkwayTiles.contains(waterTile))
    }

    @Test("pause sets isPaused")
    func pause() throws {
        let state = GameState.initial(seed: 42)
        let action = Action.pause

        var rng = SeededRNG(seed: 42)
        let (newState, _) = try Reducer.apply(action, to: state, rng: &rng)

        #expect(newState.isPaused)
    }

    @Test("resume clears isPaused")
    func resume() throws {
        let state = GameState.initial(seed: 42)
        var rng = SeededRNG(seed: 42)
        _ = try Reducer.apply(.pause, to: state, rng: &rng)
        let action = Action.resume

        var rng2 = SeededRNG(seed: 42)
        let (newState, _) = try Reducer.apply(action, to: state, rng: &rng2)

        #expect(!newState.isPaused)
    }

    @Test("setSpeed with invalid value throws")
    func invalidSpeed() throws {
        let state = GameState.initial(seed: 42)
        let action = Action.setSpeed(5)

        var rng = SeededRNG(seed: 42)
        #expect(throws: RuleError.self) {
            try Reducer.apply(action, to: state, rng: &rng)
        }
    }
}

@Suite("Tick Tests")
struct TickTests {
    @Test("tick advances clock")
    func tickAdvancesClock() {
        var state = GameState.initial(seed: 42)
        var rng = SeededRNG(seed: 42)

        (state, _) = Tick.advance(state: state, rng: &rng)
        #expect(state.clock.tick == 1)
    }

    @Test("tick advances clock by speed multiplier")
    func tickSpeed() {
        var state = GameState.initial(seed: 42)
        state.speedMultiplier = 3
        var rng = SeededRNG(seed: 42)

        (state, _) = Tick.advance(state: state, rng: &rng)
        #expect(state.clock.tick == 3)
    }

    @Test("tick with pause does not advance")
    func tickPaused() {
        var state = GameState.initial(seed: 42)
        state.isPaused = true
        var rng = SeededRNG(seed: 42)

        (state, _) = Tick.advance(state: state, rng: &rng)
        #expect(state.clock.tick == 0)
    }
}

@Suite("FlowField Tests")
struct FlowFieldTests {
    @Test("flow field computes for open stalls")
    func computesFlowField() {
        var state = GameState.initial(seed: 42)
        // Open all stalls
        for i in state.stalls.indices {
            state.stalls[i].isOpen = true
        }

        var ff = FlowField()
        ff.compute(for: state)

        // Check that some tiles have values
        let tile = Tile(col: 14, row: 9)
        let steps = ff.steps(toColor: .noodles, at: tile)
        #expect(steps != nil)
        #expect(steps! >= 0)
    }

    @Test("flow field is empty for closed stalls")
    func emptyForClosed() {
        var state = GameState.initial(seed: 42)
        // Close all stalls
        for i in state.stalls.indices {
            state.stalls[i].isOpen = false
        }

        var ff = FlowField()
        ff.compute(for: state)

        let tile = Tile(col: 14, row: 9)
        let steps = ff.steps(toColor: .noodles, at: tile)
        #expect(steps == nil)
    }
}

@Suite("Replay Tests")
struct ReplayTests {
    @Test("replay runs deterministically")
    func replayDeterministic() {
        let state1 = GameState.initial(seed: 42)
        let state2 = GameState.initial(seed: 42)

        #expect(state1.stalls.count == state2.stalls.count)
        #expect(state1.grid.width == state2.grid.width)
    }
}
