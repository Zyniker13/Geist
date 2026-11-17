import XCTest
@testable import MUCore

// S1.4: committed golden replays for the real rules engine. Each record
// stores its seed, the content version it was recorded against, its timed
// actions, and the final state hash. A behavior-affecting engine change
// bumps GameState's default contentVersion and regenerates the goldens;
// a stale record fails loudly instead of replaying green.
final class EngineGoldenReplayTests: XCTestCase {
    private func loadEngineGoldens() throws -> [(url: URL, record: GameReplay)] {
        let urls = try Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "GoldenReplays") ?? []
        return try urls.compactMap { url in
            // trivial-golden-1.json is the P0 placeholder replay.
            guard url.lastPathComponent.hasPrefix("golden-") else { return nil }
            let data = try Data(contentsOf: url)
            return (url, try JSONDecoder().decode(GameReplay.self, from: data))
        }
    }

    func testAllTwentyEngineGoldensAreCommitted() throws {
        let goldens = try loadEngineGoldens()
        XCTAssertEqual(goldens.count, 20, "expected 20 engine golden replays, found \(goldens.count)")
    }

    func testCommittedGoldenReplaysReproduceStoredHashes() throws {
        let goldens = try loadEngineGoldens()
        for (url, record) in goldens {
            let state = try runReplay(record)
            XCTAssertEqual(
                stateHash(state), record.finalHash,
                "\(url.lastPathComponent) (seed \(record.seed)) diverged from its stored hash"
            )
        }
    }

    func testStaleContentVersionFailsLoudly() {
        var record = GameReplay(
            seed: 1, contentVersion: GameState.replayContentVersion - 1, birdCount: 50,
            worldWidth: 2048, worldHeight: 1536, actions: [], finalHash: 0
        )
        XCTAssertThrowsError(try runReplay(record)) { error in
            XCTAssertEqual(error as? ReplayError, .staleContentVersion(GameState.replayContentVersion - 1))
        }
        record = GameReplay(
            seed: 1, contentVersion: GameState.replayContentVersion, birdCount: 50,
            worldWidth: 2048, worldHeight: 1536, actions: [], finalHash: 0
        )
        XCTAssertNoThrow(try runReplay(record))
    }
}
