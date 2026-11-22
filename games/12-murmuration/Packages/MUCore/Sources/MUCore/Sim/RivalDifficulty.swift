// Murmuration — rival difficulty tiers (P4.1).
//
// Regions encode the rival pilot's difficulty as a lowercase string; the
// app's difficulty picker overrides the region default for a session. The
// tiers differ in cadence, standoff, and dusk aggression:
//
// - gentle: forages away from the player, claims a far roost when it can,
//   otherwise holds a standoff (the P2.3 pilot behavior).
// - normal: shorter forage and flee cadences, picks the roost that trades
//   near-rival against far-from-player, contests when it can reach a roost.
// - hard: fastest cadences, contests roosts the player has not claimed,
//   and splits to hold two roosts in multi-roost regions.

public enum RivalDifficulty: String, Codable, Sendable, Equatable, CaseIterable {
    case gentle
    case normal
    case hard
}
