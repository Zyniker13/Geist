import XCTest

/// P0 smoke: the app builds, installs, and launches on the iPad simulator.
final class NMUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists, "app should launch")
        app.terminate()
    }
}
