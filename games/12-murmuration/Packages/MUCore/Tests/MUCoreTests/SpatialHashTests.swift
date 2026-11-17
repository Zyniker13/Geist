import XCTest
@testable import MUCore

final class SpatialHashTests: XCTestCase {
    /// INV-4 (small sweep): hash queries return exactly the neighbors brute force returns.
    func testHashMatchesBruteForce() {
        var rng = SeededRNG(seed: 2024)
        for configuration in 0..<200 {
            let count = Int(rng.next(upperBound: 120)) + 1
            var posX = [Int32](repeating: 0, count: count)
            var posY = [Int32](repeating: 0, count: count)
            for i in 0..<count {
                posX[i] = Int32(rng.next(upperBound: 1024))
                posY[i] = Int32(rng.next(upperBound: 768))
            }
            var hash = SpatialHash(width: 1024, height: 768, cellSize: 96)
            hash.rebuild(posX: posX, posY: posY, count: count)

            let probeX = Int32(rng.next(upperBound: 1024))
            let probeY = Int32(rng.next(upperBound: 768))
            let radius: Int64 = 96
            let radius2 = radius * radius

            var bruteForce = Set<Int32>()
            for j in 0..<count {
                let dx = Int64(posX[j] - probeX)
                let dy = Int64(posY[j] - probeY)
                if dx * dx + dy * dy <= radius2 { bruteForce.insert(Int32(j)) }
            }

            var fromHash = Set<Int32>()
            let home = hash.cellOf(x: probeX, y: probeY)
            for cy in max(0, home.cy - 1)...min(hash.rows - 1, home.cy + 1) {
                for cx in max(0, home.cx - 1)...min(hash.cols - 1, home.cx + 1) {
                    for slot in hash.range(cx: cx, cy: cy) {
                        let j = hash.birdID(at: slot)
                        let dx = Int64(posX[Int(j)] - probeX)
                        let dy = Int64(posY[Int(j)] - probeY)
                        if dx * dx + dy * dy <= radius2 { fromHash.insert(j) }
                    }
                }
            }
            XCTAssertEqual(fromHash, bruteForce, "configuration \(configuration): hash != brute force")
        }
    }

    func testCellMembershipAndOrdering() {
        let posX: [Int32] = [10, 500, 95, 96, 1000]
        let posY: [Int32] = [10, 500, 95, 96, 1000]
        var hash = SpatialHash(width: 1024, height: 1024, cellSize: 96)
        hash.rebuild(posX: posX, posY: posY, count: 5)
        // Bird 3 at (96,96) is the first bird of cell (1,1); bird 1 at (500,500) is alone.
        XCTAssertEqual(hash.count(cx: 0, cy: 0), 2)  // birds 0 and 2 (positions 10 and 95)
        let cell11 = hash.range(cx: 1, cy: 1)
        XCTAssertEqual(hash.birdID(at: cell11.lowerBound), 3)  // bird 3 first: IDs ascending
    }
}
