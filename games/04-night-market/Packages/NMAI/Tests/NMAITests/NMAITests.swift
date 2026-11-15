/// NMAITests — tests for AI.
import Testing
@testable import NMAI

@Suite("AI Tests")
struct AITests {
    @Test("default behavior is reasonable")
    func defaultBehavior() {
        let b = CustomerBehavior.default
        #expect(b.patience > 0)
        #expect(b.speed > 0)
        #expect(b.queueTolerance > 0)
    }

    @Test("default strategy is reasonable")
    func defaultStrategy() {
        let s = StallStrategy.default
        #expect(s.maxQueue > 0)
        #expect(s.serviceSpeed > 0)
        #expect(s.overflowGrace > 0)
    }
}
