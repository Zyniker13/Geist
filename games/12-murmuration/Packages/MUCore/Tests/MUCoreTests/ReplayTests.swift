import XCTest
@testable import MUCore

final class ReplayTests: XCTestCase {
    func testReplayIsDeterministic() {
        let record = Replay(
            seed: 42,
            contentVersion: 1,
            actions: [
                TimedAction(tick: 0, action: .increment(5)),
                TimedAction(tick: 1, action: .mix(0xA5A5A5A5A5A5A5A5)),
                TimedAction(tick: 2, action: .increment(2)),
                TimedAction(tick: 3, action: .mix(1)),
            ]
        )
        let first = replay(record)
        let second = replay(record)
        XCTAssertEqual(first, second)
        XCTAssertEqual(stateHash(first), stateHash(second))
    }

    func testGoldenReplayMatchesCommittedHash() throws {
        let url = Bundle.module.url(
            forResource: "trivial-golden-1", withExtension: "json",
            subdirectory: "GoldenReplays"
        )
        let data = try Data(contentsOf: XCTUnwrap(url, "golden replay file missing"))
        let record = try JSONDecoder().decode(Replay.self, from: data)
        let final = replay(record)
        let hash = stateHash(final)

        // The committed hash lives in the file as a sibling metadata record.
        struct GoldenFile: Codable { let seed: UInt64; let contentVersion: Int; let actions: [TimedAction]; let expectedHash: UInt64 }
        let golden = try JSONDecoder().decode(GoldenFile.self, from: data)
        XCTAssertEqual(golden.seed, record.seed)
        XCTAssertEqual(hash, golden.expectedHash, "replayed hash diverged from the committed golden")
    }

    func testStateChangesOnlyThroughActions() {
        var state = TrivialState(seed: 9)
        let before = stateHash(state)
        // Applying no actions leaves the state untouched.
        XCTAssertEqual(replay(Replay(seed: 9, contentVersion: 1, actions: [])), TrivialState(seed: 9))
        state = TrivialReducer.apply(.increment(3), to: state).0
        XCTAssertNotEqual(before, stateHash(state))
    }
}
