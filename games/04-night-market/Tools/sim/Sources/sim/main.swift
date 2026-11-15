// Tools/sim — headless Night Market runner (S1.3, NM-P1.6).
//
// Plays full nights from a seed with a deterministic random-legal-move policy,
// prints per-night summaries with checkpoint hashes, checks the roadmap
// invariants (INV-1…INV-5), and can emit golden replay files (S1.4).
//
// Usage:
//   sim --seed 42 [--nights 1] [--invariants] [--golden-out DIR] [--quiet]
//   sim --invariant-sweep 500        (INV-1…INV-5 over N seeded nights)
//   sim --golden 10 --golden-out DIR (write 10 golden replays + expectations)

import Foundation
import NMCore
import NMAI

struct BotNightResult {
    let seed: UInt64
    let map: String
    let illegal: Int
    let served: Int
    let score: Int
    /// Hours after 18:00 when the bot went service-starved (no serve for a
    /// full in-game hour after the first serve); 12.0 = serving continued to
    /// dawn. This is the bot-collapse metric behind the §6 targets.
    let collapseHour: Double
    let firstOverflowTick: Int?
}

struct NightResult {
    let seed: UInt64
    let score: Int
    let served: Int
    let survived: Bool
    let finalHash: String
    let checkpointHashes: [UInt64]
    let overflowEnded: Bool
    let walkwayCount: Int
    let budgetUsed: Int
    let budgetTotal: Int
    let finalCustomers: Int
}

struct InvariantViolation: Error, CustomStringConvertible {
    let night: UInt64
    let tick: Int
    let rule: String
    var description: String { "INV violation night=\(night) tick=\(tick) rule=\(rule)" }
}

/// Deterministic random-legal-move policy.
final class Policy {
    var rng: SeededRNG
    let walkwayPlan: [Tile]

    init(seed: UInt64) {
        rng = SeededRNG(seed: seed ^ 0xABCD)
        // Deterministic opening: a straight walkway from gate 0 toward the plaza,
        // then up into the plaza.
        var plan: [Tile] = []
        for col in 0...12 { plan.append(Tile(col: col, row: 9)) }
        for row in [10, 11] { plan.append(Tile(col: 12, row: row)) }
        walkwayPlan = plan
    }

