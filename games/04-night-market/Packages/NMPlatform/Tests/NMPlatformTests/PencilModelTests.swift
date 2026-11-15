import Testing
import NMCore
@testable import NMPlatform

/// G7: Pencil input model (NM-P7.3) — tests run without hardware per §8.2.
struct PencilModelTests {
    @Test("squeeze toggles erase on and off")
    func squeezeToggle() {
        var model = PencilInputModel()
        #expect(!model.eraseArmed)
        #expect(model.squeeze() == true)
        #expect(model.eraseArmed)
        #expect(model.squeeze() == false)
        #expect(!model.eraseArmed)
    }

    @Test("the bridge type list compiles on every platform")
    func typesExist() {
        _ = PencilInputModel()
        #expect(PencilInputModel() == PencilInputModel())
    }
}
