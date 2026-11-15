/// Golden replay regression tests (S1.4): committed scripted nights whose
/// final state hash and checkpoint hashes must stay byte-identical across
/// engine changes and platforms.
import Testing
import Foundation
@testable import NMCore

private struct Expectations: Codable {
    let finalHash: String
    let checkpoints: [String]
}

@Suite("Golden Replay Tests")
struct GoldenReplayTests {
    @Test("ten golden replays reproduce their committed hashes", arguments: 1...10)
    func goldenReplayHashes(index: Int) throws {
        let name = String(format: "golden-%02d", index)
        guard
            let replayURL = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "GoldenReplays"),
            let expectedURL = Bundle.module.url(
                forResource: "\(name).expected", withExtension: "json", subdirectory: "GoldenReplays")
        else {
            Issue.record("missing golden resources for \(name)")
            return
        }
        let replay = try JSONDecoder().decode(ReplayData.self, from: Data(contentsOf: replayURL))
        let expected = try JSONDecoder().decode(Expectations.self, from: Data(contentsOf: expectedURL))

        // Two runs must agree byte-for-byte (determinism).
        let first = Replay.run(replay)
        let second = Replay.run(replay)
        #expect(
            StateHash.hexDigest(StateHash.digest(first.finalState))
                == StateHash.hexDigest(StateHash.digest(second.finalState)))

        // And match the committed expectation.
        #expect(StateHash.hex(first.finalState) == expected.finalHash, "\(name) final hash drifted")
        let observed = first.checkpointHashes.map(StateHash.hexDigest)
        #expect(observed == expected.checkpoints, "\(name) checkpoint hashes drifted")
        #expect(first.actionsSkipped == 0, "\(name): replay actions must all apply")
    }
}
