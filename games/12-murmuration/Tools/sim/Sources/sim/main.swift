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
import MUContent
import MUAI

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
// MU-P4 balance harness: Autoplayer vs tiered rival, one seeded day per row.
let balanceTier = arguments.firstIndex(of: "--balance").flatMap { idx -> String? in
    idx + 1 < arguments.count ? arguments[idx + 1] : nil
}
let balanceDays = argument("--days", default: 100)
let balanceRegions = arguments.firstIndex(of: "--regions").flatMap { idx -> String? in
    idx + 1 < arguments.count ? arguments[idx + 1] : nil
}
let balanceOut = arguments.firstIndex(of: "--out").flatMap { idx -> String? in
    idx + 1 < arguments.count ? arguments[idx + 1] : nil
}
let balanceTrace = argument("--trace", default: 0) // print rival flock state every N ticks
let balanceEvents = argument("--events", default: 0) // print energy/falcon/roost/split events
// Rival cadence overrides (tuning probes; <0 keeps the tier table value).
let rivalForageOverride = argument("--rival-forage", default: -1)
let rivalFleeOverride = argument("--rival-flee", default: -1)
let rivalRadiusOverride = argument("--rival-radius", default: -1)
let rivalStandoffOverride = argument("--rival-standoff", default: -1)
let rivalGateOverride = argument("--rival-gate", default: -1)
let rivalRatioOverride = argument("--rival-ratio", default: -1)
let rivalSplitMinOverride = argument("--rival-splitmin", default: -1)
let rivalStartOverride = argument("--rival-start", default: -1)
// Falcon grab-budget override (tuning probe; <0 keeps the engine constant).
let falconBudgetOverride = argument("--falcon-budget", default: -1)
if falconBudgetOverride >= 0 { GameState.falconGrabPerThousand = falconBudgetOverride }

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

// MARK: - MU-P4 balance harness: Autoplayer vs tiered rival

