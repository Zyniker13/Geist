/// ORContentTests — content package tests.
import Testing
@testable import ORContent

@Test("package loads")
func packageLoads() {
    #expect(ORContentInfo.name == "ORContent")
}
