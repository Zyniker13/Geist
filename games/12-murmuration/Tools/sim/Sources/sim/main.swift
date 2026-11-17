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
let checkpointEvery = argument("--checkpoints", default: 0) // print stateHash every N ticks (INV-3)
let goldenCount = argument("--golden", default: 0) // generate N golden replays
let goldenOut = arguments.firstIndex(of: "--golden-out").flatMap { idx -> String? in
    idx + 1 < arguments.count ? arguments[idx + 1] : nil
}

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
        if checkpointEvery > 0 && (tick + 1) % checkpointEvery == 0 {
            print("checkpoint tick=\(tick + 1) hash=\(String(format: "%016llx", stateHash(state)))")
        }
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

// MARK: - Golden replay generation (S1.4)

/// A deterministic action script for a seed: every replay gets a leader path
/// early, a condense mid-morning, a second path, a split with a second-flock
/// path, and a late condense on the second flock. Waypoint geometry varies
/// deterministically with the seed via SeededRNG, so the 20 goldens exercise
/// different leader behavior without any nondeterminism in the generator.
func actionScript(seed: UInt64, worldWidth: Int32, worldHeight: Int32) -> [TimedGameAction] {
    var rng = SeededRNG(seed: seed &+ 0x5EED)
    let cx = Double(worldWidth) / 2
    let cy = Double(worldHeight) / 2
    func circle(_ radius: Double, _ points: Int, _ phase: Double) -> [Waypoint] {
        (0..<points).map { i in
            let angle = phase + Double(i) / Double(points) * 2 * .pi
            return Waypoint(x: Int32(cx + cos(angle) * radius),
                            y: Int32(cy + sin(angle) * radius * 0.75))
        }
    }
    func sweep(_ span: Double) -> [Waypoint] {
        let left = Int32(cx - span)
        let right = Int32(cx + span)
        let top = Int32(cy - span * 0.6)
        let bottom = Int32(cy + span * 0.6)
        return [Waypoint(x: left, y: top), Waypoint(x: right, y: top),
                Waypoint(x: right, y: bottom), Waypoint(x: left, y: bottom)]
    }
    let r1 = Double(rng.next(upperBound: 300)) + 200
    let r2 = Double(rng.next(upperBound: 250)) + 150
    let phase = Double(rng.next(upperBound: 1000)) / 1000.0 * 2 * .pi
    let span1 = Double(rng.next(upperBound: 300)) + 250
    let span2 = Double(rng.next(upperBound: 250)) + 200
    let ratio = 0.35 + Double(rng.next(upperBound: 30)) / 100.0
    return [
        TimedGameAction(tick: 100, action: .setLeaderPath(subFlock: 0, waypoints: circle(r1, 24, phase))),
        TimedGameAction(tick: 900, action: .condense(subFlock: 0)),
        TimedGameAction(tick: 1400, action: .setLeaderPath(subFlock: 0, waypoints: sweep(span1))),
        TimedGameAction(tick: 2200, action: .splitFlock(from: 0, ratio: ratio)),
        TimedGameAction(tick: 2201, action: .setLeaderPath(subFlock: 1, waypoints: circle(r2, 20, phase + .pi))),
        TimedGameAction(tick: 3300, action: .condense(subFlock: 1)),
        TimedGameAction(tick: 3900, action: .setLeaderPath(subFlock: 0, waypoints: sweep(span2))),
    ]
}

if goldenCount > 0 {
    let outDir = goldenOut ?? "GoldenReplays"
    try FileManager.default.createDirectory(
        atPath: outDir, withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var manifest: [String] = []
    for index in 1...goldenCount {
        let replaySeed = UInt64(index)
        // Vary flock sizes across the goldens (smaller flocks keep the
        // committed-replay test fast while still exercising merges, splits,
        // falcon dives, growth, and starvation).
        let replayBirds = 200 + (index - 1) * 40
        let actions = actionScript(seed: replaySeed, worldWidth: worldWidth, worldHeight: worldHeight)
        var state = makeGoldenWorld(birdCount: replayBirds, seed: replaySeed)
        var rng = SeededRNG(seed: replaySeed)
        var next = actions.makeIterator()
        var pending = next.next()
        for tick in 0..<GameState.dayTicks {
            while let timed = pending, timed.tick == tick {
                let (applied, _) = applyAction(timed.action, to: state)
                state = applied
                pending = next.next()
            }
            let (advanced, _) = applyTick(to: state, rng: &rng)
            state = advanced
        }
        let hash = stateHash(state)
        let record = GameReplay(
            seed: replaySeed,
            contentVersion: state.contentVersion,
            birdCount: replayBirds,
            worldWidth: worldWidth,
            worldHeight: worldHeight,
            actions: actions,
            finalHash: hash
        )
        let data = try encoder.encode(record)
        let name = String(format: "golden-%02d.json", index)
        try data.write(to: URL(fileURLWithPath: outDir + "/" + name))
        manifest.append("\(name) seed=\(replaySeed) hash=\(String(format: "%016llx", hash))")
    }
    print(manifest.joined(separator: "\n"))
    exit(0)
}

let first = runDay()
let second = runDay()
print(first == second ? "deterministic=true" : "deterministic=FALSE")
exit(first == second ? 0 : 1)