/// One seeded day: the player (Autoplayer) against a tiered rival, mirroring
/// GameModel's loop (autoplayer action, rival action, applyTick). Day variety
/// comes from reseeding the region per day; winner is 0 player, 1 rival, -1
/// when no roost was claimed at dusk.
func runBalanceDay(region: Region, tier: RivalDifficulty, day: UInt64) -> String {
    let seeded = region.reseeded(day)
    var state = seeded.makeGameState()
    // Mirror GameModel: versus and rival modes suppress the R-5 auto-merge
    // (the day-start split starts both flocks coincident).
    state.versusMergeSuppressed = seeded.hasRival
    let starterActions: [GameAction]
    if rivalStartOverride >= 0 {
        // Tuning probe: start the rival at a different fraction of the
        // region's flock (--rival-start N = N birds per 1,000; <0 keeps the
        // region's rivalStartBirds).
        starterActions = seeded.hasRival
            ? [.spawnRival(ratio: Double(rivalStartOverride) / 1000.0)]
            : []
    } else {
        starterActions = RegionStarter.startingActions(for: seeded, difficulty: tier)
    }
    for action in starterActions {
        let (applied, _) = applyAction(action, to: state)
        state = applied
    }
    var player = Autoplayer()
    var rival = GentleRival(difficulty: tier)
    // Cadence overrides for tuning probes (--rival-forage/-flee/-radius/-standoff).
    if rivalForageOverride >= 0 { rival.forageInterval = rivalForageOverride }
    if rivalFleeOverride >= 0 { rival.fleeInterval = rivalFleeOverride }
    if rivalRadiusOverride >= 0 { rival.fleeRadius = rivalRadiusOverride }
    if rivalStandoffOverride >= 0 { rival.standoffDistance = rivalStandoffOverride }
    if rivalGateOverride >= 0 { rival.claimGate = rivalGateOverride }
    if rivalRatioOverride >= 0 { rival.contestRatio = rivalRatioOverride }
    if rivalSplitMinOverride >= 0 { rival.splitMinBirds = rivalSplitMinOverride }
    var rng = SeededRNG(seed: seeded.seed)

    var winner = -1
    var playerPeak = 0
    var rivalPeak = 0
    var playerDusk = -1
    var rivalDusk = -1
    var playerFalconLosses = 0
    var rivalFalconLosses = 0
    var playerRoosts = -1
    var rivalRoosts = -1
    var autoplayerUsTotal: UInt64 = 0
    var rivalUsTotal: UInt64 = 0
    let trace = balanceTrace > 0

    func flockCounts() -> (Int, Int) {
        var player = 0
        for assignment in state.subFlockAssignments where assignment == 0 { player += 1 }
        return (player, state.subFlockAssignments.count - player)
    }

    while state.tick < GameState.dayTicks {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let playerAction = player.action(for: state)
        autoplayerUsTotal &+= DispatchTime.now().uptimeNanoseconds &- t0
        if let playerAction {
            let (applied, _) = applyAction(playerAction, to: state)
            state = applied
        }
        let t1 = DispatchTime.now().uptimeNanoseconds
        let rivalAction = rival.action(for: state)
        rivalUsTotal &+= DispatchTime.now().uptimeNanoseconds &- t1
        if let rivalAction {
            let (applied, _) = applyAction(rivalAction, to: state)
            state = applied
        }
        let (next, events) = applyTick(to: state, rng: &rng)
        state = next
        for event in events {
            switch event {
            case .victory(let who):
                winner = who
            case .falcon(.diveResult(_, let flock, let hit, let kills)) where hit:
                if flock == 0 { playerFalconLosses += kills } else { rivalFalconLosses += kills }
            case .roost(.dayEnd(let p, let rv)):
                playerRoosts = p
                rivalRoosts = rv
            default:
                break
            }
            if balanceEvents > 0 {
                var line: String?
                switch event {
                case .energy(.drain): break
                case .energy(.feed(let sf, let amt, let f)): line = "t\(state.tick) feed sf\(sf) +\(amt) f\(f)"
                case .energy(.grow(let sf, let n)): line = "t\(state.tick) GROW sf\(sf) +\(n)"
                case .energy(.starve(let sf, let n)): line = "t\(state.tick) STARVE sf\(sf) -\(n)"
                case .falcon(.diveResult(let fi, let sf, let hit, let n)): line = "t\(state.tick) dive f\(fi) sf\(sf) \(hit ? "hit \(n)" : "miss")"
                case .split(let from, let into): line = "t\(state.tick) split \(from)->\(into)"
                case .merge(let into, let from): line = "t\(state.tick) merge \(from)->\(into)"
                case .birdCountChange(let d): line = "t\(state.tick) count \(d > 0 ? "+" : "")\(d)"
                case .roost(.claim(let r, let f)): line = "t\(state.tick) claim r\(r) sf\(f)"
                case .roost(.won(let r, let f)): line = "t\(state.tick) WON r\(r) sf\(f)"
                case .roost(.dayEnd(let p, let rv)):
                    line = "t\(state.tick) dayEnd p=\(p) r=\(rv)"
                    playerRoosts = p
                    rivalRoosts = rv
                case .roost(.soloDayEnd(let s, let t)): line = "t\(state.tick) soloDayEnd settled=\(s) target=\(t)"
                case .roost(.victory(let w)): line = "t\(state.tick) victory sf\(w)"
                case .condense(let sf, let active): line = "t\(state.tick) condense sf\(sf) \(active ? "on" : "off")"
                default: break
                }
                if let line { FileHandle.standardError.write(Data((line + "\n").utf8)) }
            }
        }
        if state.tick % 30 == 0 {
            let (playerCount, rivalCount) = flockCounts()
            playerPeak = max(playerPeak, playerCount)
            rivalPeak = max(rivalPeak, rivalCount)
            if state.tick >= GameState.duskStart && playerDusk < 0 {
                playerDusk = playerCount
                rivalDusk = rivalCount
            }
        }
        if trace && state.tick % balanceTrace == 0 {
            var rx = 0.0
            var ry = 0.0
            var rn = 0
            for i in state.subFlockAssignments.indices where state.subFlockAssignments[i] == 1 {
                rx += Double(state.birds.posX[i])
                ry += Double(state.birds.posY[i])
                rn += 1
            }
            let pathPts = state.leaderPaths.count > 1 ? state.leaderPaths[1].points.count : -1
            let rivalEnergy = state.energy.count > 1 ? state.energy[1] : -1
            let playerEnergy = state.energy.count > 0 ? state.energy[0] : -1
            let fieldBudgets = state.fields.map { "\($0.maxDepletion - $0.currentDepletion)" }.joined(separator: ",")
            var px = 0.0
            var py = 0.0
            var pn = 0
            for i in state.subFlockAssignments.indices where state.subFlockAssignments[i] == 0 {
                px += Double(state.birds.posX[i])
                py += Double(state.birds.posY[i])
                pn += 1
            }
            let lead = state.leaderPaths.first
            var falcons = ""
            for f in state.falcons {
                falcons += "F(\(f.currentX),\(f.currentY))d\(f.cooldown) "
            }
            var subCounts = ""
            var seen: [UInt8: Int] = [:]
            for a in state.subFlockAssignments { seen[a, default: 0] += 1 }
            for (k, v) in seen.sorted(by: { $0.key < $1.key }) { subCounts += "sf\(k)=\(v) " }
            let line = "t\(state.tick) p=\(flockCounts().0) pE=\(playerEnergy)"
                + " pC=(\(Int(px / Double(max(pn, 1)))),\(Int(py / Double(max(pn, 1)))))"
                + " L=(\(lead?.currentX ?? -1),\(lead?.currentY ?? -1))"
                + " f=[\(fieldBudgets)] r=\(rn) rE=\(rivalEnergy)"
                + " rC=(\(Int(rx / Double(max(rn, 1)))),\(Int(ry / Double(max(rn, 1)))))"
                + " \(falcons)\(subCounts)pts=\(pathPts)"
            FileHandle.standardError.write(Data((line + "\n").utf8))
        }
    }

    let (playerBirds, rivalBirds) = flockCounts()
    let ticks = String(state.tick)
    let tickCount = max(state.tick, 1)
    let autoplayerUs = String(Int(autoplayerUsTotal) / tickCount)
    let rivalUs = String(Int(rivalUsTotal) / tickCount)
    var row: [String] = []
    row.append(seeded.id)
    row.append(tierName(tier))
    row.append(String(day))
    row.append(String(winner))
    row.append(String(playerBirds))
    row.append(String(rivalBirds))
    row.append(String(playerPeak))
    row.append(String(rivalPeak))
    row.append(String(playerDusk))
    row.append(String(rivalDusk))
    row.append(String(playerFalconLosses))
    row.append(String(rivalFalconLosses))
    row.append(String(playerRoosts))
    row.append(String(rivalRoosts))
    row.append(autoplayerUs)
    row.append(rivalUs)
    row.append(ticks)
    return row.joined(separator: ",")
}

