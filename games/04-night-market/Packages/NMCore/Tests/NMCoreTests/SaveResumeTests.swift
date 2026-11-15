import XCTest
@testable import NMCore

/// S2.4 save/resume: a Codable round-trip of the state and RNG must
/// reproduce the identical StateHash and continue identically.
final class SaveResumeTests: XCTestCase {
    /// Drives a state forward with a paint-heavy script so caches and
    /// customer positions are non-trivial before the round-trip.
    private func drivenState(seed: UInt64, ticks: Int) -> (GameState, SeededRNG) {
        var state = GameState.initial(seed: seed)
        var rng = SeededRNG(seed: seed &+ 1)
        var painted = 0
        for tick in 0..<ticks {
            if tick % 120 == 0, painted < 24 {
                let col = 1 + painted
                let tile = Tile(col: col, row: 9)
                if let (next, _) = try? Reducer.apply(.paintWalkway([tile]), to: state, rng: &rng) {
                    state = next
                    painted += 1
                }
            }
            let (next, _) = Tick.advance(state: state, rng: &rng)
            state = next
        }
        return (state, rng)
    }

    func testCodableRoundTripPreservesHashAndFuture() throws {
        let (state, rng) = drivenState(seed: 42, ticks: 1500)
        let hashBefore = StateHash.hexDigest(StateHash.digest(state))

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(StateHash.hexDigest(StateHash.digest(restored)), hashBefore)

        // RNG round-trip.
        let rngData = try JSONEncoder().encode(rng)
        let restoredRNG = try JSONDecoder().decode(SeededRNG.self, from: rngData)

        // The restored pair must produce the same future as the original.
        var a = state
        var aRng = rng
        var b = restored
        var bRng = restoredRNG
        for _ in 0..<600 {
            a = Tick.advance(state: a, rng: &aRng).0
            b = Tick.advance(state: b, rng: &bRng).0
        }
        XCTAssertEqual(
            StateHash.hexDigest(StateHash.digest(a)),
            StateHash.hexDigest(StateHash.digest(b))
        )
    }
}