    /// Returns the action to take this tick, or nil.
    func nextAction(for state: GameState) -> Action? {
        // Early game: execute the walkway plan.
        if state.usedBudget < walkwayPlan.count, state.walkwayBudget >= walkwayPlan.count {
            let remaining = walkwayPlan.filter { !state.walkwayTiles.contains($0) }
            if !remaining.isEmpty {
                let batch = Array(remaining.prefix(6))
                return .paintWalkway(batch)
            }
        }

        // Random legal moves thereafter.
        if rng.next(upperBound: 30) != 0 { return nil }
        let roll = rng.next(upperBound: 10)
        switch roll {
        case 0...3:
            // Paint up to 3 random ground/plaza tiles within remaining budget.
            var candidates: [Tile] = []
            for row in 0..<state.grid.height {
                for col in 0..<state.grid.width {
                    let tile = Tile(col: col, row: row)
                    switch state.grid.tile(at: tile) {
                    case .ground, .plaza: candidates.append(tile)
                    case .water, .building: break
                    }
                }
            }
            let unpainted = candidates.filter { !state.walkwayTiles.contains($0) }
            guard !unpainted.isEmpty, state.usedBudget < state.walkwayBudget else { return nil }
            var picks: [Tile] = []
            let want = min(3, state.walkwayBudget - state.usedBudget)
            for _ in 0..<want {
                if let tile = rng.randomElement(from: unpainted), !picks.contains(tile) {
                    picks.append(tile)
                }
            }
            return picks.isEmpty ? nil : .paintWalkway(picks)
        case 4...6:
            // Place a fixture on a traversable tile.
            let kinds: [FixtureKind] = [.awning, .busker(radius: 2), .seat(count: 3), .bridge(length: 3)]
            guard let kind = rng.randomElement(from: kinds) else { return nil }
            var traversable: [Tile] = []
            for row in 0..<state.grid.height {
                for col in 0..<state.grid.width {
                    let tile = Tile(col: col, row: row)
                    if state.isTraversable(tile) { traversable.append(tile) }
                }
            }
            guard let tile = rng.randomElement(from: traversable) else { return nil }
            return .placeFixture(kind, tile)
        case 7...8:
            // Move a random fixture.
            guard let fixture = rng.randomElement(from: state.fixtures) else { return nil }
            var traversable: [Tile] = []
            for row in 0..<state.grid.height {
                for col in 0..<state.grid.width {
                    let tile = Tile(col: col, row: row)
                    if state.isTraversable(tile) { traversable.append(tile) }
                }
            }
            guard let tile = rng.randomElement(from: traversable) else { return nil }
            return .moveFixture(fixture.id, tile)
        default:
            // Erase occasionally, but only if the night stays connected: dry-run
            // on a copy and require every open gate to still reach every color.
            // Candidates are sorted: Set iteration order must never reach the
            // RNG (it differs across processes and breaks hash parity).
            var eraseRng = rng
            let candidates = Array(state.walkwayTiles).sorted { ($0.col, $0.row) < ($1.col, $1.row) }
            guard let tile = eraseRng.randomElement(from: candidates),
                let (trial, _) = try? Reducer.apply(.eraseWalkway([tile]), to: state, rng: &eraseRng)
            else { return nil }
            let checked = FlowFields.ensureCurrent(for: trial)
            let connected = state.gates.allSatisfy { gate in
                gate.isOpen
                    ? StallColor.allCases.allSatisfy { color in
                        checked.pathFields.steps(toColor: color, at: gate.position) != nil
                    } : true
            }
            guard connected else { return nil }
            return .eraseWalkway([tile])
        }
    }
}

