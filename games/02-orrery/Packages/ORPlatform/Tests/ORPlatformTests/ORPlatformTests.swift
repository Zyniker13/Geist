/// ORPlatformTests — platform package tests.
import Testing
@testable import ORPlatform

@Test("package loads")
func packageLoads() {
    #expect(ORPlatformInfo.name == "ORPlatform")
}
