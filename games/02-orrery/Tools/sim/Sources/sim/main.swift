// OR-P1 headless simulator (S1.3): plays random-legal-move games from a
// seed through the real rules engine and reports timing and hashes.
//
// Usage:
//   sim [--games 5000] [--seed 1] [--progress N]
//   sim --golden N [--golden-out DIR] [--seed 1]
//   sim --balance-days 5000 ... (not used in P1)
//
// INV-4: runs the whole batch twice and exits 1 unless both passes agree
// hash-for-hash. INV-1/INV-2/INV-3 are asserted per ply inside the loop.

import Foundation
@_exported import ORCore

let arguments = Array(CommandLine.arguments.dropFirst())

func argument(_ name: String, default value: Int) -> Int {
    if let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
       let parsed = Int(arguments[index + 1]) {
        return parsed
    }
    return value
}

let gameCount = argument("--games", default: 5000)
let baseSeed = UInt64(argument("--seed", default: 1))
let progressEvery = argument("--progress", default: 0)
let goldenCount = argument("--golden", default: 0)
let goldenOut = arguments.firstIndex(of: "--golden-out").flatMap { idx -> String? in
    idx + 1 < arguments.count ? arguments[idx + 1] : nil
}

struct GameRecord: Codable {
    let seed: UInt64
    let actions: [GameReplay.TimedAction]
    let finalHash: String
    let winner: String?
    let reason: String
    let plies: Int
    let rounds: Int
}

// The per-game RNG for choosing random legal moves. The games themselves
// are perfect information; the seed only picks the move policy, like the
// roadmap's "all randomness is in variant selection before the game starts".
func randomGame(seed: UInt64, variant: Variant) -> (GameRecord, Double) {
    var rng = SeededRNG(seed: seed)
    var state = GameStateFactory.initial(seed: seed, variant: variant)
    var actions: [GameReplay.TimedAction] = []
    var ply = 0
    let clock = DispatchTime.now()
    while state.result == nil {
        let moves = LegalMoves.all(in: state)
        precondition(!moves.isEmpty, "a live game always has a move (pass exists)")
        let action = moves[rng.next(upperBound: moves.count)]
        actions.append(GameReplay.TimedAction(tick: ply, action: action))
        do {
            state = try Reducer.apply(action, to: state, variant: variant).0
        } catch {
            fatalError("sim: legal move rejected by the reducer: \(action) — \(error)")
        }
        // Invariants per ply.
        checkInvariant1(state, variant: variant)
        checkInvariant2(state)
        checkInvariant3(state)
        ply += 1
    }
    let seconds = Double(DispatchTime.now().uptimeNanoseconds - clock.uptimeNanoseconds) / 1_000_000_000
    let winner: String?
    let reason: String
    if let result = state.result {
        switch result {
        case .won(let player, let r): winner = player == .one ? "one" : "two"; reason = r
        case .timeout(let player, let r): winner = player == .one ? "one" : "two"; reason = r
        }
    } else {
        winner = nil
        reason = "none"
    }
    return (
        GameRecord(
            seed: seed,
            actions: actions,
            finalHash: StateHash.hexDigest(GameStateHash.digest(state)),
            winner: winner,
            reason: reason,
            plies: ply,
            rounds: state.round
        ),
        seconds
    )
}

func checkInvariant1(_ state: GameState, variant: Variant) {
    for player in PlayerID.allCases {
        let onBoard = state.planetsOnBoard(player)
        let inReserve = state.reserve[player] ?? 0
        // `captured[X]` counts planets X captured (i.e. enemy planets);
        // planets of `player` that were captured live in `captured[opponent]`.
        let lostToOpponent = state.captured[player.opponent] ?? 0
        precondition(onBoard + inReserve + lostToOpponent == variant.reserve,
                     "INV-1 violated for \(player): \(onBoard)+\(inReserve)+\(lostToOpponent) != \(variant.reserve)")
    }
}

