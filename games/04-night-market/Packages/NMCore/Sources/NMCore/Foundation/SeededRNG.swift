/// Xoshiro256** PRNG seeded through SplitMix64.
///
/// Deterministic, thread-safe, and the sole source of randomness in Core, Content, and AI.
public struct SeededRNG: Sendable, Codable {
    public var state: (UInt64, UInt64, UInt64, UInt64)

    private enum CodingKeys: String, CodingKey {
        case s0, s1, s2, s3
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = (
            try container.decode(UInt64.self, forKey: .s0),
            try container.decode(UInt64.self, forKey: .s1),
            try container.decode(UInt64.self, forKey: .s2),
            try container.decode(UInt64.self, forKey: .s3)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state.0, forKey: .s0)
        try container.encode(state.1, forKey: .s1)
        try container.encode(state.2, forKey: .s2)
        try container.encode(state.3, forKey: .s3)
    }

    /// Create from a single UInt64 seed via SplitMix64.
    public init(seed: UInt64) {
        var s = SplitMix64(seed: seed)
        self.state = (s.next(), s.next(), s.next(), s.next())
    }

    /// Create from four UInt64 values directly.
    public init(state: (UInt64, UInt64, UInt64, UInt64)) {
        self.state = state
    }

    /// Return a random UInt64.
    public mutating func next() -> UInt64 {
        let result = xoshiro256ss(&state)
        return result
    }

    /// Return a random UInt64 in `0..<upperBound`.
    public mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        let threshold = (~UInt64.max % upperBound)
        var r: UInt64
        repeat {
            r = next()
        } while r < threshold
        return r % upperBound
    }

    /// Return a random Double in `[0, 1)`.
    public mutating func nextDouble() -> Double {
        let bits = (next() >> 11) & 0x1FFFFFFFFFFFF
        return Double(bits) / Double(0x2000000000000)
    }

    /// Return a random Int in `0..<upperBound`.
    public mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next(upperBound: UInt64(upperBound)))
    }

    /// Return a random element from the collection.
    public mutating func randomElement<C: Collection>(from collection: C) -> C.Element? {
        let count = collection.count
        guard count > 0 else { return nil }
        let index = next(upperBound: count)
        let idx = collection.index(collection.startIndex, offsetBy: index)
        return collection[idx]
    }

    /// Shuffle an in-out array in place (Fisher-Yates).
    public mutating func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for i in (1..<array.count).reversed() {
            let j = next(upperBound: UInt64(i + 1))
            array.swapAt(i, Int(j))
        }
    }
}

// MARK: - Xoshiro256**

private func xoshiro256ss(_ state: inout (UInt64, UInt64, UInt64, UInt64)) -> UInt64 {
    func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << UInt64(k)) | (x >> UInt64(64 - k))
    }

    let result = rotl(state.1 &* 5, 7) &* 9
    let t = state.1 << 17

    state.2 ^= state.0
    state.3 ^= state.1
    state.1 ^= state.2
    state.0 ^= state.3

    state.2 ^= t

    state.3 = rotl(state.3, 45)

    return result
}

// MARK: - SplitMix64

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed ^ 0x9E3779B97F4A7C15  // golden ratio
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
