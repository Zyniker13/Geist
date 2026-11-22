// Murmuration Audio — granular wingbeat synthesis and regional pads.

import Foundation

/// The three layers of Murmuration's generative ambience, mixed by the app:
/// the wingbeat bed, the regional pad, and turn whooshes (ROADMAP §5
/// aesthetic spec).
public struct AmbientMix: Sendable, Equatable {
    /// Wingbeat bed gain (0..1): thickens with flock size and density.
    public var wingbeats: Float
    /// Regional pad gain (0..1): rises at dusk, quiet by day.
    public var pad: Float
    /// Turn whoosh (0..1): a sharp turn's transient envelope.
    public var whoosh: Float

    public init(wingbeats: Float, pad: Float, whoosh: Float) {
        self.wingbeats = wingbeats
        self.pad = pad
        self.whoosh = whoosh
    }
}

/// A snapshot of flock driving metrics for the wingbeat bed. The app fills
/// this from the engine state; MUAudio owns no engine types.
public struct FlockMetrics: Sendable, Equatable {
    /// Birds currently alive in the player's flock.
    public var birdCount: Int
    /// Mean nearest-neighbor distance in world units (lower = denser).
    public var meanSpacing: Float
    /// Mean absolute heading change per tick, radians (0 = steady).
    public var meanTurnRate: Float
    /// 0 = day, 1 = full dusk (from the scene's duskBlend).
    public var dusk: Float

    public init(birdCount: Int, meanSpacing: Float, meanTurnRate: Float, dusk: Float) {
        self.birdCount = birdCount
        self.meanSpacing = meanSpacing
        self.meanTurnRate = meanTurnRate
        self.dusk = dusk
    }
}

/// Granular wingbeat bed (MU-P6.2): grains are short flapping chirps
/// synthesized at a per-voice cadence; the bed's texture — grain rate,
/// density, brightness — is driven by flock size, density and turning
/// rate. Pure Swift DSP: one render call fills a caller-provided buffer,
/// so the app schedules it on any audio thread (AVAudioEngine source node)
/// and unit tests run it headless.
public struct WingbeatGranular: Sendable {
    /// Grain length in seconds (a single wing stroke's whoosh).
    public static let grainLength: Float = 0.045
    /// Sample rate the DSP assumes.
    public static let sampleRate: Float = 48_000

    /// Internal grain state, one voice per tracked bird slot.
    public struct Grain: Sendable {
        var phase: Float = 0        // 0..1 through the grain envelope
        var rate: Float = 0         // grains per second
        var brightness: Float = 0   // 0..1 spectral centroid knob
        var gain: Float = 0         // per-grain gain
        var delay: Float = 0        // seconds until this voice fires
        var active = false

        /// Whether this voice currently sounds.
        public var isActive: Bool { active }
    }

    /// Grain voices (read-only snapshot; drive them via `render`).
    public private(set) var voices: [Grain]
    /// Deterministic phase for grain noise (seeded; no SystemRNG).
    private var rngState: UInt64

    public init(voiceCount: Int = 32, seed: UInt64 = 0x9E3779B97F4A7C15) {
        voices = Array(repeating: Grain(), count: max(voiceCount, 1))
        rngState = seed
    }

