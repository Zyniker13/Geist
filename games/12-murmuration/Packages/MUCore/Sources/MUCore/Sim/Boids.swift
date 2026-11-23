/// Fixed-point boid kernel (R-6, R-7): separation, alignment, cohesion, leader
/// attraction, and wind, with speed clamped to `[minSpeed, maxSpeed]`.
///
/// All math is integer (Q16.16 velocities, Int64 accumulators, integer sqrt) so the
/// simulation is bit-identical across devices (INV-3). Neighbor iteration order is
/// deterministic: 3x3 cells row-major, bird IDs ascending within a cell.
public struct BoidsParams: Sendable, Codable {
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
    public var obstacleWeight: Int32 = 98_304 // 1.5 — P3: rock beats flock
    /// Falcon-avoid weight (MU-P8.2 assist steering): 0 = assist off
    /// (every existing replay's trajectories are unchanged). On, the
    /// player's birds push away from live falcons like from obstacles.
    public var falconAssistWeight: Int32 = 0
    /// Leader brake (P4): inside this radius of the leader point the bird's
    /// velocity is damped each tick so the flock settles onto the point
    /// instead of swinging past it and back forever (undamped pendulum).
    public var leaderBrakeRadius: Int32 = 800
    /// Damping (Q16.16) applied at the leader point itself, ramping linearly
    /// down to zero at `leaderBrakeRadius`: 32_768 = 0.5 per tick at the
    /// point, 0.125 at three-quarters of the radius out, 0 at the edge.
    public var leaderBrakeQ: Int32 = 32_768

    public init() {}
}

/// Per-tick world inputs for `stepBirds`: the active sub-flock's leader point,
/// the wind field (R-1: one Q16.16 vector per 256-unit cell, with a uniform
/// fallback for grid-less callers), and the world bounds.
public struct BoidsFrame: Sendable, Codable {
    public var leaderX: Int32
    public var leaderY: Int32
    /// Leader point per sub-flock (R-3/R-4); falls back to leaderX/Y when empty.
    public var leadersX: [Int32]
    public var leadersY: [Int32]
    public var windXQ: Int32
    public var windYQ: Int32
    public var worldWidth: Int32
    public var worldHeight: Int32
    /// Per-cell wind vectors (R-1), row-major over 256-unit cells; empty = uniform.
    public var windCellsX: [Int32]
    public var windCellsY: [Int32]
    public var windGridCols: Int32
    public var windGridRows: Int32
    public var windCellSize: Int32
    /// Static obstacle circles (P3): parallel center/radius arrays in world
    /// units; empty = no obstacles.
    public var obstacleCenterX: [Int32]
    public var obstacleCenterY: [Int32]
    public var obstacleRadius: [Int32]
    /// Live falcon positions (MU-P8.2 assist steering); empty = no falcons.
    public var falconX: [Int32]
    public var falconY: [Int32]

    public init(
        leaderX: Int32, leaderY: Int32,
        windXQ: Int32, windYQ: Int32,
        worldWidth: Int32, worldHeight: Int32,
        leadersX: [Int32] = [],
        leadersY: [Int32] = [],
        windCellsX: [Int32] = [],
        windCellsY: [Int32] = [],
        windGridCols: Int32 = 0,
        windGridRows: Int32 = 0,
        windCellSize: Int32 = 256,
        obstacleCenterX: [Int32] = [],
        obstacleCenterY: [Int32] = [],
        obstacleRadius: [Int32] = [],
        falconX: [Int32] = [],
        falconY: [Int32] = []
    ) {
        self.leaderX = leaderX
        self.leaderY = leaderY
        self.leadersX = leadersX
        self.leadersY = leadersY
        self.windXQ = windXQ
        self.windYQ = windYQ
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.windCellsX = windCellsX
        self.windCellsY = windCellsY
        self.windGridCols = windGridCols
        self.windGridRows = windGridRows
        self.windCellSize = windCellSize
        self.obstacleCenterX = obstacleCenterX
        self.obstacleCenterY = obstacleCenterY
        self.obstacleRadius = obstacleRadius
        self.falconX = falconX
        self.falconY = falconY
    }

    /// The leader point acting on a bird of sub-flock `sf`.
    @inline(__always)
    public func leader(for sf: Int32) -> (x: Int32, y: Int32) {
        let s = Int(sf)
        if s < leadersX.count, s < leadersY.count { return (leadersX[s], leadersY[s]) }
        return (leaderX, leaderY)
    }

    /// The wind vector (Q16.16) acting on a bird at `(px, py)`.
    @inline(__always)
    public func wind(at px: Int32, _ py: Int32) -> (x: Int32, y: Int32) {
        if windCellsX.isEmpty || windGridCols <= 0 || windGridRows <= 0 || windCellSize <= 0 {
            return (windXQ, windYQ)
        }
        let col = max(0, min(Int(windGridCols) - 1, Int(px) / Int(windCellSize)))
        let row = max(0, min(Int(windGridRows) - 1, Int(py) / Int(windCellSize)))
        let cell = row * Int(windGridCols) + col
        guard cell < windCellsX.count, cell < windCellsY.count else { return (windXQ, windYQ) }
        return (windCellsX[cell], windCellsY[cell])
    }

