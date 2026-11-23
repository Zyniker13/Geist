/// ORAudioTests — audio package tests.
import Testing
@testable import ORAudio

@Test("package loads")
func packageLoads() {
    #expect(ORAudioInfo.name == "ORAudio")
}
