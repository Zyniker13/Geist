// GameModel audio feed (MU-P6.2) — metrics for the wingbeat bed.

import Foundation
import MUAudio
import MUCore

extension GameModel {
    /// The ambience controller; nil when audio is off (tests, CI, mute).
    /// The view layer owns its lifetime; the model only feeds metrics.
    var audio: AudioController? {
        get { audioRef.value }
        set { audioRef.value = newValue }
    }

    /// Previous-tick velocity headings for the turn-rate metric.
    var prevHeadings: [Float] {
        get { audioPrevHeadings.value }
        set { audioPrevHeadings.value = newValue }
    }

    /// Flock metrics for the wingbeat bed: mean nearest-neighbor spacing
    /// (sampled over up to 64 birds for O(n)), mean absolute heading
    /// change per tick, and the scene's dusk blend. Called once per tick.
    func pushAudioMetrics() {
        guard let audio else { return }
        let birds = state.birds
        let n = birds.count
        guard n > 0 else {
            audio.update(metrics: FlockMetrics(birdCount: 0, meanSpacing: 240, meanTurnRate: 0, dusk: duskBlend01()))
            return
        }
        // Mean spacing: sample up to 64 birds, track each one's nearest
        // neighbor over the same sample (spatial hash not needed at 64).
        let sampleN = min(n, 64)
        let stride = max(n / sampleN, 1)
        var spacingSum: Float = 0
        var sampled = 0
        for s in 0..<sampleN {
            let i = s * stride
            guard i < n else { continue }
            var best = Float(Int32.max)
            for t in 0..<sampleN {
                let j = t * stride
                guard j != i, j < n else { continue }
                let dx = Float(birds.posX[j] - birds.posX[i])
                let dy = Float(birds.posY[j] - birds.posY[i])
                let d = (dx * dx + dy * dy).squareRoot()
                if d < best { best = d }
            }
            if best < Float(Int32.max) {
                spacingSum += best
                sampled += 1
            }
        }
        let meanSpacing = sampled > 0 ? spacingSum / Float(sampled) : 240
        // Mean turn rate: |heading(t) - heading(t-1)| averaged over the
        // birds that have both velocities.
        var turnSum: Float = 0
        var turnCount = 0
        if prevHeadings.count == n {
            for i in 0..<n {
                let vx = Float(birds.velX[i]), vy = Float(birds.velY[i])
                if vx == 0 && vy == 0 { continue }
                let heading = atan2f(vy, vx)
                var delta = heading - prevHeadings[i]
                while delta > .pi { delta -= 2 * .pi }
                while delta < -.pi { delta += 2 * .pi }
                turnSum += abs(delta)
                turnCount += 1
            }
        }
        prevHeadings = (0..<n).map { i -> Float in
            let vx = Float(birds.velX[i]), vy = Float(birds.velY[i])
            return (vx == 0 && vy == 0) ? 0 : atan2f(vy, vx)
        }
        let meanTurn = turnCount > 0 ? turnSum / Float(turnCount) : 0
        audio.update(
            metrics: FlockMetrics(
                birdCount: n,
                meanSpacing: meanSpacing,
                meanTurnRate: meanTurn,
                dusk: duskBlend01()
            )
        )
    }

    /// The dusk blend (0..1) the scene uses, computed the same way.
    func duskBlend01() -> Float {
        let span = GameState.dayTicks - GameState.duskStart
        guard state.tick > GameState.duskStart else { return 0 }
        return Float(min(state.tick - GameState.duskStart, span)) / Float(max(span, 1))
    }
}
