/// ORRenderTests — render package tests.
import Testing
@testable import ORRender

@Test("package loads")
func packageLoads() {
    #expect(ORRenderInfo.name == "ORRender")
}