func tierName(_ tier: RivalDifficulty) -> String {
    switch tier {
    case .gentle: return "gentle"
    case .normal: return "normal"
    case .hard: return "hard"
    }
}

if let balanceTierName = balanceTier {
    let tier: RivalDifficulty
    switch balanceTierName {
    case "gentle": tier = .gentle
    case "normal": tier = .normal
    case "hard": tier = .hard
    default:
        FileHandle.standardError.write(Data("unknown tier \(balanceTierName)\n".utf8))
        exit(2)
    }
    let base = URL(fileURLWithPath: "Resources/Content/regions")
    let catalog = try RegionCatalog.load(from: base)
    let ids = balanceRegions.map { $0.split(separator: ",").map(String.init) } ?? catalog.ids
    let regions = ids.compactMap { catalog.region(id: $0) }
    precondition(regions.count == ids.count, "unknown region id in \(ids)")
    var rows = ["region,tier,day,winner,playerBirds,rivalBirds,playerPeak,rivalPeak,playerDusk,rivalDusk,"
        + "falconLossPlayer,falconLossRival,playerRoosts,rivalRoosts,autoplayerNsPerTick,rivalNsPerTick,ticks"]
    for region in regions {
        for day in 1...max(balanceDays, 1) {
            rows.append(runBalanceDay(region: region, tier: tier, day: UInt64(day)))
        }
        FileHandle.standardError.write(Data("done \(region.id) tier=\(balanceTierName)\n".utf8))
    }
    let csv = rows.joined(separator: "\n") + "\n"
    if let outPath = balanceOut {
        try csv.write(to: URL(fileURLWithPath: outPath), atomically: true, encoding: .utf8)
    } else {
        print(csv)
    }
    // Win-rate summary per region and overall.
    var perRegion: [String: (wins: Int, total: Int)] = [:]
    var totalWins = 0
    var totalDays = 0
    for row in rows.dropFirst() {
        let cols = row.split(separator: ",").map(String.init)
        guard cols.count >= 4 else { continue }
        let won = cols[3] == "0"
        perRegion[cols[0], default: (0, 0)].total += 1
        if won {
            perRegion[cols[0]]!.wins += 1
            totalWins += 1
        }
        totalDays += 1
    }
    for (id, tally) in perRegion.sorted(by: { $0.key < $1.key }) {
        let pct = Double(tally.wins) / Double(max(tally.total, 1)) * 100
        print(String(format: "%@ winRate=%.1f%% (%d/%d)", id, pct, tally.wins, tally.total))
    }
    let overall = Double(totalWins) / Double(max(totalDays, 1)) * 100
    print(String(format: "overall tier=%@ winRate=%.1f%% (%d/%d)", balanceTierName, overall, totalWins, totalDays))
    exit(0)
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
