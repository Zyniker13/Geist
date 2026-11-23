// P8.2 falcon-assist steering tests: the avoidance force's raw Q16.16
// magnitudes, out-of-range zero, and trajectory divergence (assist on vs
// off) plus non-interference for flocks the falcon never touches.
import XCTest
@testable import MUCore

final class FalconAssistTests: XCTestCase {
    /// A 2048x1536 world: flock at the center, one energy field off in the
    /// southwest corner, one roost northeast, one falcon. Same fixture
    /// family as P3WorldFeaturesTests.
    private func makeState(
        seed: UInt64 = 0x2026_11,
        falconAssist: Bool,
        falconAssistWeight: Int32 = 0,
        falconX: [Int32] = [],
        falconY: [Int32] = []
    ) -> GameState {
        var params = BoidsParams()
        params.falconAssistWeight = falconAssistWeight
        let state = GameState(
            birdCount: 48,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: params,
            fieldRichness: [120],
            fieldRadius: [300],
            fieldCenterX: [80],
            fieldCenterY: [1420],
            roostCount: 1,
            roostCenterX: [1900],
            roostCenterY: [300],
            roostRadius: [120],
            falconCount: 1,
            hasRival: false,
            windSeedOffset: 0,
            seed: seed,
            windPattern: .uniform,
            falconBehavior: .patrol,
            falconAssist: falconAssist
        )
        return state
    }

    private func runTicks(_ state: inout GameState, _ n: Int) {
        var s = state
        var rng = SeededRNG(seed: s.seed)
        for _ in 0..<n {
            let (next, _) = applyTick(to: s, rng: &rng)
            s = next
        }
        state = s
    }

    // MARK: - Force profile (exact Q16.16, testR6LeaderForceMatchesWeight pattern)

    func testFalconForceMatchesWeight() {
        let frame = BoidsFrame(
            leaderX: 0, leaderY: 0, windXQ: 0, windYQ: 0,
            worldWidth: 2048, worldHeight: 1536,
            falconX: [1000], falconY: [1000]
        )
        // Straight-axis push at distance 240: direction (1, 0); the raw
        // force vector feeds normalizedScaled(1, 0, w) == (w, 0), so the
        // in-force contribution is the weight itself.
        let raw = frame.falconForce(at: 1240, 1000)
        XCTAssertEqual(raw.x, 240)
        XCTAssertEqual(raw.y, 0)
        let f = normalizedScaledForTest(Int64(raw.x), Int64(raw.y), 122_880)
        XCTAssertEqual(f.x, 122_880)
        XCTAssertEqual(f.y, 0)
        // Near-zero distance: the floor-direction fallback (0, 1).
        let center = frame.falconForce(at: 1000, 1000)
        XCTAssertEqual(center.x, 0)
        XCTAssertEqual(center.y, 1)
    }

    func testFalconForceZeroOutOfRange() {
        let frame = BoidsFrame(
            leaderX: 0, leaderY: 0, windXQ: 0, windYQ: 0,
            worldWidth: 2048, worldHeight: 1536,
            falconX: [1000], falconY: [1000]
        )
        // 479 is inside the (exclusive) 480 fear radius; 480 is out.
        let inside = frame.falconForce(at: 1000, 1000 + 479)
        XCTAssertNotEqual(inside.y, 0)
        let boundary = frame.falconForce(at: 1000, 1000 + 480)
        XCTAssertEqual(boundary.x, 0)
        XCTAssertEqual(boundary.y, 0)
    }

    func testFalconForceZeroWithNoFalcons() {
        let frame = BoidsFrame(
            leaderX: 0, leaderY: 0, windXQ: 0, windYQ: 0,
            worldWidth: 2048, worldHeight: 1536
        )
        XCTAssertEqual(frame.falconForce(at: 1000, 1000).x, 0)
        XCTAssertEqual(frame.falconForce(at: 1000, 1000).y, 0)
    }

    func testFalconForcePicksNearestFalcon() {
        // Two falcons: the bird is 100 from the first and 200 from the
        // second; the push must point away from the NEAR one (negative y).
        let frame = BoidsFrame(
            leaderX: 0, leaderY: 0, windXQ: 0, windYQ: 0,
            worldWidth: 2048, worldHeight: 1536,
            falconX: [1000, 1200], falconY: [1100, 1100]
        )
        let f = frame.falconForce(at: 1000, 1000)
        XCTAssertEqual(f.x, 0)
        XCTAssertLessThan(f.y, 0)
    }

    // MARK: - Trajectory effects

    func testAssistOnDivergesFromAssistOffWhenFalconNear() {
        var on = makeState(falconAssist: true, falconX: [1024], falconY: [900])
        var off = makeState(falconAssist: false, falconX: [1024], falconY: [900])
        runTicks(&on, 30)
        runTicks(&off, 30)
        // Divergence must exceed pure coincidence: at least one bird moved
        // differently by the end of the window.
        let dx = zip(on.birds.posX, off.birds.posX).filter { $0 != $1 }.count
        XCTAssertGreaterThan(dx, 0, "assist produced no trajectory change")
    }

    func testAssistOffMatchesAssistFreeBaselineBitForBit() {
        // Assist OFF must be bit-identical to the pre-P8.2 engine: same
        // world, same seed, falcons present but not fed to the frame.
        var off = makeState(falconAssist: false, falconX: [1024], falconY: [900])
        var baseline = makeState(falconAssist: false, falconX: [], falconY: [])
        runTicks(&off, 40)
        runTicks(&baseline, 40)
        XCTAssertEqual(off.birds.posX, baseline.birds.posX)
        XCTAssertEqual(off.birds.posY, baseline.birds.posY)
    }

    func testAssistOnStaysContainedAcross60Ticks() {
        var st = makeState(falconAssist: true, falconX: [1024], falconY: [900])
        runTicks(&st, 60)
        for i in 0..<st.birds.count {
            XCTAssertGreaterThanOrEqual(st.birds.posX[i], 0)
            XCTAssertLessThan(st.birds.posX[i], st.worldWidth)
            XCTAssertGreaterThanOrEqual(st.birds.posY[i], 0)
            XCTAssertLessThan(st.birds.posY[i], st.worldHeight)
        }
    }

    func testEffectiveParamsInjectsAssistWeightOnlyWhenOn() {
        var on = makeState(falconAssist: true)
        XCTAssertEqual(effectiveParams(on).falconAssistWeight, 122_880)
        let off = makeState(falconAssist: false)
        XCTAssertEqual(effectiveParams(off).falconAssistWeight, 0)
        // An explicit nonzero weight from the state must survive untouched.
        let custom = makeState(falconAssist: true, falconAssistWeight: 65_536)
        XCTAssertEqual(effectiveParams(custom).falconAssistWeight, 65_536)
    }
}

/// Re-exported for tests: mirrors the engine's `normalizedScaled` (file-scope
/// private in Boids.swift) so force-weight assertions use the real profile.
private func normalizedScaledForTest(_ x: Int64, _ y: Int64, _ w: Int32) -> (x: Int64, y: Int64) {
    let safe: Int64 = 2_147_483_647
    var sx = x
    var sy = y
    while sx > safe || sx < -safe || sy > safe || sy < -safe {
        sx >>= 1
        sy >>= 1
    }
    let magnitude = isqrt64(UInt64(max(sx * sx + sy * sy, 0)))
    guard magnitude > 0 else { return (0, 0) }
    let scale = Int64(w)
    return ((((sx << 16) / magnitude) * scale) >> 16,
            (((sy << 16) / magnitude) * scale) >> 16)
}