    /// The strongest obstacle push (Q16.16 magnitude) acting on a bird at
    /// `(px, py)`: the nearest circle wins, weighted by inverse distance
    /// (P3). Returns zeros when the bird is clear of every circle.
    @inline(__always)
    public func obstacleForce(at px: Int32, _ py: Int32) -> (x: Int32, y: Int32) {
        var bestD2 = Int64.max
        var fx: Int32 = 0
        var fy: Int32 = 0
        var bestRadius: Int32 = 0
        for i in 0..<obstacleRadius.count {
            let dx = px - obstacleCenterX[i]
            let dy = py - obstacleCenterY[i]
            let d2 = Int64(dx) * Int64(dx) + Int64(dy) * Int64(dy)
            if d2 < bestD2 {
                bestD2 = d2
                fx = dx
                fy = dy
                bestRadius = obstacleRadius[i]
            }
        }
        guard bestD2 < Int64.max else { return (0, 0) }
        // Inside influence = radius + 240 (same margin logic as the edges).
        let reach = Int64(bestRadius) + 240
        guard bestD2 < reach * reach else { return (0, 0) }
        let d = isqrt64(UInt64(max(bestD2, 1)))
        if d == 0 { return (0, 1) } // exactly on center: push down
        let n = 65_536 / d // Q16.16 inverse distance
        return (Int32((Int64(fx) * n) >> 16), Int32((Int64(fy) * n) >> 16))
    }

    /// The falcon-avoid direction (MU-P8.2 assist steering): the raw delta
    /// away from the nearest live falcon when it is inside the 480-unit
    /// fear radius, else zeros. stepBirds feeds this through
    /// normalizedScaled, giving a constant-weight push in the exact away
    /// direction (the same path the obstacle force takes — a pre-quantized
    /// unit vector loses most directions to integer truncation). Returns
    /// (0, 1) when the bird sits exactly on the falcon center. Pure
    /// integer (INV-3), no division.
    @inline(__always)
    public func falconForce(at px: Int32, _ py: Int32) -> (x: Int32, y: Int32) {
        guard !falconX.isEmpty, !falconY.isEmpty else { return (0, 0) }
        var bestD2 = Int64.max
        var fx: Int32 = 0
        var fy: Int32 = 0
        for i in 0..<min(falconX.count, falconY.count) {
            let dx = px - falconX[i]
            let dy = py - falconY[i]
            let d2 = Int64(dx) * Int64(dx) + Int64(dy) * Int64(dy)
            if d2 < bestD2 {
                bestD2 = d2
                fx = dx
                fy = dy
            }
        }
        guard bestD2 < Int64.max else { return (0, 0) }
        let reach: Int64 = 480
        guard bestD2 < reach * reach else { return (0, 0) }
        if bestD2 == 0 { return (0, 1) } // exactly on center: push down
        return (fx, fy)
    }

