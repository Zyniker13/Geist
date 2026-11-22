import XCTest

@testable import MUAudio

final class MUAudioTests: XCTestCase {
    // MARK: WingbeatGranular

    func testWingbeatRendersFiniteSamples() {
        var gran = WingbeatGranular(voiceCount: 16)
        let frames = 4800
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        buf.initialize(repeating: 0, count: frames)
        defer { buf.deinitialize(count: frames); buf.deallocate() }
        gran.render(
            metrics: FlockMetrics(birdCount: 400, meanSpacing: 90, meanTurnRate: 0.05, dusk: 0),
            into: buf,
            frames: frames
        )
        var peak: Float = 0
        var finite = true
        for f in 0..<frames {
            let s = buf[f]
            if !s.isFinite { finite = false }
            peak = max(peak, abs(s))
        }
        XCTAssertTrue(finite, "all samples must be finite")
        XCTAssertGreaterThan(peak, 0, "the bed must produce sound")
        XCTAssertLessThan(peak, 1.0, "the bed must stay out of clipping")
    }

    func testWingbeatBedGrowsWithFlockSize() {
        // Same seed; larger flock -> more active voices and higher peak.
        func peakFor(birds: Int) -> Float {
            var gran = WingbeatGranular(voiceCount: 32, seed: 7)
            let frames = 9600
            let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            buf.initialize(repeating: 0, count: frames)
            defer { buf.deinitialize(count: frames); buf.deallocate() }
            gran.render(
                metrics: FlockMetrics(birdCount: birds, meanSpacing: 120, meanTurnRate: 0.03, dusk: 0),
                into: buf,
                frames: frames
            )
            var peak: Float = 0
            for f in 0..<frames { peak = max(peak, abs(buf[f])) }
            return peak
        }
        XCTAssertGreaterThan(peakFor(birds: 800), peakFor(birds: 40))
    }

    func testDenseFlockRaisesGrainEnergyOverSparse() {
        // Density raises the per-voice grain rate and muffles brightness;
        // net effect: a dense flock's bed carries more sustained energy.
        func rmsFor(spacing: Float) -> Float {
            var gran = WingbeatGranular(voiceCount: 8, seed: 11)
            let frames = 48_000
            let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            buf.initialize(repeating: 0, count: frames)
            defer { buf.deinitialize(count: frames); buf.deallocate() }
            gran.render(
                metrics: FlockMetrics(birdCount: 320, meanSpacing: spacing, meanTurnRate: 0.02, dusk: 0),
                into: buf,
                frames: frames
            )
            var sum: Float = 0
            for f in 0..<frames { sum += buf[f] * buf[f] }
            return (sum / Float(frames)).squareRoot()
        }
        XCTAssertGreaterThan(rmsFor(spacing: 40), rmsFor(spacing: 220))
    }

    func testTurnRateAddsEnergy() {
        func rmsFor(turn: Float) -> Float {
            var gran = WingbeatGranular(voiceCount: 16, seed: 3)
            let frames = 48_000
            let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            buf.initialize(repeating: 0, count: frames)
            defer { buf.deinitialize(count: frames); buf.deallocate() }
            gran.render(
                metrics: FlockMetrics(birdCount: 600, meanSpacing: 100, meanTurnRate: turn, dusk: 0),
                into: buf,
                frames: frames
            )
            var sum: Float = 0
            for f in 0..<frames { sum += buf[f] * buf[f] }
            return (sum / Float(frames)).squareRoot()
        }
        XCTAssertGreaterThan(rmsFor(turn: 0.16), rmsFor(turn: 0.0))
    }

    func testRenderIsDeterministicForSameSeedAndMetrics() {
        func checksum(seed: UInt64) -> Float {
            var gran = WingbeatGranular(voiceCount: 12, seed: seed)
            let frames = 4800
            let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            buf.initialize(repeating: 0, count: frames)
            defer { buf.deinitialize(count: frames); buf.deallocate() }
            gran.render(
                metrics: FlockMetrics(birdCount: 500, meanSpacing: 80, meanTurnRate: 0.1, dusk: 0.5),
                into: buf,
                frames: frames
            )
            var sum: Float = 0
            for f in 0..<frames { sum += buf[f] * Float(f % 7) }
            return sum
        }
        XCTAssertEqual(checksum(seed: 42), checksum(seed: 42), accuracy: 1e-6)
        XCTAssertNotEqual(checksum(seed: 42), checksum(seed: 43))
    }

    func testZeroBirdsStaysSilent() {
        var gran = WingbeatGranular(voiceCount: 8)
        let frames = 2400
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        buf.initialize(repeating: 0, count: frames)
        defer { buf.deinitialize(count: frames); buf.deallocate() }
        gran.render(
            metrics: FlockMetrics(birdCount: 0, meanSpacing: 999, meanTurnRate: 0, dusk: 0),
            into: buf,
            frames: frames
        )
        var peak: Float = 0
        for f in 0..<frames { peak = max(peak, abs(buf[f])) }
        // Zero birds: no voices map on except the forced first voice, whose
        // bed gain is 0 — the output must be effectively silent.
        XCTAssertLessThan(peak, 0.01, "no flock, no wingbeats")
    }

