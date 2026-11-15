/// The runtime audio mixer (NM-P6.2). Wraps AVAudioEngine with one looping
/// player per stem; gains crossfade toward the MusicDirector's targets.
/// The engine is created lazily by `start()` so tests and headless runs
/// never touch CoreAudio. Mix math and peak accounting live in pure
/// functions so they are testable without the engine.
import AVFoundation
import NMCore

public final class AudioMixer {
    public let sampleRate: Int
    private var buffers: [Stem: [Float]] = [:]
    private var current: StemMix
    private var target: StemMix
    private var engine: AVAudioEngine?
    private var players: [Stem: AVAudioPlayerNode] = [:]
    private var lastEffectAt: Date?
    /// UI tests and headless runs keep the engine off entirely.
    public private(set) var isEnabled: Bool

    public init(sampleRate: Int = 48_000, enabled: Bool = true) {
        self.sampleRate = sampleRate
        self.isEnabled = enabled
        self.current = StemMix(bed: 0, pulse: 0, lead: 0, crowd: 0, rain: 0)
        self.target = current
        for stem in Stem.allCases {
            buffers[stem] = StemRenderer.render(stem, sampleRate: sampleRate, seed: seed(for: stem))
        }
    }

    private func seed(for stem: Stem) -> UInt64 {
        switch stem {
        case .bed: return 0xA0D1
        case .pulse: return 0xB0D2
        case .lead: return 0xC0D3
        case .crowd: return 0xD0D4
        case .rain: return 0xE0D5
        case .serve: return 0xF0D6
        case .overflow: return 0x10D7
        }
    }

    // MARK: - Pure mix math (tested without the engine)

    /// Moves `current` toward `target` by at most `rate` per call.
    public static func approach(_ current: StemMix, toward target: StemMix, rate: Float) -> StemMix {
        func step(_ a: Float, _ b: Float) -> Float {
            let delta = b - a
            if abs(delta) <= rate { return b }
            return a + (delta > 0 ? rate : -rate)
        }
        return StemMix(
            bed: step(current.bed, target.bed),
            pulse: step(current.pulse, target.pulse),
            lead: step(current.lead, target.lead),
            crowd: step(current.crowd, target.crowd),
            rain: step(current.rain, target.rain)
        )
    }

    /// The worst-case mixed peak for a mix, given each stem's rendered peak.
    public static func mixedPeak(_ mix: StemMix, peaks: [Stem: Float]) -> Float {
        mix.bed * (peaks[.bed] ?? 0)
            + mix.pulse * (peaks[.pulse] ?? 0)
            + mix.lead * (peaks[.lead] ?? 0)
            + mix.crowd * (peaks[.crowd] ?? 0)
            + mix.rain * (peaks[.rain] ?? 0)
    }

    // MARK: - Runtime

    public func setMix(_ mix: StemMix) {
        target = mix
        current = Self.approach(current, toward: target, rate: 0.02)
        guard isEnabled, engine != nil else { return }
        applyGains()
    }

    /// Plays a one-shot effect, throttled so serve spam stays musical.
    public func play(_ event: AudioEvent) {
        guard isEnabled, engine != nil else { return }
        let now = Date()
        if let last = lastEffectAt, now.timeIntervalSince(last) < 0.18 { return }
        lastEffectAt = now
        let stem: Stem = event.kind == .serve ? .serve : .overflow
        guard let player = players[stem] else { return }
        // One-shots share their stem player: stop, re-schedule, play.
        player.stop()
        guard let buffer = self.buffer(stem, length: sampleRate / 8) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.volume = event.volume
        player.play()
    }

    private func buffer(_ stem: Stem, length: Int) -> AVAudioPCMBuffer? {
        guard let samples = buffers[stem], let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate),
            channels: 1, interleaved: false
        ) else { return nil }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
        guard let channel = buffer?.floatChannelData?[0] else { return nil }
        for i in 0..<length { channel[i] = samples[i % samples.count] }
        buffer?.frameLength = AVAudioFrameCount(length)
        return buffer
    }

    /// Starts the engine (call from the app only; never in tests).
    public func start() {
        guard isEnabled, engine == nil else { return }
        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate),
            channels: 1, interleaved: false
        ) else { return }
        let mixer = engine.mainMixerNode
        for stem in Stem.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            players[stem] = player
            if stem == .serve || stem == .overflow { continue }
            if let buffer = buffer(stem, length: sampleRate) {
                player.scheduleBuffer(buffer, at: nil, options: .loops)
                player.volume = 0
                player.play()
            }
        }
        engine.prepare()
        do {
            try engine.start()
            self.engine = engine
            applyGains()
        } catch {
            // Audio is decorative: silence is always an acceptable outcome.
            self.engine = nil
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
        for player in players.values { player.stop() }
        players.removeAll()
    }

    private func applyGains() {
        for (stem, player) in players {
            let gain: Float
            switch stem {
            case .bed: gain = current.bed
            case .pulse: gain = current.pulse
            case .lead: gain = current.lead
            case .crowd: gain = current.crowd
            case .rain: gain = current.rain
            case .serve, .overflow: continue
            }
            player.volume = gain
        }
    }
}
