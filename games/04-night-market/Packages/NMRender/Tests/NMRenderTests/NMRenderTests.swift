/// NMRenderTests — tests for render types.
import Testing
@testable import NMRender

@Suite("Render Tests")
struct RenderTests {
    @Test("viewport defaults")
    func viewportDefaults() {
        let vp = Viewport()
        #expect(vp.tileWidth == 32)
        #expect(vp.tileHeight == 32)
        #expect(vp.offsetX == 0)
        #expect(vp.offsetY == 0)
    }
}
