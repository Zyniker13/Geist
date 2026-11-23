/// ORAITests — AI package tests.
import Testing
@testable import ORAI

@Test("package loads")
func packageLoads() {
    #expect(ORAIInfo.name == "ORAI")
}
