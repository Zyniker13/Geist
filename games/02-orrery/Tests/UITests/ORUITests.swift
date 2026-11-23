import XCTest

/// ORUITests — P0 smoke: the app launches to the placeholder menu with the
/// title reachable. Full-game flows arrive in P2.
final class ORUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchShowsPlaceholderMenu() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["title"].label, "Orrery")
    }
}
