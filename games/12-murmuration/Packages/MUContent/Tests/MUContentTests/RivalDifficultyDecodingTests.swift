import XCTest
import MUCore
@testable import MUContent

/// MU-P4.1: every shipped region carries an explicit rival difficulty tier;
/// the tier decodes as a flat top-level key (ADR-0027), a pre-P4.1 file
/// without the key defaults to gentle, and an unknown tier fails decode.
final class RivalDifficultyDecodingTests: XCTestCase {
    /// Game root, derived from this source file's path.
    private var gameRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    private func decode(_ json: String) throws -> Region {
        try JSONDecoder().decode(Region.self, from: Data(json.utf8))
    }

    private func shippedJSON(_ name: String) throws -> String {
        try String(
            contentsOf: gameRoot.appendingPathComponent("Resources/Content/regions/\(name).json"),
            encoding: .utf8
        )
    }

    /// Replace the shipped tier (`nil` removes the key entirely).
    private func meadowVariant(tier: String?) throws -> String {
        var json = try shippedJSON("meadow")
        if let tier {
            json = json.replacingOccurrences(
                of: "\"rivalDifficulty\"\\s*:\\s*\"[a-z]+\"",
                with: "\"rivalDifficulty\": \"\(tier)\"",
                options: .regularExpression
            )
        } else {
            // The key is the final property; drop it and the preceding comma.
            json = json.replacingOccurrences(
                of: ",\\s*\"rivalDifficulty\"\\s*:\\s*\"[a-z]+\"",
                with: "",
                options: .regularExpression
            )
        }
        return json
    }

    func testShippedRegionsDecodeWithExpectedTier() throws {
        let expected: [String: RivalDifficulty] = [
            "meadow": RivalDifficulty.gentle,
            "ridge": .gentle,
            "fenlands": .normal,
            "gorge": .normal,
            "commons": .hard,
            "delta": .hard,
        ]
        for (name, tier) in expected {
            let region = try decode(try shippedJSON(name))
            XCTAssertEqual(region.rivalDifficulty, tier, "\(name) tier")
        }
    }

    func testExplicitTierDecodes() throws {
        let region = try decode(try meadowVariant(tier: "hard"))
        XCTAssertEqual(region.rivalDifficulty, .hard)
    }

    func testMissingKeyDefaultsToGentle() throws {
        let region = try decode(try meadowVariant(tier: nil))
        XCTAssertEqual(region.rivalDifficulty, .gentle)
    }

    func testUnknownTierFailsDecode() throws {
        XCTAssertThrowsError(try decode(try meadowVariant(tier: "nightmare")))
    }
}