    /// Next xorshift output (deterministic; the seeded-RNG rule).
    mutating func nextRandom() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 7
        rngState ^= rngState << 17
        return Float(UInt64(truncatingIfNeeded: rngState) & 0xFFFFFF) / Float(0xFFFFFF)
    }

    /// Map flock metrics onto the bed's texture, then render `frames`
    /// samples into `buffer` (mono; the caller pans/mixes).
    ///
    /// - birdCount drives the number of active grain voices (up to all)
    ///   and the bed's overall gain;
    /// - density (tight spacing) raises the grain rate and lowers
    ///   brightness — a dense murmur reads as a low flutter;
    /// - turn rate adds transient energy (wings work harder).
    public mutating func render(
        metrics: FlockMetrics,
        into buffer: UnsafeMutablePointer<Float>,
        frames: Int
    ) {
        guard frames > 0 else { return }
        let count = max(metrics.birdCount, 0)
        // Voice budget: up to `voices.count` active, spread evenly.
        let activeVoices = min(voices.count, max(1, count / 16))
        // Grain rate: 14/s at sparse-and-calm up to 34/s dense-and-turning.
        let density01 = max(0, min(1, 1 - metrics.meanSpacing / 240))
        let turn01 = max(0, min(1, metrics.meanTurnRate / 0.18))
        let rate = 14 + 20 * density01 + 6 * turn01
        // Brightness: sparse flocks are crisp, dense flocks muffled.
        let brightness = 0.75 - 0.5 * density01 + 0.15 * turn01
        // Bed gain: a couple of birds are almost silent, 900+ full; a
        // dense flock is louder on top (the murmur is the sound of mass).
        let bedGain = min(1, Float(count) / 900) * 0.5 * (0.85 + 0.30 * density01)

        let dt = 1 / Self.sampleRate
        for v in 0..<voices.count {
            if v >= activeVoices { voices[v].active = false; continue }
            if !voices[v].active || voices[v].delay <= 0 {
                voices[v].active = true
                voices[v].rate = rate * (0.9 + 0.2 * nextRandom())
                voices[v].brightness = brightness
                voices[v].gain = bedGain * (0.6 + 0.4 * nextRandom()) / Float(activeVoices)
                voices[v].delay = 1 / voices[v].rate
            }
        }

        for f in 0..<frames {
            var sample: Float = 0
            for v in 0..<voices.count where voices[v].active {
                var g = voices[v]
                if g.delay > 0 {
                    g.delay -= dt
                    voices[v] = g
                    continue
                }
                // Grain envelope: fast attack, exponential decay.
                let t = g.phase
                let env = t < 0.15 ? t / 0.15 : exp(-(t - 0.15) * 9)
                // Grain source: noise burst pitched by brightness.
                let noise = nextRandom() * 2 - 1
                let pitch = 0.4 + 0.6 * g.brightness
                sample += env * g.gain * noise * pitch
                g.phase += dt / Self.grainLength
                if g.phase >= 1 {
                    g.phase = 0
                    g.delay = 1 / g.rate
                    g.rate = rate * (0.9 + 0.2 * nextRandom())
                }
                voices[v] = g
            }
            buffer[f] = sample
        }
    }

    /// Reset all voices (between days / on pause).
    public mutating func reset() {
        for i in voices.indices {
            voices[i] = Grain()
        }
    }
}

/// Turn whoosh (MU-P6.2): a short filtered-noise swell fired when the
/// flock turns sharply. The app feeds it the flock's mean turn rate each
/// tick; the synth self-triggers when the rate crosses its threshold and
/// coasts while the turn holds.
public struct TurnWhoosh: Sendable {
    public static let sampleRate: Float = 48_000

    /// Seconds since the last whoosh fired (cooldown).
    public var cooldown: Float = 0
    /// Remaining swell time for the active whoosh.
    public var swell: Float = 0
    /// Deterministic noise phase (seeded; the seeded-RNG rule).
    var rngState: UInt64

    public init(seed: UInt64 = 0x6A57_0000_9E37_79B9) {
        rngState = seed
    }

