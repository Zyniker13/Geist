// P3.1 world-feature tests: obstacle circles (avoidance + INV-2
// containment), wind patterns (uniform/shear/gusts, INV-3 integer math),
// and the falcon lurk behavior (P3 R-10).
import XCTest
@testable import MUCore

final class P3WorldFeaturesTests: XCTestCase {
    // MARK: - State builders

    /// A 2048x1536 world: flock at the center, one energy field off in the
    /// southwest corner (far from the patrol orbit), one roost, one falcon.
    private func makeState(
        seed: UInt64 = 0x2026_11,
        falconBehavior: FalconBehavior = .patrol,
        obstacleCenterX: [Int32] = [],
        obstacleCenterY: [Int32] = [],
        obstacleRadius: [Int32] = []
    ) -> GameState {
        GameState(
            birdCount: 48,
            worldWidth: 2048,
            worldHeight: 1536,
            boidsParams: BoidsParams(),
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
            falconBehavior: falconBehavior,
            obstacleCenterX: obstacleCenterX,
            obstacleCenterY: obstacleCenterY,
            obstacleRadius: obstacleRadius
        )
    }

    /// Largest field's center: the lurk anchor.
    private func lurkAnchor(_ state: GameState) -> (x: Int32, y: Int32) {
        var best = state.fields[0]
        for f in state.fields where f.radius > best.radius { best = f }
        return (best.centerX, best.centerY)
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

    private func isqrt(_ x: Int64) -> Int64 {
        isqrt64(UInt64(max(x, 0)))
    }

    // MARK: - Obstacle containment (INV-2: no tunneling)

    func testBirdsNeverEnterObstacleAcross300Ticks() {
        // Rocks scattered between the flock spawn and the leader point.
        var state = makeState(
            obstacleCenterX: [1024, 768, 1400],
            obstacleCenterY: [768, 1100, 500],
            obstacleRadius: [200, 160, 140]
        )
        runTicks(&state, 300)
        for i in 0..<state.birds.count {
            for j in 0..<state.obstacleRadius.count {
                let dx = Int64(state.birds.posX[i]) - Int64(state.obstacleCenterX[j])
                let dy = Int64(state.birds.posY[i]) - Int64(state.obstacleCenterY[j])
                let d = isqrt(dx * dx + dy * dy)
                XCTAssertGreaterThanOrEqual(
                    Int(d), Int(state.obstacleRadius[j]) - 1,
                    "bird \(i) inside obstacle \(j): d=\(d) r=\(state.obstacleRadius[j])"
                )
            }
        }
    }

    func testContainmentOfRapidBirdsDoesNotTunnel() {
        // A bird at max speed straight at a rock cannot tunnel through:
        // containment clamps it to the rim, every tick.
        let frame = BoidsFrame(
            leaderX: 2000, leaderY: 768,
            windXQ: 0, windYQ: 0,
            worldWidth: 2048, worldHeight: 1536,
            obstacleCenterX: [1500],
            obstacleCenterY: [768],
            obstacleRadius: [300]
        )
        var birds = BirdSoA(capacity: 1)
        birds.append(x: 200, y: 768, velXQ: 6 << 16, velYQ: 0, subFlock: 0)
        var hash = SpatialHash(width: 2048, height: 1536, cellSize: 96)
        let params = BoidsParams()
        for tick in 0..<60 {
            hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
            stepBirds(birds: &birds, hash: &hash, frame: frame, params: params)
            let d = isqrt(
                Int64(birds.posX[0] - 1500) * Int64(birds.posX[0] - 1500)
                    + Int64(birds.posY[0] - 768) * Int64(birds.posY[0] - 768)
            )
            XCTAssertGreaterThanOrEqual(
                Int(d), 299,
                "tunneled on tick \(tick): d=\(d) pos=(\(birds.posX[0]),\(birds.posY[0]))"
            )
        }
    }

    func testObstaclesDoNotChangeObstacleFreeTick() {
        // The obstacle must not perturb the shared pipeline (RNG order,
        // reductions) for birds it never touches. Probe evidence: with the
        // rock at (1700,170) the flock's nearest bird stays outside the
        // 330-unit influence ring for the first 18 ticks, and trajectories
        // are bit-identical through that window; after tick 18 the flock
        // genuinely reaches the rock, so the check is bounded to 12 ticks.
        var withRock = makeState(
            obstacleCenterX: [1700],
            obstacleCenterY: [170],
            obstacleRadius: [90]
        )
        var withoutRock = makeState()
        runTicks(&withRock, 12)
        runTicks(&withoutRock, 12)
        XCTAssertEqual(withRock.birds.posX, withoutRock.birds.posX)
        XCTAssertEqual(withRock.birds.posY, withoutRock.birds.posY)
    }

    // MARK: - Wind patterns (P3 R-1)

    func testUniformWindMatchesLegacyFieldBitForBit() {
        // The uniform pattern must reproduce the legacy v3 field exactly:
        // same seed, same cells, same vectors.
        let legacy = GameState.windField(
            generation: 3, seed: 0xABCD, windSeedOffset: 17,
            worldWidth: 2048, worldHeight: 1536
        )
        let uniform = GameState.windField(
            generation: 3, seed: 0xABCD, windSeedOffset: 17,
            worldWidth: 2048, worldHeight: 1536,
            pattern: .uniform
        )
        XCTAssertEqual(legacy.x, uniform.x)
        XCTAssertEqual(legacy.y, uniform.y)
    }

    func testShearWindOneVectorPerRow() {
        let field = GameState.windField(
            generation: 0, seed: 7, windSeedOffset: 0,
            worldWidth: 2048, worldHeight: 1536, pattern: .shear
        )
        let cols = 2048 / 256
        let rows = 1536 / 256
        XCTAssertEqual(field.x.count, cols * rows)
        for row in 0..<rows {
            let base = row * cols
            for col in 1..<cols {
                XCTAssertEqual(field.x[base + col], field.x[base], "row \(row) col \(col)")
                XCTAssertEqual(field.y[base + col], field.y[base], "row \(row) col \(col)")
            }
        }
        // And adjacent rows must carry different vectors (some of the time;
        // with 8 rows an all-equal table would be a broken generator).
        var differingRows = 0
        for row in 1..<rows where field.x[row * cols] != field.x[0] || field.y[row * cols] != field.y[0] {
            differingRows += 1
        }
        XCTAssertGreaterThan(differingRows, 0, "shear must vary by row")
    }

    func testGustWindOneDirectionPerGeneration() {
        let field = GameState.windField(
            generation: 1, seed: 9, windSeedOffset: 0,
            worldWidth: 2048, worldHeight: 1536, pattern: .gusts
        )
        // All nonzero cells share one direction. Integer truncation of the
        // Q16.16 products introduces error < 1 unit per component, so the
        // cross product against the shared direction stays below the sum of
        // component magnitudes (< 80_000 here); a genuinely different
        // direction would produce ~|b|*|c| ≈ 3.9e8.
        let bx = Double(field.x[0]), by = Double(field.y[0])
        for cell in 0..<field.x.count where field.x[cell] != 0 || field.y[cell] != 0 {
            let cross = bx * Double(field.y[cell]) - by * Double(field.x[cell])
            XCTAssertLessThan(abs(cross), 80_000, "cell \(cell) not parallel")
        }
        // Magnitudes span 1/8 to 8/8 of the base 19661 and vary across cells.
        let magnitudes = zip(field.x, field.y).map {
            isqrt(Int64($0) * Int64($0) + Int64($1) * Int64($1))
        }
        XCTAssertGreaterThan(Set(magnitudes).count, 1, "gusts must vary in strength")
        XCTAssertGreaterThanOrEqual(magnitudes.min() ?? 0, 2456)
        XCTAssertLessThanOrEqual(magnitudes.max() ?? 0, 19661)
    }

    func testWindPatternsAreDeterministic() {
        for pattern in WindPattern.allCases {
            let a = GameState.windField(
                generation: 2, seed: 42, windSeedOffset: 3,
                worldWidth: 2048, worldHeight: 1536, pattern: pattern
            )
            let b = GameState.windField(
                generation: 2, seed: 42, windSeedOffset: 3,
                worldWidth: 2048, worldHeight: 1536, pattern: pattern
            )
            XCTAssertEqual(a.x, b.x, "pattern \(pattern)")
            XCTAssertEqual(a.y, b.y, "pattern \(pattern)")
        }
    }

    // MARK: - Falcon behavior (P3 R-10)

    func testPatrolFalconCirclesWorldCenterUnchanged() {
        var state = makeState(falconBehavior: .patrol)
        runTicks(&state, 30)
        let f = state.falcons[0]
        // 30 ticks advance patrolAngle by 180 binary degrees, so assert the
        // orbit distance, not the start angle (±1 for IntTrig rounding).
        let dx = Int64(f.currentX) - Int64(state.worldWidth / 2)
        let dy = Int64(f.currentY) - Int64(state.worldHeight / 2)
        let d = isqrt(dx * dx + dy * dy)
        XCTAssertEqual(Int(d), 512, accuracy: 1, "patrol orbit must stay on the old path")
    }

    func testLurkFalconOrbitsLargestFieldAnchor() {
        var state = makeState(falconBehavior: .lurk)
        let anchor = lurkAnchor(state)
        runTicks(&state, 30)
        let f = state.falcons[0]
        let dx = Int64(f.currentX) - Int64(anchor.x)
        let dy = Int64(f.currentY) - Int64(anchor.y)
        let d = isqrt(dx * dx + dy * dy)
        XCTAssertEqual(Int(d), 96, accuracy: 1, "lurk orbit radius \(d) != 96")
    }

    func testLurkFalconDivesNearestLoneBird() {
        // A lone bird parked beside the largest field anchor draws a lurk
        // dive: the nearest bird, not the sparsest edge.
        var state = makeState(falconBehavior: .lurk)
        let anchor = lurkAnchor(state)
        let baitX = anchor.x + 40
        let baitY = anchor.y + 40
        var sawDive = false
        var s = state
        for _ in 0..<60 {
            var rng = SeededRNG(seed: 1)
            let (next, events) = applyTick(to: s, rng: &rng)
            for event in events {
                if case .falcon(.diveStart) = event { sawDive = true }
            }
            s = next
            s.birds.posX[0] = baitX
            s.birds.posY[0] = baitY
        }
        XCTAssertTrue(sawDive, "lurk falcon never dove at the bait bird")
    }

    func testPatrolFalconDivesFlockNotLoneBait() {
        // Contrast: a patroller ignores the lone bait by the far field and
        // dives at the flock's low-density edge instead. The falcon WILL
        // diveStart (the flock sits inside its orbit reach); what must hold
        // is that no dive targets the bait. diveTarget holds the last dive's
        // target after the run.
        var state = makeState(falconBehavior: .patrol)
        let anchor = lurkAnchor(state)
        let baitX = anchor.x + 40
        let baitY = anchor.y + 40
        var s = state
        for _ in 0..<60 {
            var rng = SeededRNG(seed: 1)
            let (next, _) = applyTick(to: s, rng: &rng)
            s = next
            s.birds.posX[0] = baitX
            s.birds.posY[0] = baitY
        }
        let f = s.falcons[0]
        let tdx = Int64(f.diveTargetX) - Int64(baitX)
        let tdy = Int64(f.diveTargetY) - Int64(baitY)
        XCTAssertGreaterThan(
            isqrt(tdx * tdx + tdy * tdy), 400,
            "patrol falcon targeted the lone bait bird"
        )
    }
}
