/// NMAudioTests — tests for audio types.
import Testing
@testable import NMAudio

@Suite("Audio Tests")
struct AudioTests {
    @Test("audio event is creatable")
    func eventCreation() {
        let event = AudioEvent(kind: .serve, volume: 0.5, pitch: 1.0)
        #expect(event.volume == 0.5)
        #expect(event.pitch == 1.0)
    }
}
