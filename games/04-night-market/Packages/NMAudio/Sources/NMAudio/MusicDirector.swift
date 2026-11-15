/// The four-stem music director (NM-P6.2). Pure gain logic: crowd density
/// and night phase map to per-stem target gains; the mixer crossfades
/// toward them. Stems: bed (drone), pulse (percussion), lead (melody),
/// crowd (ambience). Rain adds its own ambience layer.
public struct StemMix: Equatable, Sendable {
    public var bed: Float
    public var pulse: Float
    public var lead: Float
    public var crowd: Float
    public var rain: Float

    public init(bed: Float, pulse: Float, lead: Float, crowd: Float, rain: Float) {
        self.bed = bed
        self.pulse = pulse
        self.lead = lead
        self.crowd = crowd
        self.rain = rain
    }
}

public struct MusicDirector: Sendable {
    /// The reference crowd size at which every stem is fully in (density 1).
    public static let referenceCrowd: Double = 300

    /// Builds the stem mix for a moment of the night.
    ///
    /// - Parameters:
    ///   - density: customers in the market ÷ referenceCrowd, clamped 0…1.
    ///   - isRaining: rain turns the lead down and brings the rain layer in.
    ///   - hourProgress: 0 at 18:00 … 1 at 06:00; the last fifth fades out.
    public static func mix(density: Double, isRaining: Bool, hourProgress: Double) -> StemMix {
        let d = min(1, max(0, density))
        let hp = min(1, max(0, hourProgress))
        let fade: Float = hp < 0.8 ? 1.0 : Float(max(0.35, 1.0 - (hp - 0.8) * 3.25))

        let bed: Float = Float(0.4 + 0.2 * d)
        let pulse = d <= 0.15 ? 0 : Float(min(1, (d - 0.15) / 0.6)) * 0.7
        let leadBase = d <= 0.35 ? 0.0 : Float(min(1, (d - 0.35) / 0.5)) * 0.6
        let lead = isRaining ? leadBase * 0.7 : leadBase
        let crowdRaw = Float(0.2 + 0.8 * d)
        let crowd = isRaining ? min(crowdRaw, 0.5) : crowdRaw
        let rain: Float = isRaining ? 0.5 : 0

        return StemMix(
            bed: bed * fade,
            pulse: pulse * fade,
            lead: lead * fade,
            crowd: crowd * fade,
            rain: rain * fade
        )
    }
}
