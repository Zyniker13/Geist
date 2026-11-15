/// NMPlatformTests — tests for platform types.
import Testing
import Testing
@testable import NMPlatform

@Suite("Platform Tests")
struct NightPlatformTests {
    @Test("input event is creatable")
    func inputCreation() {
        let event = InputEvent.tap(col: 5, row: 10)
        switch event {
        case .tap(let col, let row):
            #expect(col == 5)
            #expect(row == 10)
        default:
            Issue.record("unreachable")
        }
    }
}
