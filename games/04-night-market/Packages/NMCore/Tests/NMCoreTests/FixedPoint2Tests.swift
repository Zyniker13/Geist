import Foundation
import NMCore
import Testing

@Suite("FixedPoint2 Tests")
struct FixedPoint2Tests {
    @Test("tile convention: 1 tile = 1,024 units")
    func tileUnits() {
        let tileOrigin = FixedPoint2(x: 3 * 1024, y: 5 * 1024)
        #expect(tileOrigin.x == 3072)
        #expect(tileOrigin.y == 5120)
    }

    @Test("origin is zero")
    func originIsZero() {
        #expect(FixedPoint2.origin.x == 0)
        #expect(FixedPoint2.origin.y == 0)
    }

    @Test("distance squared is exact integer math")
    func distanceSquared() {
        let a = FixedPoint2(x: 0, y: 0)
        let b = FixedPoint2(x: 3, y: 4)
        #expect(a.distanceSquared(to: b) == 25)
        #expect(b.distanceSquared(to: a) == 25)
        #expect(a.distanceSquared(to: a) == 0)
    }

    @Test("distance squared handles one tile away")
    func distanceSquaredOneTile() {
        let a = FixedPoint2(x: 0, y: 0)
        let oneTile = FixedPoint2(x: 1024, y: 0)
        #expect(a.distanceSquared(to: oneTile) == 1024 * 1024)
    }

    @Test("manhattan distance in tiles truncates sub-tile offsets")
    func manhattanTiles() {
        let a = FixedPoint2(x: 0, y: 0)
        // Same tile: sub-tile offset does not count
        let subTile = FixedPoint2(x: 1000, y: 1000)
        #expect(a.manhattanTiles(to: subTile) == 0)
        // One tile in x
        let oneTileX = FixedPoint2(x: 1024, y: 0)
        #expect(a.manhattanTiles(to: oneTileX) == 1)
        // Two tiles: one in x, one in y
        let diag = FixedPoint2(x: 2048, y: 1024)
        #expect(a.manhattanTiles(to: diag) == 3)
    }

    @Test("vector addition and subtraction wrap safely")
    func addSubtract() {
        let a = FixedPoint2(x: 100, y: 200)
        let b = FixedPoint2(x: 30, y: 40)
        let sum = a + b
        #expect(sum.x == 130)
        #expect(sum.y == 240)
        let diff = sum - b
        #expect(diff == a)
    }

    @Test("ordering is lexicographic")
    func ordering() {
        let a = FixedPoint2(x: 1, y: 2)
        let b = FixedPoint2(x: 1, y: 3)
        let c = FixedPoint2(x: 2, y: 0)
        #expect(a < b)
        #expect(b < c)
        #expect(a < c)
    }

    @Test("codable round trip preserves values")
    func codableRoundTrip() throws {
        let p = FixedPoint2(x: -1024, y: 4096)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(FixedPoint2.self, from: data)
        #expect(decoded == p)
    }
}
