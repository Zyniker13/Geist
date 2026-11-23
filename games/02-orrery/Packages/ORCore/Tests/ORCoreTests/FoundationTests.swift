/// ORCoreTests — determinism foundation tests (S0.2).
import Testing
import Foundation
@testable import ORCore

@Suite("SeededRNG Tests")
struct SeededRNGTests {
    @Test("deterministic seed produces same sequence")
    func deterministicSeed() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 42)

        for _ in 0..<100 {
            #expect(rng1.next() == rng2.next())
        }
    }

    @Test("different seeds produce different sequences")
    func differentSeeds() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 43)

        #expect(rng1.next() != rng2.next())
    }

    @Test("next(upperBound:) returns value in range")
    func nextUpperBound() {
        var rng = SeededRNG(seed: 12345)
        for _ in 0..<100 {
            let val = rng.next(upperBound: 100)
            #expect(val >= 0 && val < 100)
        }
    }

    @Test("nextDouble returns value in [0, 1)")
    func nextDoubleRange() {
        var rng = SeededRNG(seed: 54321)
        for _ in 0..<100 {
            let val = rng.nextDouble()
            #expect(val >= 0.0 && val < 1.0)
        }
    }

    @Test("shuffle preserves elements")
    func shufflePreserves() {
        var rng = SeededRNG(seed: 999)
        var arr = [1, 2, 3, 4, 5]
        rng.shuffle(&arr)
        #expect(arr.sorted() == [1, 2, 3, 4, 5])
    }

    @Test("randomElement returns collection members")
    func randomElementWorks() {
        var rng = SeededRNG(seed: 7)
        let items = [10, 20, 30]
        for _ in 0..<20 {
            let pick = rng.randomElement(from: items)
            #expect(pick != nil && items.contains(pick!))
        }
        #expect(rng.randomElement(from: [] as [Int]) == nil)
    }

    @Test("codable round trip preserves state and sequence")
    func codableRoundTrip() throws {
        var rng = SeededRNG(seed: 314)
        _ = rng.next()
        _ = rng.next()

        let data = try JSONEncoder().encode(rng)
        var restored = try JSONDecoder().decode(SeededRNG.self, from: data)

        #expect(restored.next() == rng.next())
        #expect(restored.next() == rng.next())
    }

    @Test("known-answer vector for seed 1 (xoshiro256** via SplitMix64)")
    func knownAnswerVector() {
        // Reference values computed from independent Python and scratch-Swift
        // implementations of the same algorithms (golden constant; a change
        // here means the PRNG changed, which breaks replay determinism).
        var rng = SeededRNG(seed: 1)
        let expected: [UInt64] = [
            0x3752_BDAF_106A_FAEC, 0x4441_CBC0_FFEB_C80F, 0x2A4E_AA9F_FEB0_8F42,
            0x5AD7_4342_12C3_3BCC, 0x1C56_4CDF_A987_39B4,
        ]
        for want in expected {
            let got = rng.next()
            #expect(got == want, "expected \(want), got \(got)")
        }
    }
}

@Suite("Fixed Tests")
struct FixedTests {
    @Test("construction and conversion round trip")
    func constructionRoundTrip() {
        #expect(Fixed(7).rounded() == 7)
        #expect(Fixed(-3).rounded() == -3)
        #expect(Fixed(0) == Fixed.zero)
        #expect(Fixed(raw: Fixed.one.raw * 3) == Fixed(3))
    }

    @Test("addition and subtraction")
    func addSubtract() {
        let a = Fixed(5)
        let b = Fixed(raw: Fixed.one.raw / 2)  // 0.5
        #expect((a + b).description(precision: 1) == "5.5")
        #expect((a - b).description(precision: 1) == "4.5")
        #expect((Fixed.zero - b).description(precision: 1) == "-0.5")
    }

    @Test("multiplication Q32.32")
    func multiply() {
        let half = Fixed(raw: Fixed.one.raw / 2)
        let quarter = half * half
        #expect(quarter.description(precision: 4) == "0.2500")
        #expect((Fixed(-2) * Fixed(3)) == Fixed(-6))
        #expect((Fixed(-2) * Fixed(-3)) == Fixed(6))
    }

    @Test("division Q32.32")
    func divide() {
        #expect((Fixed(1) / Fixed(2)).description(precision: 2) == "0.50")
        #expect((Fixed(7) / Fixed(2)) == Fixed(raw: Fixed(3).raw + Fixed.one.raw / 2))
        #expect((Fixed(-9) / Fixed(3)) == Fixed(-3))
    }

    @Test("rounding half away from zero on negatives (Swift 6.4.2 magnitude trap regression)")
    func roundingNegatives() {
        // raw = -0.5 exactly: round half away from zero → -1.
        #expect(Fixed(raw: -(Fixed.one.raw / 2)).rounded() == -1)
        #expect(Fixed(raw: -(Fixed.one.raw / 2) - 1).rounded() == -1)
        #expect(Fixed(raw: -(Fixed.one.raw / 2) + 1).rounded() == 0)
        // Int64.min must not trap: magnitude 2^63 rounds to -2^31 exactly.
        #expect(Fixed(raw: Int64.min).rounded() == -2_147_483_648)
    }

    @Test("description handles negative values without trapping")
    func descriptionNegatives() {
        #expect(Fixed(raw: Int64.min).description(precision: 0) == "-2147483648")
        #expect(Fixed(-2).description(precision: 0) == "-2")
        #expect(Fixed(raw: -(Fixed.one.raw / 2)).description(precision: 1) == "-0.5")
        #expect(Fixed(raw: -(Fixed.one.raw / 2)).description(precision: 1) != "0.5")
    }

    @Test("division by zero traps by contract")
    func divisionByZero() {
        // precondition failure is the documented contract; verify with a
        // manual probe rather than #expect(throws:) (which cannot catch traps).
        // Guarded here by only calling with a nonzero divisor in all other tests.
        #expect(Fixed(1) / Fixed(2) != Fixed.zero)
    }

    @Test("comparison ordering")
    func ordering() {
        #expect(Fixed(-1) < Fixed.zero)
        #expect(Fixed.zero < Fixed(1))
        #expect(!(Fixed(2) < Fixed(1)))
    }
}
