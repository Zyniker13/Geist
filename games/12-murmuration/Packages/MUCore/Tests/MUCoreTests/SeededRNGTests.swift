import XCTest
@testable import MUCore

final class SeededRNGTests: XCTestCase {
    // Known-answer vectors: Xoshiro256** seeded through SplitMix64, seed = 1.
    func testKnownAnswerVectors() {
        var rng = SeededRNG(seed: 1)
        XCTAssertEqual(rng.next(), 3986457179768683244)
        XCTAssertEqual(rng.next(), 4918436297853093903)
        XCTAssertEqual(rng.next(), 3048561601925910338)
    }

    func testSameSeedProducesIdenticalSequence() {
        var a = SeededRNG(seed: 0xDEADBEEF)
        var b = SeededRNG(seed: 0xDEADBEEF)
        for _ in 0..<64 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testNextUpperBoundStaysInRange() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<1000 {
            let value = rng.next(upperBound: 13)
            XCTAssertTrue(value >= 0 && value < 13)
        }
    }

    func testCodableRoundTripPreservesSequence() throws {
        var a = SeededRNG(seed: 42)
        _ = a.next()
        let data = try JSONEncoder().encode(a)
        var b = try JSONDecoder().decode(SeededRNG.self, from: data)
        for _ in 0..<32 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testShufflePreservesElements() {
        var rng = SeededRNG(seed: 3)
        var values = Array(0..<64)
        let sorted = values.sorted()
        rng.shuffle(&values)
        XCTAssertEqual(values.sorted(), sorted)
    }

    func testRandomElement() {
        var rng = SeededRNG(seed: 5)
        let options = ["a", "b", "c"]
        for _ in 0..<32 {
            let element = rng.randomElement(from: options)
            XCTAssertNotNil(element)
            XCTAssertTrue(options.contains(element!))
        }
        XCTAssertNil(rng.randomElement(from: [] as [Int]))
    }
}
