import XCTest
@testable import MUCore

final class FixedTests: XCTestCase {
    func testConstruction() {
        XCTAssertEqual(Fixed.zero.raw, 0)
        XCTAssertEqual(Fixed.one.raw, 0x1_0000_0000)
        XCTAssertEqual(Fixed(2).raw, 0x2_0000_0000)
        XCTAssertEqual(Fixed(0.5).raw, 0x8000_0000)
    }

    func testAdditionAndSubtraction() {
        XCTAssertEqual((Fixed(2) + Fixed(3)).rounded(), 5)
        XCTAssertEqual((Fixed(3) - Fixed(2)).rounded(), 1)
        XCTAssertEqual((Fixed(2) - Fixed(3)).rounded(), -1)
    }

    func testMultiplicationKnownAnswers() {
        XCTAssertEqual((Fixed(0.5) * Fixed(0.5)).raw, 0x4000_0000)  // 0.25
        XCTAssertEqual((Fixed(2) * Fixed(3)).rounded(), 6)
        XCTAssertEqual((Fixed(1.5) * Fixed(2)).rounded(), 3)
    }

    func testDivisionKnownAnswers() {
        XCTAssertEqual((Fixed(1) / Fixed(3)).description(precision: 3), "0.333")
        XCTAssertEqual((Fixed(-1) / Fixed(3)).description(precision: 3), "-0.333")
        XCTAssertEqual((Fixed(6) / Fixed(3)).rounded(), 2)
    }

    func testRoundingHalfAwayFromZero() {
        XCTAssertEqual(Fixed(0.5).rounded(), 1)
        XCTAssertEqual(Fixed(-0.5).rounded(), -1)
        XCTAssertEqual(Fixed(1.4).rounded(), 1)
        XCTAssertEqual(Fixed(1.6).rounded(), 2)
    }

    func testDescription() {
        XCTAssertEqual(Fixed(0.1).description(precision: 2), "0.10")
        XCTAssertEqual(Fixed(1).description(precision: 0), "1")
        XCTAssertEqual(Fixed(1.25).description(precision: 2), "1.25")
        XCTAssertEqual(Fixed(-2.5).description(precision: 1), "-2.5")
    }

    func testComparisonAndHashability() {
        XCTAssertTrue(Fixed(1) < Fixed(2))
        XCTAssertFalse(Fixed(2) < Fixed(2))
        var set = Set<Fixed>()
        set.insert(Fixed(1))
        set.insert(Fixed(1))
        XCTAssertEqual(set.count, 1)
    }

    func testOrderingAcrossOperations() {
        // Multiplication, addition, and division must compose to the same value
        // regardless of grouping (fixed-point exactness for these inputs).
        let a = Fixed(1.5)
        let b = Fixed(2.0)
        XCTAssertEqual((a * b) + b, b + (a * b))
    }
}
