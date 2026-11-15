import Testing
@testable import NMCore

/// G5: the challenge system (NM-P5.2). Seeds must be identical across
/// devices for the same UTC date/week, draws must be deterministic, and all
/// twelve modifiers must change exactly the state they claim to.
struct ChallengesTests {
    // MARK: - Seed determinism (G5 check: 30 dates / 8 weeks)

    @Test("daily seeds are identical functions of the UTC date, 30 dates")
    func dailyDeterministic() {
        var first: [UInt64] = []
        for day in 1...30 {
            let date = String(format: "2026-11-%02d", day)
            first.append(Challenge.dailySeed(yyyymmddUTC: date))
        }
        for _ in 0..<2 {
            var again: [UInt64] = []
            for day in 1...30 {
                again.append(Challenge.dailySeed(yyyymmddUTC: String(format: "2026-11-%02d", day)))
            }
            #expect(again == first)
        }
        // Distinct dates map to distinct seeds.
        #expect(Set(first).count == 30)
    }

    @Test("weekly seeds are identical functions of the ISO week, 8 weeks")
    func weeklyDeterministic() {
        var first: [UInt64] = []
        for week in 40...47 {
            first.append(Challenge.weeklySeed(isoWeekUTC: "2026-W\(week)"))
        }
        for _ in 0..<2 {
            var again: [UInt64] = []
            for week in 40...47 {
                again.append(Challenge.weeklySeed(isoWeekUTC: "2026-W\(week)"))
            }
            #expect(again == first)
        }
        #expect(Set(first).count == 8)
    }

    // MARK: - Draw determinism

    @Test("same seed draws the same map, schedule, and modifier")
    func drawDeterministic() {
        let maps = ["taipei", "bangkok", "marrakesh", "istanbul", "oaxaca", "seoul"]
        let schedules = ["schedule_standard", "schedule_festival", "schedule_monsoon"]
        let first = Challenge.draw(seed: 99, mapIds: maps, scheduleIds: schedules)
        for _ in 0..<3 {
            let again = Challenge.draw(seed: 99, mapIds: maps, scheduleIds: schedules)
            #expect(again.mapId == first.mapId)
            #expect(again.scheduleId == first.scheduleId)
            #expect(again.modifier == first.modifier)
        }
        // Different seeds draw different combos at least once in 20 tries.
        var distinct = false
        for seed in 0..<20 {
            let other = Challenge.draw(seed: UInt64(seed), mapIds: maps, scheduleIds: schedules)
            if other.mapId != first.mapId || other.scheduleId != first.scheduleId
                || other.modifier != first.modifier {
                distinct = true
            }
        }
        #expect(distinct)
    }

    @Test("draw only ever picks listed ids and a real modifier")
    func drawWithinCatalog() {
        let maps = ["taipei", "seoul"]
        let schedules = ["schedule_standard"]
        for seed: UInt64 in 0..<50 {
            let draw = Challenge.draw(seed: seed, mapIds: maps, scheduleIds: schedules)
            #expect(maps.contains(draw.mapId))
            #expect(schedules.contains(draw.scheduleId))
            #expect(ChallengeModifier.allCases.contains(draw.modifier))
        }
    }

    @Test("draw falls back to defaults on empty catalogs")
    func drawFallbacks() {
        let draw = Challenge.draw(seed: 1, mapIds: [], scheduleIds: [])
        #expect(draw.mapId == "taipei")
        #expect(draw.scheduleId == "schedule_standard")
        #expect(ChallengeModifier.allCases.contains(draw.modifier))
    }

    @Test("every modifier has a stable, nonempty title")
    func titles() {
        #expect(ChallengeModifier.allCases.count == 12)
        for modifier in ChallengeModifier.allCases {
            #expect(!modifier.title.isEmpty)
        }
    }

    // MARK: - Modifier effects

    private func apply(_ modifier: ChallengeModifier, seed: UInt64 = 42) throws -> GameState {
        let base = try GameState.initial(seed: seed)
        var modified = base
        modifier.apply(to: &modified)
        return modified
    }

    @Test("tightBudget sets the start budget to 20; generousBudget to 50")
    func budgetModifiers() throws {
        #expect(try apply(.tightBudget).walkwayBudget == 20)
        #expect(try apply(.generousBudget).walkwayBudget == 50)
    }

    @Test("rushHour raises every hourly spawn rate by 25%")
    func rushHour() throws {
        let base = try GameState.initial(seed: 42)
        let modified = try apply(.rushHour)
        for (original, raised) in zip(base.spawnRates, modified.spawnRates) {
            #expect(raised == max(1, original * 5 / 4))
        }
    }

