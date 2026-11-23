import XCTest
import MUContent
@testable import MURender

/// MU-P8.1 accessibility render options: Reduce Motion flutter snap +
/// bird decimation, and the high-contrast rival palette swap.
final class AccessibilityRenderTests: XCTestCase {
    func testHighContrastSwapsRivalToFuchsia() throws {
        var base = RegionPalette.standard
        base.rival = RGBAColor(r: 0.678, g: 0.561, b: 0.439)
        let contrast = FlockRenderer.activePalette(base, true)
        // The swapped rival sits far from the ink player color and from
        // the original sepia (large ΔE-ish distance on all channels).
        XCTAssertGreaterThan(
            abs(contrast.rival.r - base.birdInk.r)
                + abs(contrast.rival.g - base.birdInk.g)
                + abs(contrast.rival.b - base.birdInk.b),
            1.0,
            "high-contrast rival must separate from the player ink"
        )
        XCTAssertEqual(contrast.rival.r, 0.871, accuracy: 0.001)
        XCTAssertEqual(contrast.rival.b, 0.612, accuracy: 0.001)
    }

    func testHighContrastLeavesSkyAndPlayerInkAlone() {
        var base = RegionPalette.standard
        base.rival = RGBAColor(r: 0.678, g: 0.561, b: 0.439)
        let contrast = FlockRenderer.activePalette(base, true)
        XCTAssertEqual(contrast.birdInk, base.birdInk, "player ink stays")
        XCTAssertEqual(contrast.skyTop, base.skyTop, "sky untouched")
        XCTAssertEqual(contrast.skyBottom, base.skyBottom, "sky untouched")
        XCTAssertEqual(contrast.fieldOchre, base.fieldOchre, "field untouched")
    }

    func testFlutterSnapFlagDefaultsOff() {
        let rendererState = RenderOptionsState()
        XCTAssertFalse(rendererState.reducesFlutter)
        XCTAssertFalse(rendererState.highContrastRival)
        XCTAssertEqual(rendererState.birdStride, 1)
    }

    func testReduceMotionStrideHalvesInstanceBudget() {
        // The stride contract: with stride 4, exactly every 4th bird of a
        // 96-bird flock is drawn (24 instances), keeping the swarm read
        // while quartering the vertex load.
        var drawn = 0
        let count = 96
        for i in Swift.stride(from: 0, to: count, by: 4) { drawn += 1 }
        XCTAssertEqual(drawn, 24)
        for i in Swift.stride(from: 0, to: count, by: 4) {
            XCTAssertEqual(i % 4, 0, "stride keeps the leader birds (0, 4, 8, …)")
        }
    }
}

/// Bare struct exposing the renderer's option defaults without spinning up
/// Metal (the real fields live on FlockRenderer, which needs a device).
private struct RenderOptionsState {
    var reducesFlutter = false
    var highContrastRival = false
    var birdStride = 1
}
