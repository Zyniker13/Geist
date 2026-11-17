/// Fixed-point boid kernel (R-6, R-7): separation, alignment, cohesion, leader
/// attraction, and wind, with speed clamped to `[minSpeed, maxSpeed]`.
///
/// All math is integer (Q16.16 velocities, Int64 accumulators, integer sqrt) so the
/// simulation is bit-identical across devices (INV-3). Neighbor iteration order is
/// deterministic: 3x3 cells row-major, bird IDs ascending within a cell.
public struct BoidsParams: Sendable {
    public var sepRadius: Int32 = 24
    public var alignRadius: Int32 = 64
    public var cohRadius: Int32 = 96
    public var sepWeight: Int32 = 98_304      // 1.5 in Q16.16
    public var alignWeight: Int32 = 65_536    // 1.0
    public var cohWeight: Int32 = 52_429      // 0.8
    public var leaderWeight: Int32 = 78_643   // 1.2
    public var windWeight: Int32 = 39_322     // 0.6
    public var minSpeed: Int32 = 1_179_648    // 18 units/tick in Q16.16
    public var maxSpeed: Int32 = 2_621_440    // 40 units/tick in Q16.16
    public var edgeMargin: Int32 = 64         // steer inward within this band
    public var edgeWeight: Int32 = 65_536     // 1.0

    public init() {}
}

/// Per-tick world inputs for `stepBirds`: the active sub-flock's leader point,
/// the wind vector (Q16.16), and the world bounds.
public struct BoidsFrame: Sendable {
    public var leaderX: Int32
    public var leaderY: Int32
    public var windXQ: Int32
    public var windYQ: Int32
    public var worldWidth: Int32
    public var worldHeight: Int32

    public init(
        leaderX: Int32, leaderY: Int32,
        windXQ: Int32, windYQ: Int32,
        worldWidth: Int32, worldHeight: Int32
    ) {
        self.leaderX = leaderX
        self.leaderY = leaderY
        self.windXQ = windXQ
        self.windYQ = windYQ
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
    }
}

