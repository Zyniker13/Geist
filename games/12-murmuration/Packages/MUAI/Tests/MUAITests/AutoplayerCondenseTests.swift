import XCTest
import MUCore
import MUContent
@testable import MUAI

/// Autoplayer condense scheduling (ADR-0030).
final class AutoplayerCondenseTests: XCTestCase {
    /// Asymmetric two-field, two-roost region. Field A (500, 480) is nearer
    /// the world center than field B (1560, 1060); roost A (400, 400) is
    /// nearer than roost B (1648, 1200).
    private func makeTestRegion(birdCount: Int = 1400) -> Region {
        Region(
            id: "test", name: "Test",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: birdCount, falconCount: 1, hasRival: true,
            rivalStartBirds: birdCount * 3 / 7,
            windSeedOffset: 0, seed: 7,
            roosts: [
                .init(x: 400, y: 400, radius: 120),
                .init(x: 1648, y: 1200, radius: 120),
            ],
            fields: [
                .init(x: 500, y: 480, radius: 128, richness: 60),
                .init(x: 1560, y: 1060, radius: 128, richness: 60),
            ],
            palette: .standard
        )
    }

    func testAutoplayerCondensesInsideRoost() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        state.tick = GameState.duskStart
        for i in 0..<state.birds.count {
            state.birds.posX[i] = 400
            state.birds.posY[i] = 400
        }
        _ = ai.action(for: state)  // issues the dusk path to the roost
        guard case .condense(let sf)? = ai.action(for: state) else {
            return XCTFail("expected a condense inside the roost")
        }
        XCTAssertEqual(sf, 0)
    }

    /// While the forage target holds steady the autoplayer keeps the
    /// flock condensed: a stretched cloud grazes fields it flies past,
    /// restarting their regrowth ramps and starving the flock (the day
    /// cloud measured ~1,000-unit spread without it). Condense is
    /// re-issued whenever its cooldown has lapsed and no path change is
    /// due, so it never delays steering (ADR-0030).
    func testAutoplayerCondensesWhileForageTargetHolds() {
        var state = makeTestRegion().makeGameState()
        var ai = Autoplayer()
        _ = ai.action(for: state)  // tick 0: path to field A
        state.tick = 1
        XCTAssertEqual(state.condenseActive, 0)
        XCTAssertEqual(state.condenseCooldown, 0)
        guard case .condense(let sf)? = ai.action(for: state) else {
            return XCTFail("expected a condense while the target holds")
        }
        XCTAssertEqual(sf, 0)
    }
}