    @Test("slowCookers adds 30 ticks of service time to every stall")
    func slowCookers() throws {
        let base = try GameState.initial(seed: 42)
        let modified = try apply(.slowCookers)
        for (original, slowed) in zip(base.stalls, modified.stalls) {
            #expect(slowed.serviceTicks == original.serviceTicks + 30)
        }
    }

    @Test("twoGatesOnly keeps the first two gates and closes the rest")
    func twoGatesOnly() throws {
        let modified = try apply(.twoGatesOnly)
        for (index, gate) in modified.gates.enumerated() {
            if index < 2 {
                #expect(gate.isOpen || gate.opensAtTick != nil)
            } else {
                #expect(!gate.isOpen)
                #expect(gate.opensAtTick == nil)
            }
        }
    }

    @Test("lateGates pushes every opening to 00:00 or later")
    func lateGates() throws {
        let modified = try apply(.lateGates)
        for gate in modified.gates {
            if let open = gate.opensAtTick {
                #expect(open >= 7200)
            }
        }
    }

    @Test("everyoneWantsTea weights tea at six and leaves others at default")
    func everyoneWantsTea() throws {
        let modified = try apply(.everyoneWantsTea)
        #expect(modified.zoneWeights["tea"] == 6)
        #expect(modified.zoneWeights.count == 1)
    }

    @Test("smallQueues lowers queue capacity by two")
    func smallQueues() throws {
        let base = try GameState.initial(seed: 42)
        let modified = try apply(.smallQueues)
        #expect(modified.queueCapacityMod == -2)
        let stall = modified.stalls[0]
        #expect(
            Movement.queueCapacity(for: stall, in: modified)
                == max(1, Movement.queueCapacity(for: base.stalls[0], in: base) - 2)
        )
    }

    @Test("earlyClose ends the night at 03:00")
    func earlyClose() throws {
        let modified = try apply(.earlyClose)
        #expect(modified.clock.nightHours == 9)
        var mid = modified
        mid.clock.tick = modified.clock.ticksPerHour * 9 - 1
        #expect(!mid.clock.isNightOver)
        mid.clock.tick = modified.clock.ticksPerHour * 9
        #expect(mid.clock.isNightOver)
    }

    @Test("rainAllNight schedules one shower spanning the whole night")
    func rainAllNight() throws {
        let modified = try apply(.rainAllNight)
        #expect(modified.rainSchedule.count == 1)
        let shower = modified.rainSchedule[0]
        #expect(shower.startTick == 0)
        #expect(shower.durationTicks == modified.clock.ticksPerHour * 12)
    }

    @Test("doubleServes doubles the score per served customer")
    func doubleServes() async throws {
        var state = try GameState.initial(seed: 42, modifiers: [.doubleServes])
        #expect(state.scorePerServe == 2)
        let stall = state.stalls[0]
        state.stalls[0].queue = [CustomerID(1)]
        state.stalls[0].isOpen = true
        state.stalls[0].serviceProgress = stall.serviceTicks
        var rng = SeededRNG(seed: 3)
        let (next, events) = try Tick.advance(state: state, rng: &rng)
        #expect(events.contains(.served(CustomerID(1), stall.color)))
        #expect(next.score == 2)
    }

    @Test("lanternsCostDouble charges two tokens for one lantern")
    func lanternsCostDouble() throws {
        var state = GameState.initial(seed: 42, modifiers: [.lanternsCostDouble])
        state.fixtureStock.lantern = 3
        // Plaza tiles are traversable (RulesLateTests places seats there).
        var rng = SeededRNG(seed: 5)
        let (next, _) = try Reducer.apply(
            .placeFixture(.lantern(radius: 2), Tile(col: 12, row: 8)), to: state, rng: &rng
        )
        #expect(next.fixtureStock.lantern == 1)
        // With one token left, placing again is illegal under the modifier.
        do {
            _ = try Reducer.apply(
                .placeFixture(.lantern(radius: 2), Tile(col: 13, row: 8)), to: next, rng: &rng
            )
            Issue.record("placement with one token should have failed under the modifier")
        } catch {}
    }

    @Test("modifiers hash into the state digest")
    func modifiersHashed() throws {
        let base = try GameState.initial(seed: 42)
        let modified = try GameState.initial(seed: 42, modifiers: [.rushHour])
        #expect(StateHash.digest(base) != StateHash.digest(modified))
        let sameTwice = try GameState.initial(seed: 42, modifiers: [.rushHour])
        #expect(StateHash.digest(modified) == StateHash.digest(sameTwice))
    }

    @Test("initial with modifiers records them on the state")
    func modifiersRecorded() throws {
        let state = try GameState.initial(seed: 42, modifiers: [.tightBudget, .doubleServes])
        #expect(state.challengeModifiers == [.tightBudget, .doubleServes])
        #expect(state.walkwayBudget == 20)
        #expect(state.scorePerServe == 2)
    }
}