/// Advance every bird one tick. `frame.leaderX/leaderY` are the active
/// sub-flock's leader point; the spike drives a single flock, so one leader
/// serves all birds.
public func stepBirds(
    birds: inout BirdSoA,
    hash: inout SpatialHash,
    frame: BoidsFrame,
    params: BoidsParams
) {
    let count = birds.count
    guard count > 0 else { return }

    let sep2 = Int64(params.sepRadius) * Int64(params.sepRadius)
    let align2 = Int64(params.alignRadius) * Int64(params.alignRadius)
    let coh2 = Int64(params.cohRadius) * Int64(params.cohRadius)
    let minSpeed2 = Int64(params.minSpeed) * Int64(params.minSpeed)
    let maxSpeed2 = Int64(params.maxSpeed) * Int64(params.maxSpeed)

    for i in 0..<count {
        let px = birds.posX[i]
        let py = birds.posY[i]
        let home = hash.cellOf(x: px, y: py)

        var sepSumX: Int64 = 0
        var sepSumY: Int64 = 0
        var alignSumX: Int64 = 0
        var alignSumY: Int64 = 0
        var cohSumX: Int64 = 0
        var cohSumY: Int64 = 0
        var sepCount = 0
        var alignCount = 0
        var cohCount = 0

        // 3x3 neighborhood, row-major from the top-left: fixed iteration order.
        var cy = home.cy - 1
        while cy <= home.cy + 1 {
            if cy >= 0 && cy < hash.rows {
                var cx = home.cx - 1
                while cx <= home.cx + 1 {
                    if cx >= 0 && cx < hash.cols {
                        let cellRange = hash.range(cx: cx, cy: cy)
                        for slot in cellRange {
                            let j = Int(hash.birdID(at: slot))
                            if j == i { continue }
                            let dx = Int64(birds.posX[j]) - Int64(px)
                            let dy = Int64(birds.posY[j]) - Int64(py)
                            let d2 = dx * dx + dy * dy
                            if d2 < coh2 {
                                cohSumX += dx
                                cohSumY += dy
                                cohCount += 1
                                if d2 < align2 {
                                    alignSumX += Int64(birds.velX[j])
                                    alignSumY += Int64(birds.velY[j])
                                    alignCount += 1
                                    if d2 < sep2 {
                                        sepSumX -= dx
                                        sepSumY -= dy
                                        sepCount += 1
                                    }
                                }
                            }
                        }
                    }
                    cx += 1
                }
            }
            cy += 1
        }

        // Steering forces: each normalized direction scaled by its Q16.16 weight.
        var forceX: Int64 = 0
        var forceY: Int64 = 0
        if sepCount > 0 {
            let f = normalizedScaled(sepSumX, sepSumY, params.sepWeight)
            forceX += f.x
            forceY += f.y
        }
        if alignCount > 0 {
            let f = normalizedScaled(alignSumX, alignSumY, params.alignWeight)
            forceX += f.x
            forceY += f.y
        }
        if cohCount > 0 {
            let f = normalizedScaled(cohSumX, cohSumY, params.cohWeight)
            forceX += f.x
            forceY += f.y
        }
        let leaderDX = Int64(frame.leaderX) - Int64(px)
        let leaderDY = Int64(frame.leaderY) - Int64(py)
        let leaderF = normalizedScaled(leaderDX, leaderDY, params.leaderWeight)
        forceX += leaderF.x
        forceY += leaderF.y
        if frame.windXQ != 0 || frame.windYQ != 0 {
            let windF = normalizedScaled(Int64(frame.windXQ), Int64(frame.windYQ), params.windWeight)
            forceX += windF.x
            forceY += windF.y
        }

        // World-edge avoidance (the R-6 obstacle-avoidance force against the
        // world border). Without it birds pin to the walls and stream along
        // the perimeter, so the flock can never be steered to a leader point.
        let margin = Int64(params.edgeMargin)
        if margin > 0 {
            let edgeW = Int64(params.edgeWeight)
            if Int64(px) < margin { forceX += edgeW }
            if Int64(frame.worldWidth - 1) - Int64(px) < margin { forceX -= edgeW }
            if Int64(py) < margin { forceY += edgeW }
            if Int64(frame.worldHeight - 1) - Int64(py) < margin { forceY -= edgeW }
        }

        // Integrate velocity, clamping to Q16.16 range, then clamp speed.
        var vx = Int64(birds.velX[i]) + forceX
        var vy = Int64(birds.velY[i]) + forceY
        vx = vx.clampedToQ16()
        vy = vy.clampedToQ16()

        let speed2 = vx * vx + vy * vy
        if speed2 > maxSpeed2 {
            // Hard cap: never exceeded, even mid-turn.
            let scaled = rescaleDown(vx, vy, to: params.maxSpeed, speed2: speed2)
            vx = scaled.x
            vy = scaled.y
        } else if speed2 < minSpeed2 {
            // Cruise floor, not a hard constraint while turning: when the net
            // force decelerates the bird (negative dot with its velocity), the
            // speed may dip below `minSpeed` so the direction can reverse.
            // Enforcing the floor during a decelerating turn re-inflates the
            // old direction every tick and permanently deadlocks birds whose
            // velocity points into a wall along the force line.
            let dot = forceX * vx + forceY * vy
            if dot >= 0 {
                let scaled = rescaleUp(vx, vy, to: params.minSpeed, speed2: speed2)
                vx = scaled.x
                vy = scaled.y
            }
        }

        birds.velX[i] = Int32(truncatingIfNeeded: vx)
        birds.velY[i] = Int32(truncatingIfNeeded: vy)

        // Integrate position (Q16.16 velocity -> raw world units).
        var nx = px + Int32(vx >> 16)
        var ny = py + Int32(vy >> 16)
        nx = max(0, min(frame.worldWidth - 1, nx))
        ny = max(0, min(frame.worldHeight - 1, ny))
        birds.posX[i] = nx
        birds.posY[i] = ny
    }
}

