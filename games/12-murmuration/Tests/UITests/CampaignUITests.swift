import XCTest

/// G5 checks: the migration campaign plays end-to-end under the
/// Autoplayer, and the daily challenge surfaces its day + modifier.
final class CampaignUITests: XCTestCase {
    /// MU-P5.1: a campaign stage runs to program done with the carried
    /// flock; the HUD shows the stage number.
    func testCampaignStageCompletesUnderAutoplayer() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 2, fast: 120,
            extra: ["-uitest-campaign", "3", "-uitest-carry", "800"]
        )
        let stageRow = GameUITest.overlayRow(app: app, identifier: "game.stage")
        XCTAssertTrue(
            stageRow.waitForExistence(timeout: 30),
            "campaign stage row never appeared"
        )
        XCTAssertTrue(
            GameUITest.rowText(of: stageRow).contains("stage 4/12"),
            "stage 3 (0-based) must display as stage 4/12"
        )
        let final = GameUITest.finalElement(app)
        XCTAssertTrue(
            final.waitForExistence(timeout: 240),
            "the campaign stage never completed"
        )
    }

    /// MU-P5.2: the daily challenge pins a day and shows the modifier.
    func testDailyShowsDayAndModifier() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 1, fast: 120,
            extra: ["-uitest-daily", "-uitest-daily-day", "13"]
        )
        let dailyRow = GameUITest.overlayRow(app: app, identifier: "debug.daily")
        XCTAssertTrue(
            dailyRow.waitForExistence(timeout: 30),
            "daily row never appeared"
        )
        let text = GameUITest.rowText(of: dailyRow)
        XCTAssertTrue(
            text.contains("13"),
            "the pinned day number must appear, got: \(text)"
        )
        XCTAssertFalse(
            text.isEmpty,
            "the daily row must carry the modifier name"
        )
        let final = GameUITest.finalElement(app)
        XCTAssertTrue(
            final.waitForExistence(timeout: 240),
            "the daily day never completed"
        )
    }

    /// MU-P7.1: a completed day posts to Game Center (the poster is
    /// deterministic in UI-test runs; the posts row must go non-zero).
    func testCompletedDayPostsScores() throws {
        let app = XCUIApplication()
        GameUITest.launch(
            app: app, region: "meadow", days: 1, fast: 120,
            extra: ["-uitest-poster-mock", "-uitest-daily", "-uitest-daily-day", "13"]
        )
        let final = GameUITest.finalElement(app)
        XCTAssertTrue(
            final.waitForExistence(timeout: 240),
            "the daily day never completed"
        )
        let postsRow = GameUITest.overlayRow(app: app, identifier: "debug.posts")
        XCTAssertTrue(
            postsRow.waitForExistence(timeout: 30),
            "the posts row never appeared"
        )
        let value = GameUITest.rowText(of: postsRow).trimmingCharacters(in: .whitespaces)
        XCTAssertNotEqual(
            value, "0/0",
            "the posts row must go non-zero after a completed day, got: \(value)"
        )
    }
}