    func testResetClearsVoices() {
        var gran = WingbeatGranular(voiceCount: 8, seed: 5)
        let frames = 2400
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        buf.initialize(repeating: 0, count: frames)
        defer { buf.deinitialize(count: frames); buf.deallocate() }
        gran.render(
            metrics: FlockMetrics(birdCount: 300, meanSpacing: 100, meanTurnRate: 0.05, dusk: 0),
            into: buf,
            frames: frames
        )
        gran.reset()
        let active = gran.voices.filter(\.isActive).count
        XCTAssertEqual(active, 0, "reset must silence every voice")
    }

    // MARK: RegionalPad

    func testEveryContentRegionHasAChord() {
        for region in ["meadow", "commons", "gorge", "ridge", "delta", "fenlands"] {
            let pad = RegionalPad(regionID: region)
            XCTAssertFalse(pad.partials.isEmpty, "\(region) needs a chord")
            XCTAssertGreaterThan(pad.partials[0].ratio, 0)
            XCTAssertGreaterThan(pad.partials[0].gain, 0)
        }
    }

    func testUnknownRegionFallsBackToMeadow() {
        let pad = RegionalPad(regionID: "nowhere")
        XCTAssertEqual(pad.partials, RegionalPad.chords["meadow"])
    }

    func testChordsDifferAcrossRegions() {
        let set = Set(RegionalPad.chords.values.map { $0.map { "\($0.ratio):\($0.gain)" }.joined(separator: ",") })
        XCTAssertEqual(
            set.count,
            RegionalPad.chords.count,
            "each region's chord must be distinct"
        )
    }

    func testPadIsLouderAtDuskAndFinite() {
        var pad = RegionalPad(regionID: "gorge")
        let frames = 4800
        let bufDay = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        bufDay.initialize(repeating: 0, count: frames)
        let bufDusk = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        bufDusk.initialize(repeating: 0, count: frames)
        defer { bufDay.deinitialize(count: frames); bufDay.deallocate(); bufDusk.deinitialize(count: frames); bufDusk.deallocate() }
        pad.render(dusk: 0, level: 0.5, into: bufDay, frames: frames)
        pad = RegionalPad(regionID: "gorge")
        pad.render(dusk: 1, level: 0.5, into: bufDusk, frames: frames)
        var dayPeak: Float = 0
        var duskPeak: Float = 0
        var finite = true
        for f in 0..<frames {
            dayPeak = max(dayPeak, abs(bufDay[f]))
            duskPeak = max(duskPeak, abs(bufDusk[f]))
            if !bufDusk[f].isFinite { finite = false }
        }
        XCTAssertTrue(finite)
        XCTAssertGreaterThan(duskPeak, dayPeak)
        XCTAssertLessThan(duskPeak, 1.0, "the pad must stay out of clipping")
    }

    // MARK: TurnWhoosh

    func testWhooshFiresOnSharpTurnThenCoasts() {
        var whoosh = TurnWhoosh(seed: 9)
        // Steady flight: silent.
        XCTAssertEqual(whoosh.tick(turnRate: 0.02), 0)
        // A sharp turn arms the swell.
        XCTAssertGreaterThan(whoosh.tick(turnRate: 0.15), 0)
        // The cooldown suppresses immediate re-fires.
        let duringCooldown = TurnWhoosh(seed: 9)
        _ = duringCooldown
        var w2 = TurnWhoosh(seed: 9)
        XCTAssertGreaterThan(w2.tick(turnRate: 0.15), 0)
        var sawZero = false
        // Hold turning: the swell must decay to zero before the cooldown
        // lifts (0.55 s swell < 1.2 s cooldown).
        var ticks = 0
        while ticks < 40 {
            let g = w2.tick(turnRate: 0.15)
            ticks += 1
            if g == 0 { sawZero = true; break }
        }
        XCTAssertTrue(sawZero, "the swell must decay while the cooldown holds")
    }

    func testWhooshRenderAddsFiniteSamplesOnlyWhenArmed() {
        var whoosh = TurnWhoosh(seed: 21)
        let frames = 480
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        buf.initialize(repeating: 0, count: frames)
        defer { buf.deinitialize(count: frames); buf.deallocate() }
        whoosh.render(gain: 0, into: buf, frames: frames)
        var peak: Float = 0
        for f in 0..<frames { peak = max(peak, abs(buf[f])) }
        XCTAssertEqual(peak, 0, "gain 0 must leave the buffer untouched")
        whoosh.render(gain: 0.5, into: buf, frames: frames)
        var peak2: Float = 0
        var finite = true
        for f in 0..<frames {
            peak2 = max(peak2, abs(buf[f]))
            if !buf[f].isFinite { finite = false }
        }
        XCTAssertTrue(finite)
        XCTAssertGreaterThan(peak2, 0)
    }
}
