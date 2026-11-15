import XCTest
import NMCore
@testable import NMContent

final class NightScenarioTests: XCTestCase {
    func testTaipeiSlicePinsOneShower() throws {
        let state = GameState.initial(seed: 7, overrides: NightScenario.taipeiSlice.overrides)
        XCTAssertEqual(state.rainSchedule.count, 1)
        XCTAssertEqual(state.rainSchedule.first?.startTick, 3600)
        // A different seed must not change the pinned schedule.
        let other = GameState.initial(seed: 99, overrides: NightScenario.taipeiSlice.overrides)
        XCTAssertEqual(state.rainSchedule, other.rainSchedule)
    }

    func testClearScenarioHasNoRain() throws {
        let state = GameState.initial(seed: 3, overrides: NightScenario.clear.overrides)
        XCTAssertTrue(state.rainSchedule.isEmpty)
    }

    func testDefaultScenarioIsSeeded() throws {
        // Without a scenario the schedule stays seeded (R-17): different
        // seeds may differ, but the count is within 0...3.
        let a = GameState.initial(seed: 1)
        let b = GameState.initial(seed: 2)
        XCTAssertTrue((0...3).contains(a.rainSchedule.count))
        XCTAssertTrue((0...3).contains(b.rainSchedule.count))
    }
}
