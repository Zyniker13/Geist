import XCTest

/// ORUITestsMac — P0 smoke for the macOS shell (TCC-limited locally; runs in CI).
final class ORUITestsMac: XCTestCase {
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
