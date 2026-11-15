/// NMMetaTests — tests for meta types.
import Testing
@testable import NMMeta

@Suite("Meta Tests")
struct MetaTests {
    @Test("telemetry event is creatable")
    func eventCreation() {
        let event = TelemetryEvent(kind: .stepCost(durationMs: 10), tick: 0, extra: [:])
        #expect(event.tick == 0)
        if case .stepCost(let ms) = event.kind {
            #expect(ms == 10)
        } else {
            #expect(Bool.false)
        }
    }
}
