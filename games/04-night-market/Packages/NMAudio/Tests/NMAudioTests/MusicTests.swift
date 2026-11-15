import Testing
import Foundation
@testable import NMAudio

/// G6: the four-stem music system (NM-P6.2). The mix is deterministic, the
/// stems are seeded and asset-free, and the worst-case simultaneous mix
/// stays at or below −1 dBFS (peak ≤ 0.891).
struct MusicTests {
    // MARK: - Director

    @Test("an empty market beds down and nothing else plays")
    func emptyMarket() {
        let mix = MusicDirector.mix(density: 0, isRaining: false, hourProgress: 0)
        #expect(mix.bed > 0.35)
        #expect(mix.pulse == 0)
        #expect(mix.lead == 0)
        #expect(mix.crowd > 0.1)
        #expect(mix.rain == 0)
    }

    @Test("a packed market brings every stem in")
    func packedMarket() {
        let mix = MusicDirector.mix(density: 1, isRaining: false, hourProgress: 0.4)
        #expect(mix.bed >= 0.55)
        #expect(mix.pulse >= 0.6)
        #expect(mix.lead >= 0.55)
        #expect(mix.crowd >= 0.95)
    }

    @Test("rain ducks the lead and the crowd, and raises the rain layer")
    func rainDucking() {
        let dry = MusicDirector.mix(density: 1, isRaining: false, hourProgress: 0.4)
        let wet = MusicDirector.mix(density: 1, isRaining: true, hourProgress: 0.4)
        #expect(wet.lead < dry.lead)
        #expect(wet.crowd < dry.crowd)
        #expect(wet.rain > 0.4)
        #expect(dry.rain == 0)
    }

    @Test("the last fifth of the night fades toward the floor")
    func lateFade() {
        let early = MusicDirector.mix(density: 1, isRaining: false, hourProgress: 0.4)
        let late = MusicDirector.mix(density: 1, isRaining: false, hourProgress: 0.97)
        #expect(late.pulse < early.pulse)
        #expect(late.pulse >= 0.2, "the fade floor keeps a little life in the mix")
        let end = MusicDirector.mix(density: 1, isRaining: false, hourProgress: 1)
        #expect(end.bed >= 0.1)
    }

    @Test("density clamps out-of-range inputs")
    func clamping() {
        let high = MusicDirector.mix(density: 9, isRaining: false, hourProgress: -1)
        let low = MusicDirector.mix(density: -3, isRaining: false, hourProgress: 2)
        #expect(high == MusicDirector.mix(density: 1, isRaining: false, hourProgress: 0))
        #expect(low == MusicDirector.mix(density: 0, isRaining: false, hourProgress: 1))
    }

    // MARK: - Stem rendering

    @Test("every rendered stem stays inside its peak budget")
    func stemPeaks() async throws {
        for stem in Stem.allCases {
            let samples = StemRenderer.render(stem, sampleRate: 48_000, seed: 7)
            let peak = samples.map { abs($0) }.max() ?? 0
            #expect(peak <= stem.peakBudget + 0.0001, "\(stem) peak \(peak)")
        }
    }

    @Test("stems are deterministic for a given seed")
    func deterministic() {
        let a = StemRenderer.render(.lead, sampleRate: 8_000, seed: 99)
        let b = StemRenderer.render(.lead, sampleRate: 8_000, seed: 99)
        #expect(a == b)
        let other = StemRenderer.render(.lead, sampleRate: 8_000, seed: 100)
        #expect(a != other)
    }

    @Test("one-shot effects are short and peak-capped")
    func effects() {
        for stem in [Stem.serve, .overflow] {
            let samples = StemRenderer.render(stem, sampleRate: 48_000, seed: 3)
            let peak = samples.map { abs($0) }.max() ?? 0
            #expect(peak <= stem.peakBudget)
            let nonzero = samples.filter { abs($0) > 0.001 }.count
            #expect(nonzero < 48_000 / 4, "\(stem) should finish within a quarter second")
        }
    }

    // MARK: - Peak accounting (G6: ≤ −1 dBFS)

    @Test("the worst-case simultaneous mix stays at or below −1 dBFS")
    func worstCasePeak() {
        let peaks: [Stem: Float] = [
            .bed: StemRenderer.render(.bed, sampleRate: 8_000, seed: 1).map { abs($0) }.max() ?? 0,
            .pulse: StemRenderer.render(.pulse, sampleRate: 8_000, seed: 1).map { abs($0) }.max() ?? 0,
            .lead: StemRenderer.render(.lead, sampleRate: 8_000, seed: 1).map { abs($0) }.max() ?? 0,
            .crowd: StemRenderer.render(.crowd, sampleRate: 8_000, seed: 1).map { abs($0) }.max() ?? 0,
            .rain: StemRenderer.render(.rain, sampleRate: 8_000, seed: 1).map { abs($0) }.max() ?? 0,
        ]
        // The loudest mix the director can ever ask for.
        let loud = MusicDirector.mix(density: 1, isRaining: true, hourProgress: 0.5)
        let peak = AudioMixer.mixedPeak(loud, peaks: peaks)
        #expect(peak <= 0.891, "worst-case mix peak \(peak) must stay ≤ −1 dBFS (0.891)")
        #expect(peak > 0.1, "the mix should not be inaudibly quiet")
    }

    @Test("gain crossfades move monotonically toward the target")
    func crossfade() {
        let from = StemMix(bed: 0, pulse: 0, lead: 0, crowd: 0, rain: 0)
        let to = StemMix(bed: 1, pulse: 1, lead: 1, crowd: 1, rain: 1)
        var current = from
        var lastBed = Float(0)
        for _ in 0..<200 {
            current = AudioMixer.approach(current, toward: to, rate: 0.02)
            #expect(current.bed >= lastBed)
            lastBed = current.bed
        }
        #expect(current.bed == 1)
    }
}
