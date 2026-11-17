/// Xoshiro256** PRNG seeded through SplitMix64.
///
/// Deterministic, thread-safe, and the sole source of randomness in Core, Content, and AI.
public struct SeededRNG: Sendable, Codable, Equatable, Hashable {
    public var s0: UInt64
    public var s1: UInt64
    public var s2: UInt64
    public var s3: UInt64

    private enum CodingKeys: String, CodingKey {
        case s0, s1, s2, s3
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        s0 = try container.decode(UInt64.self, forKey: .s0)
        s1 = try container.decode(UInt64.self, forKey: .s1)
        s2 = try container.decode(UInt64.self, forKey: .s2)
        s3 = try container.decode(UInt64.self, forKey: .s3)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(s0, forKey: .s0)
        try container.encode(s1, forKey: .s1)
        try container.encode(s2, forKey: .s2)
        try container.encode(s3, forKey: .s3)
    }

    /// Create from a single UInt64 seed via SplitMix64.
    public init(seed: UInt64) {
        var s = SplitMix64(seed: seed)
        self.s0 = s.next(); self.s1 = s.next(); self.s2 = s.next(); self.s3 = s.next()
    }

    /// Create from four UInt64 values directly.
    public init(s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64) {
        self.s0 = s0; self.s1 = s1; self.s2 = s2; self.s3 = s3
    }

    /// The four internal state words as a tuple (read-only).
    public var state: (UInt64, UInt64, UInt64, UInt64) { (s0, s1, s2, s3) }

    /// Return a random UInt64.
    public mutating func next() -> UInt64 {
        xoshiro256ss(&s0, &s1, &s2, &s3)
    }

    /// Return a random UInt64 in `0..<upperBound` (unbiased via rejection sampling).
    public mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        let threshold = (~UInt64.max % upperBound)
        var r: UInt64
        repeat {
            r = next()
        } while r < threshold
        return r % upperBound
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

private func xoshiro256ss(_ s0: inout UInt64, _ s1: inout UInt64, _ s2: inout UInt64, _ s3: inout UInt64) -> UInt64 {
    func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << UInt64(k)) | (x >> UInt64(64 - k))
    }

    let result = rotl(s1 &* 5, 7) &* 9
    let t = s1 << 17

    s2 ^= s0
    s3 ^= s1
    s1 ^= s2
    s0 ^= s3

    s2 ^= t

    s3 = rotl(s3, 45)

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