func runNight(seed: UInt64, checkInvariants: Bool, goldenActions: inout [TimedAction]) throws -> NightResult {
    var state = GameState.initial(seed: seed)
    var rng = SeededRNG(seed: seed)
    let policy = Policy(seed: seed)

    var servedCount = 0
    var lastScore = 0
    var survived = false
    var overflowEnded = false
    var checkpoints: [UInt64] = []
    var tick = 0

    while tick < 21_600 {
        // Player action this tick (before the tick advances, matching replay timing).
        if let action = policy.nextAction(for: state) {
            do {
                let (next, _) = try Reducer.apply(action, to: state, rng: &rng)
                state = next
                // Record only applied actions so replays re-apply exactly what
                // happened; failed attempts are absent from golden files.
                goldenActions.append(TimedAction(tick: tick, action: action))
            } catch {
                // Illegal under current state — policy just skips.
            }
        }

        let (next, events) = Tick.advance(state: state, rng: &rng)
        state = next
        tick = state.clock.tick

        for event in events {
            switch event {
            case .served:
                servedCount += 1
            case .nightEnded(_, let didSurvive):
                survived = didSurvive
                if !didSurvive { overflowEnded = true }
            default:
                break
            }
        }

        // INV-3: score non-decreasing.
        if checkInvariants {
            if state.score < lastScore {
                throw InvariantViolation(night: seed, tick: tick, rule: "INV-3 score decreased")
            }
            lastScore = state.score
            // INV-1: budget.
            if state.usedBudget > state.walkwayBudget {
                throw InvariantViolation(night: seed, tick: tick, rule: "INV-1 budget exceeded")
            }
            // INV-2: traversable positions, no double-queuing.
            for customer in state.customers where !state.isTraversable(state.tileOf(customer.position)) {
                if ProcessInfo.processInfo.environment["NM_SIM_TRACE"] != nil {
                    let tile = state.tileOf(customer.position)
                    let pos = "\(customer.position.x),\(customer.position.y)"
                    FileHandle.standardError.write(
                        Data(
                            ("OFF t=\(tick) id=\(customer.id) state=\(customer.state) pos=\(pos)"
                                + " tile=\(tile.col),\(tile.row) type=\(state.grid.tile(at: tile))"
                                + " walkway=\(state.walkwayTiles.contains(tile)) bridge=\(state.bridgeTiles.contains(tile))"
                                + " seatTarget=\(customer.targetSeatID ?? -1)\n").utf8))
                    let fx = state.fixtures.map { fixture in
                        "\(fixture.id):\(fixture.kind)@\(fixture.position.col),\(fixture.position.row)"
                    }.sorted().joined(separator: " ")
                    FileHandle.standardError.write(Data(("FIXTURES \(fx)\n").utf8))
                }
                throw InvariantViolation(night: seed, tick: tick, rule: "INV-2 customer off traversable")
            }
            var queueSeen: Set<CustomerID> = []
            for stall in state.stalls {
                for id in stall.queue {
                    if queueSeen.contains(id) {
                        throw InvariantViolation(night: seed, tick: tick, rule: "INV-2 double queue")
                    }
                    queueSeen.insert(id)
                }
            }
        }

        // Checkpoint hashes every 1,800 ticks (INV-5 evidence). Recorded
        // before the boundary upgrade choice so replays (which hash before
        // applying recorded actions) reproduce the same snapshots.
        if state.clock.tick % 1_800 == 0, state.clock.tick > 0 {
            checkpoints.append(StateHash.digest(state))
            if ProcessInfo.processInfo.environment["NM_SIM_PARTS"] != nil {
                FileHandle.standardError.write(Data(("CKPT \(simParts(state))\n").utf8))
            }
        }

        // Hour boundary: choose an upgrade (first offered) to keep flowing.
        if state.isPaused, !state.pendingOffers.isEmpty {
            let offer = state.pendingOffers[0]
            let (next, _) = try Reducer.apply(.chooseUpgrade(offer.id), to: state, rng: &rng)
            state = next
            goldenActions.append(TimedAction(tick: tick, action: .chooseUpgrade(offer.id)))
        }

        if ProcessInfo.processInfo.environment["NM_SIM_PARTS"] != nil {
            FileHandle.standardError.write(Data(("T \(simDetailed(state))\n").utf8))
        }
        if ProcessInfo.processInfo.environment["NM_SIM_DEBUG"] != nil, state.clock.tick % 600 == 0 {
            var states: [String: Int] = [:]
            for c in state.customers {
                let key = "\(c.state)"
                states[key, default: 0] += 1
            }
            let histogram = states.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            print("DBG \(simParts(state)) \(histogram)")
        }
    }

    return NightResult(
        seed: seed,
        score: state.score,
        served: servedCount,
        survived: survived,
        finalHash: StateHash.hex(state),
        checkpointHashes: checkpoints,
        overflowEnded: overflowEnded,
        walkwayCount: state.walkwayTiles.count,
        budgetUsed: state.usedBudget,
        budgetTotal: state.walkwayBudget,
        finalCustomers: state.customers.count
    )
}

