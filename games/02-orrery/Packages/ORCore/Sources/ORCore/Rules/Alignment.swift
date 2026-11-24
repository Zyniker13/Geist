/// Alignment and capture (R-9…R-14).
///
/// A line (R-9) is the unordered pair of opposite angles `{a, a+24}`, indexed
/// by its smaller endpoint `a` (0…23). A planet's signed position on a line
/// (R-10) is `+ring` at angle `a` or `−ring` at angle `a+24` — the sign says
/// which side of the sun, the magnitude which ring.
public enum Alignment {
    /// All 24 line indices, in canonical order.
    public static let allLines: ClosedRange<Int> = 0...23

    /// Signed positions of every planet of `player` on every line.
    /// Returns line → sorted signed positions (all nonzero).
    public static func signedPositions(of player: PlayerID, in state: GameState)
        -> [Int: [Int]]
    {
        var result: [Int: [Int]] = [:]
        for planet in state.planets(of: player) {
            let angle = state.angle(of: planet)
            let line = angle.lineIndex
            let sign = angle.lineSign
            result[line, default: []].append(sign * planet.ring)
        }
        for line in result.keys {
            result[line]?.sort()
        }
        return result
    }

    /// Lines where `player` has ≥ 3 planets (R-11), with the aligned planets.
    public static func alignments(for player: PlayerID, in state: GameState) -> [(line: Int, planets: [PlanetRef])] {
        var byLine: [Int: [PlanetRef]] = [:]
        for planet in state.planets(of: player) {
            let angle = state.angle(of: planet)
            byLine[angle.lineIndex, default: []].append(planet)
        }
        return
            byLine
            .filter { $0.value.count >= 3 }
            .map { (line: $0.key, planets: $0.value.sorted { ($0.ring, $0.slot) < ($1.ring, $1.slot) }) }
            .sorted { $0.line < $1.line }
    }

    /// Grand Alignment check (R-14): one planet of `player` on each of the 4
    /// rings at the same angle (same ray, not the opposite side).
    public static func grandAlignment(for player: PlayerID, in state: GameState) -> Bool {
        var byAngle: [Angle48: Set<Int>] = [:]
        for planet in state.planets(of: player) {
            byAngle[state.angle(of: planet), default: []].insert(planet.ring)
        }
        return byAngle.values.contains { $0.count == 4 }
    }

    /// Captures created by `player`'s alignments on `state` (R-12): for each
    /// aligned line, every enemy planet strictly between the min and max
    /// signed positions is captured. Returns the PlanetRefs to remove (the
    /// enemy planet's own ring/slot identity).
    public static func captures(for player: PlayerID, in state: GameState) -> [PlanetRef] {
        var captured: [PlanetRef] = []
        var seen: Set<PlanetRef> = []
        let opponent = player.opponent
        let opponentPlanets = state.planets(of: opponent)

        for alignment in alignments(for: player, in: state) {
            let positions = alignment.planets.map { state.angle(of: $0).lineSign * $0.ring }
            guard let minPos = positions.min(), let maxPos = positions.max() else { continue }

            for enemy in opponentPlanets {
                let angle = state.angle(of: enemy)
                guard angle.lineIndex == alignment.line else { continue }
                let position = angle.lineSign * enemy.ring
                if position > minPos, position < maxPos, !seen.contains(enemy) {
                    seen.insert(enemy)
                    captured.append(enemy)
                }
            }
        }
        return captured.sorted { ($0.ring, $0.slot) < ($1.ring, $1.slot) }
    }
}
