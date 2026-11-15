/// Procedural stem rendering (NM-P6.2). Every stem is synthesized from a
/// seeded generator — no audio assets, no third-party content. Amplitude
/// budgets are chosen so the worst-case simultaneous mix stays below
/// −1 dBFS (see `MusicDirector` max gains and the peak test).
import Foundation
import NMCore

public enum Stem: String, CaseIterable, Sendable {
    case bed, pulse, lead, crowd, rain
    case serve, overflow  // one-shot effects

    /// Per-stamp peak amplitude budget. Worst-case simultaneous mix
    /// (bed 0.6 + pulse 0.7 + lead 0.6 + crowd 1.0 + rain 0.5 gains):
    /// 0.25·0.6 + 0.30·0.7 + 0.25·0.6 + 0.18·1.0 + 0.15·0.5 = 0.765 ≤ 0.891.
    public var peakBudget: Float {
        switch self {
        case .bed: return 0.25
        case .pulse: return 0.30
        case .lead: return 0.25
        case .crowd: return 0.18
        case .rain: return 0.15
        case .serve: return 0.30
        case .overflow: return 0.40
        }
    }
}

public enum StemRenderer {
    /// One second of a stem at the given rate, mono Float32.
    public static func render(_ stem: Stem, sampleRate: Int, seed: UInt64) -> [Float] {
        var rng = SeededRNG(seed: seed)
        let count = sampleRate
        var samples = [Float](repeating: 0, count: count)
        switch stem {
        case .bed:
            // Two detuned low sines with a slow tremolo swell.
            for i in 0..<count {
                let t = Double(i) / Double(sampleRate)
                let tremolo = 0.8 + 0.2 * sin(2 * .pi * 0.25 * t)
                let value = sin(2 * .pi * 110 * t) * 0.6 + sin(2 * .pi * 164.8 * t) * 0.4
                samples[i] = Float(value * tremolo * 0.25)
            }
        case .pulse:
            // A 16-step kick loop; four hits with exponential decay bodies.
            for i in 0..<count {
                let t = Double(i) / Double(sampleRate)
                let step = Int(t * 16) % 16
                let phase = t * 16 - Double(Int(t * 16))
                let hit: Double = step.isMultiple(of: 4) ? 1 : 0
                let decay = exp(-phase * 9)
                let body = sin(2 * .pi * (58 + 40 * decay) * (phase / 16.0 * 16))
                samples[i] = Float(hit * decay * body * 0.30)
            }
        case .lead:
            // Pentatonic plucks: seeded pitch picks, each a decaying sine.
            let scale: [Double] = [220, 261.6, 293.7, 329.6, 392, 440]
            var cursor = 0
            while cursor < count {
                let note = scale[Int(rng.next(upperBound: UInt64(scale.count)))]
                let length = sampleRate / 3
                for j in 0..<length where cursor + j < count {
                    let decay = exp(-3.5 * Double(j) / Double(length))
                    samples[cursor + j] += Float(sin(2 * .pi * note * Double(j) / Double(sampleRate)) * decay * 0.25)
                }
                cursor += length + Int(rng.next(upperBound: UInt64(sampleRate / 4)))
            }
        case .crowd:
            // Murmur: seeded noise low-passed by a moving average.
            var history: [Float] = []
            for i in 0..<count {
                let noise = Float(rng.nextDouble()) * 2 - 1
                history.append(noise)
                if history.count > 48 { history.removeFirst() }
                let average = history.reduce(0, +) / Float(history.count)
                samples[i] = average * 0.9
            }
        case .rain:
            // Rain hiss: seeded noise, heavier low-pass.
            var history: [Float] = []
            for i in 0..<count {
                let noise = Float(rng.nextDouble()) * 2 - 1
                history.append(noise)
                if history.count > 160 { history.removeFirst() }
                let average = history.reduce(0, +) / Float(history.count)
                samples[i] = average * 0.9
            }
        case .serve:
            // Bright blip: rising sweep with fast decay, 80 ms.
            let length = sampleRate * 8 / 100
            for i in 0..<min(length, count) {
                let t = Double(i) / Double(sampleRate)
                let sweep = 880.0 + 440.0 * Double(i) / Double(length)
                samples[i] = Float(sin(2 * .pi * sweep * t) * exp(-9 * t) * 0.30)
            }
        case .overflow:
            // Low thud with a rough tail, 150 ms.
            let length = sampleRate * 15 / 100
            for i in 0..<min(length, count) {
                let t = Double(i) / Double(sampleRate)
                samples[i] = Float(sin(2 * .pi * 120 * t) * exp(-5 * t) * 0.40)
            }
        }
        // Enforce the stem's peak budget regardless of synthesis drift.
        var peak: Float = 0.0001
        for s in samples { peak = max(peak, abs(s)) }
        let limit = stem.peakBudget
        if peak > limit {
            let scale = limit / peak
            for i in 0..<count { samples[i] *= scale }
        }
        return samples
    }
}