/// Plays one full night with the AutoPlanner (NM-P4.1). Mirrors runNight's
/// driver timing: at most one player action per tick, applied before the tick
/// advances. Counts reducer throws as illegal actions (G4 requires zero).
func runBotNight(seed: UInt64, map: MapDefinition, spawnScale: Double = 1.0) throws -> BotNightResult {
    var state = try GameState.initial(seed: seed, map: map)
    if spawnScale != 1.0 {
        state.spawnRates = Spawner.hourlyRates.map { max(1, Int((Double($0) * spawnScale).rounded())) }
    }
    var rng = SeededRNG(seed: seed)
    let planner = AutoPlanner()
    var illegal = 0
    var servedCount = 0
    var firstServeTick: Int?
    var lastServeTick = 0
    var firstOverflowTick: Int?

    var lastEvents: [Event] = []
    while !state.clock.isNightOver {
        if let action = planner.nextAction(for: state, events: lastEvents) {
            do {
                let (next, _) = try Reducer.apply(action, to: state, rng: &rng)
                state = next
            } catch {
                illegal += 1
            }
        }
        let (next, events) = Tick.advance(state: state, rng: &rng)
        state = next
        lastEvents = events
        for event in events {
            switch event {
            case .served:
                servedCount += 1
                if firstServeTick == nil { firstServeTick = state.clock.tick }
                lastServeTick = state.clock.tick
            case .overflowWarning:
                if firstOverflowTick == nil { firstOverflowTick = state.clock.tick }
            case .nightEnded:
                break
            default:
                break
            }
        }
    }

    // Collapse metric (documented in docs/BALANCE.md): the first tick after
    // serving began where a full in-game hour passed with no serve; a bot
    // that never serves at all collapses at hour 0.
    var collapseHour = 12.0
    if let first = firstServeTick {
        if state.clock.tick - lastServeTick >= 1800 {
            collapseHour = Double(max(first, lastServeTick)) / 1800.0
        }
    } else {
        collapseHour = 0
    }
    return BotNightResult(
        seed: seed, map: map.id, illegal: illegal, served: servedCount, score: state.score,
        collapseHour: collapseHour, firstOverflowTick: firstOverflowTick
    )
}

/// Zero-padded lowercase hex (local to sim; independent of NMCore string APIs).
func paddedHex(_ value: UInt64) -> String {
    var v = value
    var chars: [Character] = []
    let digits: [Character] = Array("0123456789abcdef")
    for _ in 0..<16 {
        chars.append(digits[Int(v & 0xF)])
        v >>= 4
    }
    return String(chars.reversed())
}

/// Compact one-line state summary shared by the diagnostic dumps.
func simParts(_ state: GameState) -> String {
    "t=\(state.clock.tick) score=\(state.score) used=\(state.usedBudget)"
        + " walk=\(state.walkwayTiles.count) cust=\(state.customers.count) fx=\(state.fixtures.count)"
        + " nc=\(state.nextCustomerID) nf=\(state.nextFixtureID) paused=\(state.isPaused)"
        + " offers=\(state.pendingOffers.map(\.id).joined(separator: "|"))"
}

/// Detailed per-tick dump: fixture positions and the sorted walkway tile list.
func simDetailed(_ state: GameState) -> String {
    let fx = state.fixtures.map { "\($0.id)@\($0.position.col),\($0.position.row)" }.sorted().joined(separator: ";")
    let walk = state.walkwayTiles.map { "\($0.col),\($0.row)" }.sorted().joined(separator: ";")
    return simParts(state) + " fxlist=\(fx) walklist=\(walk)"
}