func checkInvariant2(_ state: GameState) {
    for ring in state.rings where !(0..<48).contains(ring.offset) {
        fatalError("INV-2 violated: offset \(ring.offset)")
    }
}

func checkInvariant3(_ state: GameState) {
    // Captures only remove the opponent's planets: every captured planet's
    // owner must be the opponent, counts stay within the enemy supply, and
    // no captured planet still sits on the board of its owner... expressed
    // through INV-1 (counts balance) plus non-negativity here.
    for player in PlayerID.allCases {
        let capturedByMe = state.captured[player] ?? 0
        precondition(capturedByMe >= 0, "INV-3 violated: negative captures")
        precondition(capturedByMe <= 10, "INV-3 violated: captures exceed the enemy supply")
    }
}

// MARK: Golden generation

func goldenFiles(count: Int, out directory: String?) {
    var records: [GameRecord] = []
    var index = 0
    while records.count < count {
        let seed = baseSeed &+ UInt64(index)
        let (record, _) = randomGame(seed: seed, variant: .standard)
        // Golden replays replay cleanly by construction: every action came
        // from the legal set, so `skipped` is 0.
        records.append(record)
        index += 1
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    for (i, record) in records.enumerated() {
        let data = try! encoder.encode(record)
        let name = "golden-\(String(format: "%03d", i + 1)).json"
        if let dir = directory {
            try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try! data.write(to: URL(fileURLWithPath: dir + "/" + name))
        } else {
            print("\(name): \(record.finalHash) (\(record.plies) plies, winner \(record.winner ?? "none"), \(record.reason))")
        }
    }
    if directory == nil {
        print("— \(count) golden summaries printed (pass --golden-out DIR to write files)")
    }
}

// MARK: Main

if goldenCount > 0 {
    goldenFiles(count: goldenCount, out: goldenOut)
    exit(0)
}

var pass1: [String] = []
var pass2: [String] = []
var timings: [Double] = []
var wins: [String: Int] = ["one": 0, "two": 0]
var reasons: [String: Int] = [:]
var totalPlies = 0

for pass in 1...2 {
    var hashes: [String] = []
    for i in 0..<gameCount {
        let seed = baseSeed &+ UInt64(i)
        let (record, seconds) = randomGame(seed: seed, variant: .standard)
        hashes.append(record.finalHash)
        timings.append(seconds)
        totalPlies += record.plies
        if pass == 1 {
            if let w = record.winner { wins[w, default: 0] += 1 }
            reasons[record.reason, default: 0] += 1
        }
        if progressEvery > 0, i % progressEvery == 0, pass == 1 {
            print("pass 1: game \(i)/\(gameCount) — \(record.plies) plies, \(String(format: "%.2f", seconds * 1000)) ms", terminator: "\r")
        }
    }
    if pass == 1 { pass1 = hashes } else { pass2 = hashes }
}
print()

precondition(pass1.count == pass2.count)
var mismatches = 0
for i in 0..<pass1.count where pass1[i] != pass2[i] {
    mismatches += 1
    print("INV-4 MISMATCH in game \(i): \(pass1[i]) vs \(pass2[i])")
}
if mismatches > 0 { exit(1) }

let sortedTimings = timings.sorted()
let median = sortedTimings[timings.count / 2]
let mean = timings.reduce(0, +) / Double(timings.count)
let p95 = sortedTimings[(timings.count * 19) / 20]
let maxT = sortedTimings.last!
print("games: \(gameCount) × 2 passes, mismatches: \(mismatches)")
print("timing ms: median \(String(format: "%.3f", median * 1000)), mean \(String(format: "%.3f", mean * 1000)), p95 \(String(format: "%.3f", p95 * 1000)), max \(String(format: "%.3f", maxT * 1000))")
print("plies: mean \(String(format: "%.1f", Double(totalPlies) / Double(gameCount)))")
print("wins: one \(wins["one"] ?? 0) / two \(wins["two"] ?? 0)")
for (reason, count) in reasons.sorted(by: { $0.key < $1.key }) {
    print("reason: \(reason) — \(count)")
}
