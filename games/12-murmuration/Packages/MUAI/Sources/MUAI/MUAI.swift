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
public enum RegionStarter {
    /// Actions applied to a fresh day state before its first tick.
    public static func startingActions(for region: Region) -> [GameAction] {
        guard region.hasRival, region.rivalStartBirds > 0, region.birdCount > 0 else {
            return []
        }
        let ratio = Double(region.rivalStartBirds) / Double(region.birdCount)
        return [.spawnRival(ratio: ratio)]
    }
}
