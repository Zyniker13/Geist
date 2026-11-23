/// ORMetaTests — meta package tests.
import Testing
@testable import ORMeta

@Test("package loads")
func packageLoads() {
    #expect(ORMetaInfo.name == "ORMeta")
}
