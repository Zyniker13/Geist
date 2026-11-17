/// Flock bird storage: struct-of-arrays per the roadmap schema
/// (`Bird { pos: SIMD2<Int32>; vel: SIMD2<Int32>; subFlock: UInt8 }`).
///
/// Positions are raw world units; velocities are Q16.16 fixed-point Int32
/// (18–40 units/tick → raw 1_179_648–2_621_440).
public struct BirdSoA: Sendable, Codable {
    public var posX: [Int32]
    public var posY: [Int32]
    public var velX: [Int32]
    public var velY: [Int32]
    public var subFlock: [UInt8]

    public var count: Int { posX.count }

    public init(capacity: Int) {
        posX = []
        posY = []
        velX = []
        velY = []
        subFlock = []
        posX.reserveCapacity(capacity)
        posY.reserveCapacity(capacity)
        velX.reserveCapacity(capacity)
        velY.reserveCapacity(capacity)
        subFlock.reserveCapacity(capacity)
    }

    /// Append a bird.
    public mutating func append(
        x: Int32, y: Int32,
        velXQ: Int32, velYQ: Int32,
        subFlock: UInt8
    ) {
        posX.append(x)
        posY.append(y)
        velX.append(velXQ)
        velY.append(velYQ)
        self.subFlock.append(subFlock)
    }

    /// Remove the last `n` birds (starvation and falcon kills drop from the tail).
    public mutating func removeLast(_ n: Int) {
        posX.removeLast(n)
        posY.removeLast(n)
        velX.removeLast(n)
        velY.removeLast(n)
        subFlock.removeLast(n)
    }

    /// Remove the bird at `index`, preserving order (O(n) shift).
    public mutating func remove(at index: Int) {
        posX.remove(at: index)
        posY.remove(at: index)
        velX.remove(at: index)
        velY.remove(at: index)
        subFlock.remove(at: index)
    }

    /// Read one bird's position.
    @inline(__always)
    public func position(_ index: Int) -> SIMD2<Int32> {
        SIMD2(posX[index], posY[index])
    }

    /// Read one bird's velocity in Q16.16 raw units.
    @inline(__always)
    public func velocity(_ index: Int) -> SIMD2<Int32> {
        SIMD2(velX[index], velY[index])
    }
}
