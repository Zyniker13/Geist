/// ReplayTests — S0.6: the golden-replay contract on the trivial state.
import Testing
import Foundation
@testable import ORCore

@Suite("Replay Tests")
struct ReplayTests {
    @Test("empty replay hashes the initial state")
    func emptyReplay() {
        let replay = Replay(seed: 1)
        let result = Replay.run(replay)
        #expect(result.finalState.count == 0)
        #expect(result.applied == 0)
        #expect(result.skipped == 0)
        #expect(result.finalHash == TrivialState().canonicalHash())
    }

    @Test("same replay runs to the same hash twice (determinism)")
    func deterministicRerun() {
        let actions = (0..<50).map { Replay.TimedAction(tick: $0 * 3, action: .bump) }
        let replay = Replay(seed: 77, actions: actions)
        let a = Replay.run(replay)
        let b = Replay.run(replay)
        #expect(a == b)
        #expect(a.finalHash == b.finalHash)
    }

    @Test("actions are applied in canonical order regardless of input order")
    func canonicalOrdering() {
        var actions = [
            Replay.TimedAction(tick: 30, action: .bump),
            Replay.TimedAction(tick: 10, action: .bump),
            Replay.TimedAction(tick: 20, action: .bump),
        ]
        actions.shuffle()
        let shuffled = Replay(seed: 5, actions: actions)
        let sortedInput = Replay(seed: 5, actions: actions.sorted { $0.tick < $1.tick })
        #expect(Replay.run(shuffled) == Replay.run(sortedInput))
        #expect(Replay.run(shuffled).finalState.count == 3)
    }

    @Test("negative bumps are skipped, not applied")
    func illegalActionsSkipped() {
        let replay = Replay(
            seed: 9,
            actions: [
                Replay.TimedAction(tick: 1, action: .bumps(-3)),
                Replay.TimedAction(tick: 2, action: .bump),
            ])
        let result = Replay.run(replay)
        #expect(result.applied == 1)
        #expect(result.skipped == 1)
        #expect(result.finalState.count == 1)
    }

    @Test("golden replay runs twice and matches its committed expectations")
    func goldenReplayFile() throws {
        guard
            let url = Bundle.module.url(
                forResource: "trivial-golden-1", withExtension: "json", subdirectory: "GoldenReplays")
        else {
            Issue.record("golden replay resource missing from the bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let golden = try JSONDecoder().decode(GoldenReplay.self, from: data)
        let replay = Replay(seed: golden.seed, contentVersion: golden.contentVersion, actions: golden.actions)
        let a = Replay.run(replay)
        let b = Replay.run(replay)
        #expect(a.finalHash == b.finalHash, "two runs of the same replay must agree")
        #expect(a.finalHash == golden.expectedHash, "final hash must match the committed expectation")
        #expect(a.applied == golden.expectedApplied)
        #expect(a.skipped == golden.expectedSkipped)
    }
}

/// Committed golden-replay expectation file shape.
struct GoldenReplay: Codable {
    let name: String
    let seed: UInt64
    let contentVersion: String
    let actions: [Replay.TimedAction]
    let expectedHash: UInt64
    let expectedApplied: Int
    let expectedSkipped: Int
}
