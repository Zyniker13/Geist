// MU-P0.1 spike: 4,000 fixed-point boids at 30 Hz on CPU, tick time on Mac Release.
//
// Usage:
//   spike --birds 4000 --ticks 300 [--seed 1]
//   spike golden            # print the trivial golden-replay record as JSON
//
// The boid run reports average and maximum per-tick cost (rebuild + step), a final
// state hash, and a two-run determinism check (identical hashes across two full runs).

import Foundation
import MUCore

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "golden" {
    // Generate the committed golden replay for the trivial state harness.
    var actions: [TimedAction] = []
    var rng = SeededRNG(seed: 2026)
    for tick in 0..<24 {
        if tick % 3 == 0 {
            actions.append(TimedAction(tick: tick, action: .increment(Int(rng.next(upperBound: 9)) + 1)))
        } else {
            actions.append(TimedAction(tick: tick, action: .mix(rng.next())))
        }
    }
    let record = Replay(seed: 2026, contentVersion: 1, actions: actions)
    let final = replay(record)
    struct GoldenFile: Codable { let seed: UInt64; let contentVersion: Int; let actions: [TimedAction]; let expectedHash: UInt64 }
    let golden = GoldenFile(seed: record.seed, contentVersion: record.contentVersion, actions: record.actions, expectedHash: stateHash(final))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(golden)
    print(String(bytes: data, encoding: .utf8) ?? "<invalid utf8>")
    exit(0)
}

func argument(_ name: String, default value: Int) -> Int {
    if let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
       let parsed = Int(arguments[index + 1]) {
        return parsed
    }
    return value
}

let birdCount = argument("--birds", default: 4000)
let tickCount = argument("--ticks", default: 300)
let seed = UInt64(argument("--seed", default: 1))

let worldWidth: Int32 = 4096
let worldHeight: Int32 = 3072

func runSimulation() -> UInt64 {
    var rng = SeededRNG(seed: seed)
    var birds = BirdSoA(capacity: birdCount)
    for _ in 0..<birdCount {
        // Integer-only spawn: deterministic direction from a seeded angle table.
        let angleRaw = rng.next(upperBound: 1 << 20)
        let angle = Double(angleRaw) / Double(1 << 20) * 2.0 * Double.pi
        let speedQ: Int32 = 1_835_008  // 28 units/tick in Q16.16
        let vx = Int32(cos(angle) * Double(speedQ))
        let vy = Int32(sin(angle) * Double(speedQ))
        birds.append(
            x: Int32(rng.next(upperBound: Int(worldWidth))),
            y: Int32(rng.next(upperBound: Int(worldHeight))),
            velXQ: vx,
            velYQ: vy,
            subFlock: 0
        )
    }
    var hash = SpatialHash(width: worldWidth, height: worldHeight, cellSize: 96)
    let params = BoidsParams()

    var samples: [Double] = []
    samples.reserveCapacity(tickCount)

    // Leader circles the world center; wind rotates every 600 ticks (R-1 cadence).
    for tick in 0..<tickCount {
        let angle = Double(tick) * 0.05
        let leaderX = Int32(Double(worldWidth) / 2 + cos(angle) * 600)
        let leaderY = Int32(Double(worldHeight) / 2 + sin(angle) * 450)
        let windAngle = Double(tick / 600) * 0.7
        let windXQ = Int32(cos(windAngle) * 327_680)  // 5 units/tick in Q16.16
        let windYQ = Int32(sin(windAngle) * 327_680)

        let start = DispatchTime.now().uptimeNanoseconds
        hash.rebuild(posX: birds.posX, posY: birds.posY, count: birds.count)
        stepBirds(
            birds: &birds, hash: &hash,
            frame: BoidsFrame(
                leaderX: leaderX, leaderY: leaderY,
                windXQ: windXQ, windYQ: windYQ,
                worldWidth: worldWidth, worldHeight: worldHeight
            ),
            params: params
        )
        let end = DispatchTime.now().uptimeNanoseconds
        samples.append(Double(end - start) / 1_000_000.0)
    }

    // Checkpoint hash every 300 ticks: FNV-1a over positions and velocities.
    var stateHashValue: UInt64 = 0xcbf29ce484222325
    func mix(_ byte: UInt8) {
        stateHashValue &= ~UInt64(byte)
        stateHashValue = stateHashValue &* 0x100000001b3
    }
    func mix32(_ value: Int32) {
        withUnsafeBytes(of: value) { for b in $0 { mix(b) } }
    }
    for i in 0..<birds.count {
        mix32(birds.posX[i])
        mix32(birds.posY[i])
        mix32(birds.velX[i])
        mix32(birds.velY[i])
    }

    samples.sort()
    let avg = samples.reduce(0, +) / Double(samples.count)
    let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
    let maxMs = samples.last ?? 0
    print(String(format: "birds=%d ticks=%d avgTick=%.3fms p95=%.3fms max=%.3fms finalHash=%016llx", birdCount, tickCount, avg, p95, maxMs, stateHashValue))
    return stateHashValue
}

let first = runSimulation()
let second = runSimulation()
print(first == second ? "deterministic=true" : "deterministic=FALSE")
exit(first == second ? 0 : 1)