    /// Project a world point to the nearest position at least `minDist`
    /// outside every obstacle circle (P3 INV-2 containment). Pure integer.
    @inline(__always)
    public func containOutsideObstacles(_ px: Int32, _ py: Int32, minDist: Int32 = 2) -> (x: Int32, y: Int32) {
        var x = px
        var y = py
        for i in 0..<obstacleRadius.count {
            let cx = obstacleCenterX[i]
            let cy = obstacleCenterY[i]
            let dx = x - cx
            let dy = y - cy
            let d2 = Int64(dx) * Int64(dx) + Int64(dy) * Int64(dy)
            let limit = Int64(obstacleRadius[i]) + Int64(minDist)
            guard d2 < limit * limit else { continue }
            let d = isqrt64(UInt64(max(d2, 1)))
            var ux: Int64
            var uy: Int64
            if d == 0 {
                // Exactly on center: shove east along +x to the rim (Q16 unit).
                ux = Int64(limit) << 16
                uy = 0
            } else {
                ux = (Int64(dx) << 16) / d
                uy = (Int64(dy) << 16) / d
            }
            x = cx + Int32((Int64(ux) * limit) >> 16)
            y = cy + Int32((Int64(uy) * limit) >> 16)
        }
        return (x, y)
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

    // Neighbor-scan cap: in an ultra-dense flock a bird can have thousands of
    // neighbors inside the cohesion radius, making the per-tick cost O(n · k)
    // explode exactly when the flock is tightest (a 4,000-bird day ran ~7 ms
    // per tick, far over the G1 budget). Boids steering needs a local sample,
    // not the complete set, so each bird examines at most `maxNeighborVisits`
    // neighbors per tick, taken in the deterministic iteration order (3x3
    // cells row-major, bird IDs ascending within a cell). This bounds the
    // worst case, keeps results reproducible (INV-3), and leaves the spatial
    // hash itself exact (INV-4 covers the hash, not the steering subset).
    // See docs/DECISIONS.md, "Neighbor-visit cap in stepBirds".
    let maxNeighborVisits = 48

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
        var visits = 0

        // 3x3 neighborhood, row-major from the top-left: fixed iteration order.
        var cy = home.cy - 1
        outer: while cy <= home.cy + 1 {
            if cy >= 0 && cy < hash.rows {
                var cx = home.cx - 1
                while cx <= home.cx + 1 {
                    if cx >= 0 && cx < hash.cols {
                        let cellRange = hash.range(cx: cx, cy: cy)
                        for slot in cellRange {
                            if visits >= maxNeighborVisits { break outer }
                            let j = Int(hash.birdID(at: slot))
                            if j == i { continue }
                            visits += 1
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
        let leader = frame.leader(for: Int32(birds.subFlock[i]))
        let leaderDX = Int64(leader.x) - Int64(px)
        let leaderDY = Int64(leader.y) - Int64(py)
        let leaderF = normalizedScaled(leaderDX, leaderDY, params.leaderWeight)
        forceX += leaderF.x
        forceY += leaderF.y
        // Leader brake (P4): near the leader point, damp velocity so a bird
        // converges onto the point instead of overshooting and swinging back
        // forever. The damping ramps linearly from zero at the radius edge to
        // the full `leaderBrakeQ` at the point, so transit through the outer
        // radius keeps cruise speed and only the final approach decelerates
        // (an arrive profile; a flat brake inside 800 damped day-start trips
        // to a crawl and merged the day-start clouds before they separated).
        let brake2 = Int64(params.leaderBrakeRadius)
            * Int64(params.leaderBrakeRadius)
        let d2 = leaderDX * leaderDX + leaderDY * leaderDY
        if d2 < brake2 {
            let ramp = Int64(params.leaderBrakeRadius) - isqrt64(UInt64(max(d2, 1)))
            let q = (Int64(params.leaderBrakeQ) * ramp) / Int64(params.leaderBrakeRadius)
            forceX -= (Int64(birds.velX[i]) * q) >> 16
            forceY -= (Int64(birds.velY[i]) * q) >> 16
        }
        let (windX, windY) = frame.wind(at: px, py)
        if windX != 0 || windY != 0 {
            let windF = normalizedScaled(Int64(windX), Int64(windY), params.windWeight)
            forceX += windF.x
            forceY += windF.y
        }

        // Obstacle avoidance (P3): the nearest circle pushes outward with
        // strength proportional to inverse distance.
        let (obsX, obsY) = frame.obstacleForce(at: birds.posX[i], birds.posY[i])
        if obsX != 0 || obsY != 0 {
            let obsF = normalizedScaled(Int64(obsX), Int64(obsY), params.obstacleWeight)
            forceX += obsF.x
            forceY += obsF.y
        }

        // Falcon assist (MU-P8.2): when enabled, the same inverse-distance
        // profile pushes birds away from the nearest live falcon.
        if params.falconAssistWeight > 0 {
            let (favX, favY) = frame.falconForce(at: birds.posX[i], birds.posY[i])
            if favX != 0 || favY != 0 {
                let favF = normalizedScaled(Int64(favX), Int64(favY), params.falconAssistWeight)
                forceX += favF.x
                forceY += favF.y
            }
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
        // Obstacle containment (P3 INV-2): no bird may end a tick inside a
        // rock, whatever the steering forces decided this tick.
        if !frame.obstacleRadius.isEmpty {
            let c = frame.containOutsideObstacles(nx, ny)
            nx = c.x
            ny = c.y
            nx = max(0, min(frame.worldWidth - 1, nx))
            ny = max(0, min(frame.worldHeight - 1, ny))
        }
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
///
/// `x`/`y` are raw sums over the neighbor set, so their magnitude is not
/// bounded a priori (an ultra-dense flock puts thousands of neighbors inside
/// the alignment radius, each contributing a full Q16.16 velocity). Squaring
/// such a sum overflows Int64, so the inputs are first down-shifted
/// deterministically until each fits the squaring budget. The shift only
/// engages for sums that would otherwise trap, costs at most a few low-order
/// bits of direction precision, and is pure integer math (INV-3).
@inline(__always)
private func normalizedScaled(_ x: Int64, _ y: Int64, _ weight: Int32) -> (x: Int64, y: Int64) {
    // (2^31 - 1)^2 * 2 < Int64.max, so sums within this bound square safely.
    let safe: Int64 = 2_147_483_647
    var sx = x
    var sy = y
    while sx > safe || sx < -safe || sy > safe || sy < -safe {
        sx >>= 1
        sy >>= 1
    }
    let magnitude = isqrt64(UInt64(sx * sx + sy * sy))
    guard magnitude > 0 else { return (0, 0) }
    let scale = Int64(weight)
    return ((((sx << 16) / magnitude) * scale) >> 16,
            (((sy << 16) / magnitude) * scale) >> 16)
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
