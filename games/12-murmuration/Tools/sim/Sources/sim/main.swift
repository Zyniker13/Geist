// MU-P1 headless simulator: runs a full day through the rules engine.
//
// Usage:
//   sim [--birds 4000] [--seed 1]
//
// Sets one circling leader path, then advances the day with applyTick
// (boids, leader, energy, falcons, merges — the real tick). Reports the
// per-tick timing distribution, the total day CPU, and the final
// stateHash; runs the day twice and exits 1 unless both hashes match.

import Foundation
@_exported import MUCore

let arguments = Array(CommandLine.arguments.dropFirst())

func argument(_ name: String, default value: Int) -> Int {
    if let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
       let parsed = Int(arguments[index + 1]) {
        return parsed
    }
    return value
}

let birdCount = argument("--birds", default: 4000)
let seed = UInt64(argument("--seed", default: 1))
let progress = argument("--progress", default: 0) // print tick every N ticks

let worldWidth: Int32 = 2048
let worldHeight: Int32 = 1536

func runDay() -> UInt64 {
    var rng = SeededRNG(seed: seed)
    var state = GameState(
        birdCount: birdCount,
        worldWidth: worldWidth,
        worldHeight: worldHeight,
        boidsParams: BoidsParams(),
        fieldRichness: [10],
        fieldRadius: [128],
        fieldCenterX: [Int32(worldWidth / 2)],
        fieldCenterY: [Int32(worldHeight / 2)],
        roostCount: 1,
        roostCenterX: [Int32(worldWidth / 2)],
        roostCenterY: [Int32(worldHeight / 2)],
        roostRadius: [128],
        falconCount: 1,
        hasRival: false,
        windSeedOffset: 0,
        seed: seed
    )

    // One leader path: a full circle around the world center (R-3).
    var waypoints: [Waypoint] = []
    waypoints.reserveCapacity(24)
    for i in 0..<24 {
        let angle = Double(i) / 24 * 2 * Double.pi
        waypoints.append(Waypoint(
            x: Int32(Double(worldWidth) / 2 + cos(angle) * 500),
            y: Int32(Double(worldHeight) / 2 + sin(angle) * 375)
        ))
    }
    let (withPath, _) = applyAction(.setLeaderPath(subFlock: 0, waypoints: waypoints), to: state)
    state = withPath

    let dayTicks = GameState.dayTicks
    var samples: [Double] = []
    samples.reserveCapacity(dayTicks)

    for tick in 0..<dayTicks {
        if progress > 0 && tick % progress == 0 {
            let last = samples.last ?? 0
            FileHandle.standardError.write(Data("tick \(tick) birds \(state.birds.count) lastTickMs \(String(format: "%.2f", last))\n".utf8))
        }
        let start = DispatchTime.now().uptimeNanoseconds
        let (next, _) = applyTick(to: state, rng: &rng)
        state = next
        let end = DispatchTime.now().uptimeNanoseconds
        samples.append(Double(end - start) / 1_000_000.0)
    }

    samples.sort()
    let totalMs = samples.reduce(0, +)
    let avg = totalMs / Double(samples.count)
    let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
    let maxMs = samples.last ?? 0
    let hash = stateHash(state)
    print(String(format: "birds=%d ticks=%d dayCPU=%.2fs avgTick=%.3fms p95=%.3fms max=%.3fms finalHash=%016llx",
                 birdCount, dayTicks, totalMs / 1000.0, avg, p95, maxMs, hash))
    if TickProfiler.enabled { print(TickProfiler.report()) }
    return hash
}

let first = runDay()
let second = runDay()
print(first == second ? "deterministic=true" : "deterministic=FALSE")
exit(first == second ? 0 : 1)
