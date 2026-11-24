/// Golden replay tests (S1.4): the ten committed full-game replays must
/// reproduce their committed final hashes exactly, twice per run, with
/// every action applied and none skipped.
import Testing
import Foundation
@testable import ORCore

@Suite("Game Golden Replay Tests")
struct GameGoldenReplayTests {

    @Test("all ten committed golden replays replay bit-exactly, twice")
    func goldenReplays() throws {
        for index in 1...10 {
            let name = String(format: "golden-%03d", index)
            guard
                let url = Bundle.module.url(
                    forResource: name, withExtension: "json", subdirectory: "GoldenReplays")
            else {
                Issue.record("\(name) missing from the bundle")
                continue
            }
            let data = try Data(contentsOf: url)
            let golden = try JSONDecoder().decode(GoldenGame.self, from: data)
            let replay = GameReplay(
                seed: golden.seed,
                variantID: "standard",
                actions: golden.actions)
            let a = GameReplay.run(replay)
            let b = GameReplay.run(replay)
            #expect(a.finalHash == b.finalHash, "\(name): two runs must agree")
            #expect(
                StateHash.hexDigest(a.finalHash) == golden.finalHash,
                "\(name): final hash must match the committed expectation")
            #expect(a.skipped == 0, "\(name): no action may be skipped")
            #expect(a.finalState.result != nil, "\(name): the game must have ended")
            if let winner = golden.winner {
                let actual = winnerName(a.finalState)
                #expect(actual == winner, "\(name): winner must match")
            }
            #expect(a.checkpointHashes.count == golden.plies / 2, "\(name): checkpoint cadence")
        }
    }

    private func winnerName(_ state: GameState) -> String {
        guard let result = state.result else { return "none" }
        switch result {
        case .won(let player, _), .timeout(let player, _):
            return player == .one ? "one" : "two"
        }
    }
}

/// The committed golden file shape (mirrors the sim tool's GameRecord).
struct GoldenGame: Codable {
    let seed: UInt64
    let actions: [GameReplay.TimedAction]
    let finalHash: String
    let winner: String?
    let reason: String
    let plies: Int
    let rounds: Int
}