/// Normalize a Q16.16 vector and scale by `weight`, returning Q16.16 components.
///
/// Parentheses matter here: Swift binds `<<`/`>>` tighter than `*`//`, so an
/// unparenthesized `x << 16 / m * w >> 16` would parse as `(x << 16 / m) *
/// (w >> 16)` and truncate the weight to whole units (0.8 and 0.6 would
/// become zero). Verified by BoidsTests.testLeaderForceMatchesWeight.
@inline(__always)
private func normalizedScaled(_ x: Int64, _ y: Int64, _ weight: Int32) -> (x: Int64, y: Int64) {
    let magnitude = isqrt64(UInt64(x * x + y * y))
    guard magnitude > 0 else { return (0, 0) }
    let scale = Int64(weight)
    return ((((x << 16) / magnitude) * scale) >> 16,
            (((y << 16) / magnitude) * scale) >> 16)
}

/// Rescale a Q16.16 velocity to magnitude >= `target` (min-speed branch).
///
/// `isqrt64` floors the true magnitude, so `magnitude <= sqrt(speed2)`. Each
/// component is then divided rounding AWAY FROM ZERO, which can only grow the
/// result magnitude: |result| >= target * sqrt(speed2) / magnitude >= target.
/// Deterministic integer math (INV-3); no floating point.
@inline(__always)
private func rescaleUp(_ x: Int64, _ y: Int64, to target: Int32, speed2: Int64) -> (x: Int64, y: Int64) {
    let magnitude = isqrt64(UInt64(speed2))
    guard magnitude > 0 else { return (0, 0) }
    let t = Int64(target)
    return (scaledAwayFromZero(x, t, magnitude), scaledAwayFromZero(y, t, magnitude))
}

/// Rescale a Q16.16 velocity to magnitude <= `target` (max-speed branch).
///
/// Round the magnitude UP to `ceil(sqrt(speed2))` (never underestimate), then
/// floor-divide each component: |result| <= target * sqrt(speed2) / magnitude
/// <= target. Deterministic integer math (INV-3).
@inline(__always)
private func rescaleDown(_ x: Int64, _ y: Int64, to target: Int32, speed2: Int64) -> (x: Int64, y: Int64) {
    var magnitude = isqrt64(UInt64(speed2))
    guard magnitude > 0 else { return (0, 0) }
    if magnitude * magnitude < speed2 { magnitude += 1 } // ceil(sqrt(speed2))
    let t = Int64(target)
    return (x * t / magnitude, y * t / magnitude)
}

/// Scale `v` by `t / magnitude`, rounding away from zero so the magnitude
/// never shrinks below the exact real-valued product.
@inline(__always)
private func scaledAwayFromZero(_ v: Int64, _ t: Int64, _ magnitude: Int64) -> Int64 {
    if v == 0 { return 0 }
    let absV = v < 0 ? -v : v
    let scaled = (absV * t + magnitude - 1) / magnitude // ceil for absV > 0
    return v < 0 ? -scaled : scaled
}

/// Integer square root (bit-by-bit), deterministic on every platform.
public func isqrt64(_ value: UInt64) -> Int64 {
    var x = value
    var result: UInt64 = 0
    var bit: UInt64 = 1 << 62
    while bit > x { bit >>= 2 }
    while bit != 0 {
        if x >= result + bit {
            x -= result + bit
            result = (result >> 1) + bit
        } else {
            result >>= 1
        }
        bit >>= 2
    }
    return Int64(result)
}

extension Int64 {
    /// Clamp to the representable Q16.16 range held in Int32 storage.
    @inline(__always)
    func clampedToQ16() -> Int64 {
        let limit = Int64(Int32.max)
        if self > limit { return limit }
        if self < -limit { return -limit }
        return self
    }
}
