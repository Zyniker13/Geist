/// NMContentTests — tests for content.
import Testing
@testable import NMContent

@Suite("Content Tests")
struct ContentTests {
    @Test("content version initial is correct")
    func versionInitial() {
        let v = ContentVersion.initial
        #expect(v.major == 0)
        #expect(v.minor == 0)
        #expect(v.patch == 0)
    }
}
