/// Rotation math (R-7): after both players move, all rings rotate by their speed.
public enum Rotation {
    /// The end-of-round rotation: every ring advances by its speed. Returns
    /// the rotated rings and the per-ring deltas (normalized for hashing).
    public static func rotateRings(_ rings: [RingState]) -> (rings: [RingState], deltas: [Int]) {
        var out: [RingState] = []
        var deltas: [Int] = []
        for ring in rings {
            var copy = ring
            let delta = ring.speed
            copy.rotate(by: delta)
            out.append(copy)
            deltas.append(delta)
        }
        return (out, deltas)
    }
}