func argumentValue(_ flag: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func hasFlag(_ flag: String) -> Bool {
    CommandLine.arguments.contains(flag)
}

// MARK: - Entry point

var exitCode = 0

if let mapDir = argumentValue("--emit-maps") {
    // P3 content authoring: write map JSON (base64-rle tiles) for the
    // three G3 maps. Taipei mirrors the built-in GameState.initial layout
    // so the round-trip test can prove byte-identical states.
    func tileBytes(_ tiles: [TileType]) -> [UInt8] {
        func byte(_ t: TileType) -> UInt8 {
            switch t {
            case .ground: return 0
            case .plaza: return 1
            case .water(.canal): return 2
            case .building: return 3
            }
        }
        var rle: [UInt8] = []
        var runValue = byte(tiles[0])
        var runCount: UInt8 = 0
        for t in tiles {
            let v = byte(t)
            if v == runValue, runCount < 255 {
                runCount += 1
            } else {
                rle.append(runCount)
                rle.append(runValue)
                runValue = v
                runCount = 1
            }
        }
        rle.append(runCount)
        rle.append(runValue)
        return rle
    }
    struct MapSpec {
        let name: String
        let width: Int
        let height: Int
        let tileFn: (Int, Int) -> TileType
        let gates: [[Int]]
        let gateOpenTicks: [Int]
        let stallZones: [[Int]]
        let stallStride: Int
        let lanternSpots: [[Int]]
        let palette: String
        /// Per-color demand weights (P3: distinct per map; keyed by debug name).
        var zoneWeights: [String: Int] = [:]
    }

    func emit(_ spec: MapSpec) throws {
        let name = spec.name
        let width = spec.width
        let height = spec.height
        let tileFn = spec.tileFn
        var tiles: [TileType] = []
        for row in 0..<height {
            for col in 0..<width { tiles.append(tileFn(col, row)) }
        }
        let zones: [String: [[Int]]] = [
            "noodles": spec.stallZones, "tea": spec.stallZones, "skewers": spec.stallZones,
            "dumplings": spec.stallZones, "sweets": spec.stallZones, "seafood": spec.stallZones,
        ]
        let json: [String: Any] = [
            "id": name.lowercased(), "name": name,
            "size": [width, height],
            "tiles": Data(tileBytes(tiles)).base64EncodedString(),
            "gates": spec.gates, "gateOpenTicks": spec.gateOpenTicks,
            "zones": zones, "stallStride": spec.stallStride,
            "lanternSpots": spec.lanternSpots,
            "schedule": "schedule_standard", "palette": spec.palette,
            "zoneWeights": spec.zoneWeights,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(
            to: URL(fileURLWithPath: mapDir).appendingPathComponent("\(name.lowercased()).json"))
        print("EMIT \(name.lowercased()).json tiles=\(tiles.count)")
    }

    do {
        // Taipei: byte-identical to the built-in GameState.initial layout
        // (canals painted AFTER the plaza so they cut through it — ADR-0008).
        try emit(
            MapSpec(
                name: "Taipei", width: 32, height: 20,
                tileFn: { col, row in
                    if row == 7 || row == 12, col >= 14, col < 17 { return .water(.canal) }
                    if row >= 8, row < 13, col >= 12, col < 20 { return .plaza }
                    return .ground
                },
                gates: [[0, 9], [0, 10]], gateOpenTicks: [0, 5400],
                stallZones: [[13, 9, 5, 3]], stallStride: 2,
                lanternSpots: [[14, 10], [17, 10]], palette: "neon_warm"))
        // Bangkok: a four-wide river down the middle; plazas on both banks;
        // three gates; stalls along the banks (bridge crossing required).
        try emit(
            MapSpec(
                name: "Bangkok", width: 32, height: 20,
                tileFn: { col, row in
                    if col >= 14, col <= 17 { return .water(.canal) }
                    if row >= 8, row < 12, col >= 8, col < 13 { return .plaza }
                    if row >= 8, row < 12, col >= 19, col < 24 { return .plaza }
                    return .ground
                },
                gates: [[0, 9], [31, 10], [18, 0]], gateOpenTicks: [0, 3600, 7200],
                stallZones: [[8, 8, 6, 4], [19, 8, 5, 4]], stallStride: 1,
                lanternSpots: [[10, 9], [21, 9]], palette: "river_gold",
                zoneWeights: ["seafood": 3, "skewers": 2]))
        // Marrakesh: building blocks leave one-wide alleys between them.
        try emit(
            MapSpec(
                name: "Marrakesh", width: 32, height: 20,
                tileFn: { col, row in
                    if row >= 4, row < 16, col % 5 == 4, row % 4 != 3 { return .building }
                    if col >= 12, col < 20, row >= 7, row < 13 { return .plaza }
                    return .ground
                },
                gates: [[0, 9], [0, 10]], gateOpenTicks: [0, 4500],
                stallZones: [[12, 7, 8, 6]], stallStride: 1,
                lanternSpots: [[13, 9], [18, 9]], palette: "earth_lantern",
                zoneWeights: ["sweets": 3, "tea": 2]))
        // Oaxaca: one huge open plaza ringed by a wide ground apron; gates on
        // three edges open early; long sightlines make lanterns matter less
        // than raw walkway reach.
        try emit(
            MapSpec(
                name: "Oaxaca", width: 32, height: 20,
                tileFn: { col, row in
                    if col >= 10, col < 22, row >= 6, row < 14 { return .plaza }
                    if col == 8 || col == 23, row >= 5, row < 15 { return .building }
                    return .ground
                },
                gates: [[0, 9], [0, 10], [31, 9]], gateOpenTicks: [0, 2700, 5400],
                stallZones: [[10, 6, 12, 8]], stallStride: 1,
                lanternSpots: [[13, 9], [18, 9]], palette: "earth_lantern",
                zoneWeights: ["dumplings": 3, "sweets": 2]))
        // Seoul: two canal arms pinching a central market island; crossings
        // exist only where bridges span, so walkway planning is tight.
        try emit(
            MapSpec(
                name: "Seoul", width: 32, height: 20,
                tileFn: { col, row in
                    if row == 5 || row == 6, col >= 6, col < 26 { return .water(.canal) }
                    if row == 13 || row == 14, col >= 6, col < 26 { return .water(.canal) }
                    if col >= 13, col < 19, row >= 8, row < 12 { return .plaza }
                    return .ground
                },
                gates: [[2, 9], [29, 10], [15, 0]], gateOpenTicks: [0, 3600, 7200],
                stallZones: [[12, 8, 8, 4]], stallStride: 1,
                lanternSpots: [[14, 9], [17, 10]], palette: "river_gold",
                zoneWeights: ["skewers": 3, "noodles": 2]))
        // Istanbul: a covered bazaar grid — dense building blocks with
        // two-wide lanes and a small central court; many corners (R-9).
        try emit(
            MapSpec(
                name: "Istanbul", width: 32, height: 20,
                tileFn: { col, row in
                    if row >= 3, row < 17, col >= 5, col < 27 {
                        let inBlockRow = row % 4 == 0 || row % 4 == 1
                        let inBlockCol = col % 6 == 1 || col % 6 == 2
                        if inBlockRow && inBlockCol { return .building }
                    }
                    if col >= 14, col < 18, row >= 8, row < 12 { return .plaza }
                    return .ground
                },
                gates: [[0, 9], [0, 10], [31, 9], [31, 10]], gateOpenTicks: [0, 2700, 5400, 8100],
                stallZones: [[6, 3, 20, 14]], stallStride: 1,
                lanternSpots: [[15, 9], [16, 10]], palette: "earth_lantern",
                zoneWeights: ["tea": 3, "sweets": 2]))
    } catch {
        print("EMIT FAILED: \(error)")
        exitCode = 1
    }
} else if let tuneNights = argumentValue("--tune") {
    // DirectorTuner (NM-P4.1): sweep the spawn ramp scale, evaluate the §6
    // targets, and write docs/BALANCE.md with the recommended ramp.
    let nights = Int(tuneNights) ?? 100
    let mapsDir = argumentValue("--maps") ?? "Resources/Content/maps"
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(mapsDir)/taipei.json"))
        let map = try JSONDecoder().decode(MapDefinition.self, from: data)
        let dateStamp = ISO8601DateFormatter().string(from: Date())
        var lines: [String] = []
        lines.append("# Night Market Balance Report")
        lines.append("")
        lines.append("_Generated by `Tools/sim --tune` (DirectorTuner), \(dateStamp). "
            + "Collapse hour = the first in-game hour (after the first serve) where a full hour "
            + "passes with no serve; 12.00 = serving continued to dawn._")
        lines.append("")
        lines.append("## §6 targets (AutoPlanner bot)")
        lines.append("- median collapse hour in [1.00, 3.00]")
        lines.append("- nights serving to dawn ≤ 10%")
        lines.append("- first overflow before 20:00 in ≤ 5% of nights")
        lines.append("")
        lines.append("## Sweep (taipei, \(nights) seeded nights per point)")
        lines.append("")
        lines.append("| spawn scale | median collapse | dawn-serving | overflow < 20:00 | served/night |")
        lines.append("| --- | --- | --- | --- | --- |")
        var best: (scale: Double, median: Double, dawn: Int, early: Int)?
        for scale in [0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6, 1.8, 2.0] {
            var collapses: [Double] = []
            var dawn = 0
            var early = 0
            var servedTotal = 0
            for index in 0..<nights {
                let result = try runBotNight(seed: UInt64(5000 + index), map: map, spawnScale: scale)
                collapses.append(result.collapseHour)
                if result.collapseHour >= 12.0 { dawn += 1 }
                if let tick = result.firstOverflowTick, tick < 3600 { early += 1 }
                servedTotal += result.served
            }
            collapses.sort()
            let median = collapses[collapses.count / 2]
            lines.append(
                String(
                    format: "| %.2f | %.2f | %d/%d | %d/%d | %.0f |", scale, median, dawn, nights,
                    early, nights, Double(servedTotal) / Double(nights)
                )
            )
            let fits = (1.0...3.0).contains(median) && Double(dawn) <= Double(nights) * 0.10
                && Double(early) <= Double(nights) * 0.05
            if fits, best == nil { best = (scale, median, dawn, early) }
        }
        lines.append("")
        if let best {
            let rates = Spawner.hourlyRates.map { max(1, Int((Double($0) * best.scale).rounded())) }
            lines.append("## Recommended ramp")
            lines.append("")
            lines.append("Scale **\(String(format: "%.2f", best.scale))** is the smallest swept scale meeting all three targets.")
            lines.append("")
            lines.append("Recommended `spawnsPerHour`: **\(rates)**")
            lines.append("")
            lines.append("Adopting it means updating `Resources/Content/schedule_standard.json` and "
                + "`Spawner.hourlyRates` together, regenerating the goldens, and recording an ADR "
                + "that cites this sweep.")
        } else {
            lines.append("## Recommended ramp")
            lines.append("")
            lines.append("No swept scale met all three targets; keep the default ramp and record the "
                + "out-of-target observations in a tuning ADR.")
        }
        let out = lines.joined(separator: "\n") + "\n"
        try out.write(toFile: "docs/BALANCE.md", atomically: true, encoding: .utf8)
        print(out)
        print("TUNE OK (docs/BALANCE.md written)")
    } catch {
        print("TUNE FAILED: \(error)")
        exitCode = 1
    }
} else if let nightsArg = argumentValue("--autopilot") {
    // G4: AutoPlanner over the content maps; zero illegal actions required.
    let nights = Int(nightsArg) ?? 1000
    let mapsDir = argumentValue("--maps") ?? "Resources/Content/maps"
    let spawnScale = Double(argumentValue("--spawn-scale") ?? "") ?? 1.0
    do {
        var totalIllegal = 0
        let files = try FileManager.default.contentsOfDirectory(atPath: mapsDir).filter { $0.hasSuffix(".json") }.sorted()
        for file in files {
            let data = try Data(contentsOf: URL(fileURLWithPath: "\(mapsDir)/\(file)"))
            let map = try JSONDecoder().decode(MapDefinition.self, from: data)
            var collapses: [Double] = []
            var dawnServing = 0
            var earlyOverflow = 0
            var overflowSeen = 0
            var servedTotal = 0
            for index in 0..<nights {
                let result = try runBotNight(seed: UInt64(1000 + index), map: map, spawnScale: spawnScale)
                totalIllegal += result.illegal
                collapses.append(result.collapseHour)
                if result.collapseHour >= 12.0 { dawnServing += 1 }
                if let tick = result.firstOverflowTick {
                    overflowSeen += 1
                    if tick < 3600 { earlyOverflow += 1 }
                }
                servedTotal += result.served
            }
            collapses.sort()
            let median = collapses.isEmpty ? 0 : collapses[collapses.count / 2]
            print(
                "AUTOPILOT map=\(map.id) nights=\(nights) illegal=\(totalIllegal) "
                    + "medianCollapseHour=\(String(format: "%.2f", median)) "
                    + "servedToDawn=\(dawnServing)/\(nights) "
                    + "firstOverflowBefore2000=\(earlyOverflow)/\(overflowSeen) servedTotal=\(servedTotal)"
            )
        }
        if totalIllegal > 0 {
            print("AUTOPILOT FAILED: \(totalIllegal) illegal actions")
            exitCode = 1
        } else {
            print("AUTOPILOT OK illegal=0 across \(files.count) maps × \(nights) nights")
        }
    } catch {
        print("AUTOPILOT FAILED: \(error)")
        exitCode = 1
    }
} else if let sweep = argumentValue("--invariant-sweep") {
    // INV-1…INV-5 over N seeded nights.
    let nights = Int(sweep) ?? 500
    var servedTotal = 0
    var survivedCount = 0
    do {
        for index in 0..<nights {
            var unused: [TimedAction] = []
            let result = try runNight(seed: UInt64(1000 + index), checkInvariants: true, goldenActions: &unused)
            servedTotal += result.served
            if result.survived { survivedCount += 1 }
            if index % 50 == 0 {
                print(
                    "NIGHT \(index + 1)/\(nights) seed=\(result.seed) score=\(result.score) survived=\(result.survived)"
                )
            }
        }
        print("INVARIANT_SWEEP OK nights=\(nights) servedTotal=\(servedTotal) survived=\(survivedCount)")
    } catch let violation as InvariantViolation {
        print("INVARIANT_SWEEP FAILED: \(violation)")
        exitCode = 1
    }
} else if let goldenCount = argumentValue("--golden"), let outDir = argumentValue("--golden-out") {
    // S1.4: write N golden replays (Codable ReplayData) + expectation files.
    struct Expectations: Codable {
        let finalHash: String
        let checkpoints: [String]
    }
    let count = Int(goldenCount) ?? 10
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for index in 0..<count {
        let seed = UInt64(42 + index * 7)
        var actions: [TimedAction] = []
        let result = try runNight(seed: seed, checkInvariants: true, goldenActions: &actions)
        let replay = ReplayData(seed: seed, contentVersion: "0.0.0", actions: actions)
        let replayData = try encoder.encode(replay)
        let expectations = Expectations(
            finalHash: result.finalHash,
            checkpoints: result.checkpointHashes.map(paddedHex)
        )
        let expectationData = try encoder.encode(expectations)
        let base = "\(outDir)/golden-\(String(format: "%02d", index + 1))"
        try replayData.write(to: URL(fileURLWithPath: base + ".json"))
        try expectationData.write(to: URL(fileURLWithPath: base + ".expected.json"))
        print("GOLDEN \(base).json seed=\(seed) finalHash=\(result.finalHash) actions=\(actions.count)")
    }
} else {
    // Plain runs.
    let seed = UInt64(argumentValue("--seed") ?? "42") ?? 42
    let nights = Int(argumentValue("--nights") ?? "1") ?? 1
    let quiet = hasFlag("--quiet")
    for index in 0..<nights {
        var unused: [TimedAction] = []
        let result = try runNight(
            seed: seed + UInt64(index * 13), checkInvariants: hasFlag("--invariants"), goldenActions: &unused)
        if !quiet {
            print(
                "NIGHT seed=\(result.seed) score=\(result.score) served=\(result.served) survived=\(result.survived) overflowEnded=\(result.overflowEnded) hash=\(result.finalHash)"
            )
            print(
                "STATE walkways=\(result.walkwayCount) budgetUsed=\(result.budgetUsed)/\(result.budgetTotal) customers=\(result.finalCustomers)"
            )
            print("CHECKPOINTS \(result.checkpointHashes.map(paddedHex).joined(separator: ","))")
        }
    }
}

if exitCode != 0 {
    exit(Int32(exitCode))
}
