/// ORCore — the Orrery rules engine (pure Swift, no platform imports).
///
/// P0 carries the determinism foundation (`SeededRNG`, `Fixed`), the canonical
/// angular unit (`Angle48`, OR-P0.1), the state hasher, and the replay
/// harness. The full rules engine arrives in P1.
public enum ORCoreInfo {
    /// Content version the packages were built for.
    public static let contentVersion = "or-0.1"
}
