// Murmuration AI — rival flock steering, falcons, and the autoplayer.
//
// P2 scope: the Autoplayer (player flock policy for the vertical slice and
// the three-day autoplay UI test) and the GentleRival (the slice's rival
// pilot). Falcon behaviors land in P4.

import MUCore
import MUContent

/// Day-start actions (P2.3): a region with a rival starts with a `spawnRival`
/// (ADR-0033) that carves the rival's birds off flock 0 into a rival-OWNED
/// side flock. The player keeps the remainder, matching the ROADMAP's
/// `startBirds` and `rival.startBirds` content values.
///
/// ADR-0035 scales the carve by difficulty (`startScale`): the shipped
/// `rivalStartBirds` is the gentle-tier setup, and harder tiers start the
/// rival with a larger share — a visible "you are outnumbered" cue and the
/// main lever behind the 85/60/35 win-rate targets on tiebreak-heavy days.
public enum RegionStarter {
    /// Per-tier multiplier on the region's `rivalStartBirds` share.
    public static func startScale(_ difficulty: RivalDifficulty) -> Double {
        switch difficulty {
        case .gentle: return 1.0
        case .normal: return 1.25
        case .hard: return 1.5
        }
    }

    /// Actions applied to a fresh day state before its first tick. A nil
    /// difficulty keeps the region's raw share (legacy call sites and
    /// probes).
    public static func startingActions(
        for region: Region, difficulty: RivalDifficulty? = nil
    ) -> [GameAction] {
        guard region.hasRival, region.rivalStartBirds > 0, region.birdCount > 0 else {
            return []
        }
        var ratio = Double(region.rivalStartBirds) / Double(region.birdCount)
        if let difficulty {
            ratio *= startScale(difficulty)
        }
        return [.spawnRival(ratio: min(ratio, 0.9))]
    }
}
