// Murmuration audio controller — schedules MUAudio's DSP on AVAudioEngine.

import AVFoundation
import MUAudio

#if canImport(UIKit)
    import UIKit
#endif

/// The DSP state the render callback touches, held as one reference so the
/// controller's update methods and the audio thread share it safely under
/// the controller's serial queue.
private final class AudioDSP {
    var gran = WingbeatGranular(voiceCount: 32, seed: 0x9E3779B97F4A7C15)
    var pad = RegionalPad(regionID: "meadow")
    var whoosh = TurnWhoosh()
    var metrics = FlockMetrics(birdCount: 0, meanSpacing: 240, meanTurnRate: 0, dusk: 0)
    var padLevel: Float = 0.28
    var strikePulse: Float = 0
}

/// Drives the generative ambience (MU-P6.2): a wingbeat granular bed and a
/// regional pad rendered on an AVAudioEngine source node. The app pushes
/// `metrics` from the game model each tick; the DSP runs on the audio
/// thread. Everything degrades silently when audio is unavailable (no
/// device, CI): the game never depends on sound.
final class AudioController {
    private let engine = AVAudioEngine()
    private let dsp = AudioDSP()
    /// Serializes access to `dsp` between the app thread (updates) and the
    /// audio thread (render). Contention is nil in practice: updates are
    /// one struct copy per tick.
    private let queue = DispatchQueue(label: "mu.audio.dsp")
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning = false

    init() {
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)
        // The MUAudio DSP assumes 48 kHz; resample the bed by linear stride.
        let ratio = max(sampleRate / WingbeatGranular.sampleRate, 0.25)
        let node = AVAudioSourceNode(format: outputFormat) { [dsp, queue] _, _, frameCount, audioBufferList in
            let frames = Int(frameCount)
            var scratch = [Float](repeating: 0, count: frames)
            scratch.withUnsafeMutableBufferPointer { bp in
                queue.sync {
                    let bedFrames = Int(Float(frames) / ratio) + 2
                    var bed = [Float](repeating: 0, count: bedFrames)
                    dsp.gran.render(metrics: dsp.metrics, into: &bed, frames: bedFrames)
                    dsp.pad.render(dusk: dsp.metrics.dusk, level: dsp.padLevel, into: bp.baseAddress!, frames: frames)
                    // Whoosh: the tick's turn rate drives the swell; the gain
                    // persists over the audio frames this callback renders.
                    let whooshGain = dsp.whoosh.tick(turnRate: dsp.metrics.meanTurnRate) * 0.25
                    if whooshGain > 0 {
                        dsp.whoosh.render(gain: whooshGain, into: bp.baseAddress!, frames: frames)
                    }
                    // Falcon strike: a short bright noise pulse (seeded).
                    if dsp.strikePulse > 0 {
                        let pulseFrames = min(frames, Int(dsp.strikePulse / 0.001))
                        for f in 0..<pulseFrames {
                            bp[f] += dsp.strikePulse * 0.6 * (dsp.whoosh.pulseNoise() * 2 - 1)
                        }
                        dsp.strikePulse = max(0, dsp.strikePulse - Float(frames) / 48_000 * 6)
                    }
                    for f in 0..<frames {
                        let src = Float(f) / ratio
                        let i = min(Int(src), bedFrames - 2)
                        let frac = src - Float(i)
                        bp[f] += bed[i] * (1 - frac) + bed[i + 1] * frac
                    }
                }
            }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in abl {
                guard let mData = buffer.mData else { continue }
                let out = mData.assumingMemoryBound(to: Float.self)
                for f in 0..<frames {
                    out[f] = scratch[f]
                }
            }
            return noErr
        }
        sourceNode = node
    }

    /// Begin rendering ambience. Safe to call again; failures degrade to
    /// silence (the game plays fine without audio).
    func start() {
        guard let sourceNode, !isRunning else { return }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// Stop rendering (app backgrounded, menu). Idempotent.
    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
    }

    /// Push the current flock metrics (called once per tick).
    func update(metrics: FlockMetrics) {
        queue.sync { dsp.metrics = metrics }
    }

    /// Switch the regional pad (called at day start).
    func setRegion(regionID: String, padLevel: Float) {
        queue.sync {
            dsp.pad = RegionalPad(regionID: regionID)
            dsp.padLevel = padLevel
        }
    }

    /// Clear grain voices (day boundary, pause).
    func resetBed() {
        queue.sync { dsp.gran.reset() }
    }

    /// A falcon strike: sharp audio pulse + haptic tap (MU-P6 spec).
    func strike() {
        queue.sync { dsp.strikePulse = 0.25 }
        Haptics.strikeTap()
    }
}

/// Haptics (MU-P6): continuous light texture while steering is handled by
/// the gesture layer's feedback; the strike tap lives here so both arrive
/// from the model's event handling. Wraps UIKit/AppKit lazily and no-ops
/// where unsupported (tests, CI).
enum Haptics {
    /// A short, sharp impact for a falcon strike.
    static func strikeTap() {
        #if os(iOS)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
}