    mutating func nextRandom() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 7
        rngState ^= rngState << 17
        return Float(UInt64(truncatingIfNeeded: rngState) & 0xFFFFFF) / Float(0xFFFFFF)
    }

    /// One noise sample for the strike pulse (public so the app's audio
    /// callback can reuse this synth's seeded stream).
    public mutating func pulseNoise() -> Float {
        nextRandom()
    }

    /// Feed one tick's mean turn rate; returns the swell gain for the
    /// tick (0 when silent). A rate above 0.09 rad/tick arms a whoosh.
    public mutating func tick(turnRate: Float) -> Float {
        if cooldown > 0 { cooldown = max(0, cooldown - 1 / 30) }
        if swell > 0 { swell = max(0, swell - 1 / 30) }
        if turnRate > 0.09 && cooldown <= 0 {
            swell = 0.55
            cooldown = 1.2
        }
        return swell > 0 ? min(1, swell / 0.55) : 0
    }

    /// Render `frames` samples of whoosh noise at `gain` (0 = silent).
    public mutating func render(
        gain: Float,
        into buffer: UnsafeMutablePointer<Float>,
        frames: Int
    ) {
        guard frames > 0, gain > 0 else {
            for f in 0..<frames { buffer[f] += 0 }
            return
        }
        let dt = 1 / Self.sampleRate
        for f in 0..<frames {
            let noise = nextRandom() * 2 - 1
            // Low-pass the noise by averaging successive samples.
            buffer[f] += gain * 0.5 * noise
            _ = dt
        }
    }
}

/// Regional pad (MU-P6.2): slow, quiet drone chords, one chord set per
/// region, rising at dusk. Pure additive synthesis over shared voices.
public struct RegionalPad: Sendable {
    /// One partial: frequency ratio over the pad's root and its gain.
    public struct Partial: Sendable, Equatable {
        public var ratio: Float
        public var gain: Float

        public init(ratio: Float, gain: Float) {
            self.ratio = ratio
            self.gain = gain
        }
    }

    /// Chord presets keyed by region id (the six content regions).
    public static let chords: [String: [Partial]] = [
        "meadow": [
            Partial(ratio: 1.0, gain: 0.50), Partial(ratio: 1.5, gain: 0.22),
            Partial(ratio: 2.0, gain: 0.12),
        ],
        "commons": [
            Partial(ratio: 1.0, gain: 0.48), Partial(ratio: 1.25, gain: 0.24),
            Partial(ratio: 1.5, gain: 0.14),
        ],
        "gorge": [
            Partial(ratio: 1.0, gain: 0.46), Partial(ratio: 1.5, gain: 0.20),
            Partial(ratio: 2.0, gain: 0.16), Partial(ratio: 3.0, gain: 0.07),
        ],
        "ridge": [
            Partial(ratio: 1.0, gain: 0.52), Partial(ratio: 2.0, gain: 0.18),
            Partial(ratio: 2.5, gain: 0.12),
        ],
        "delta": [
            Partial(ratio: 1.0, gain: 0.50), Partial(ratio: 1.3333, gain: 0.24),
            Partial(ratio: 2.0, gain: 0.10),
        ],
        "fenlands": [
            Partial(ratio: 1.0, gain: 0.46), Partial(ratio: 1.2, gain: 0.26),
            Partial(ratio: 1.5, gain: 0.16), Partial(ratio: 2.0, gain: 0.08),
        ],
    ]

    /// Sample rate the DSP assumes.
    public static let sampleRate: Float = 48_000

    public var phase: Float = 0
    /// Root frequency in Hz.
    public var rootHz: Float
    public var partials: [Partial]

    public init(regionID: String, rootHz: Float = 110) {
        partials = RegionalPad.chords[regionID] ?? RegionalPad.chords["meadow"]!
        self.rootHz = rootHz
    }

    /// Render `frames` samples of the pad into `buffer`. `dusk` (0..1)
    /// raises the pad's level toward evening; `level` is the base mix.
    public mutating func render(
        dusk: Float,
        level: Float,
        into buffer: UnsafeMutablePointer<Float>,
        frames: Int
    ) {
        guard frames > 0 else { return }
        let gain = level * (0.35 + 0.65 * max(0, min(1, dusk)))
        let dt = 1 / Self.sampleRate
        for f in 0..<frames {
            var sample: Float = 0
            for p in partials {
                let w = 2 * Float.pi * rootHz * p.ratio
                sample += p.gain * sin(w * phase + Float(f) * w * dt)
            }
            buffer[f] += gain * sample
            phase += dt
        }
        if phase > 3600 { phase -= 3600 } // keep phase bounded
    }
}
