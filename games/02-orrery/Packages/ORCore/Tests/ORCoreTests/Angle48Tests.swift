/// Angle48Tests — OR-P0.1: canonical angular unit (acceptance: wraparound ±1…±96).
import Testing
import Foundation
@testable import ORCore

@Suite("Angle48 Tests")
struct Angle48Tests {
    @Test("constructor normalizes all residues into 0...47")
    func normalization() {
        for raw in -96...96 {
            let angle = Angle48(raw)
            #expect(angle.value >= 0 && angle.value <= 47)
            #expect(angle.value == ((raw % 48) + 48) % 48)
        }
        #expect(Angle48(0).value == 0)
        #expect(Angle48(47).value == 47)
        #expect(Angle48(48).value == 0)
        #expect(Angle48(49).value == 1)
        #expect(Angle48(-1).value == 47)
        #expect(Angle48(-48).value == 0)
        #expect(Angle48(-49).value == 47)
        #expect(Angle48(96).value == 0)
        #expect(Angle48(-96).value == 0)
        #expect(Angle48(Int.max % 48 == 0 ? 0 : 1).value >= 0)
    }

    @Test("advanced and rewound wrap by every delta from 1 to 96")
    func wraparoundMatrix() {
        let start = Angle48(5)
        for delta in 1...96 {
            let forward = start.advanced(by: delta)
            let backward = start.rewound(by: delta)
            #expect(forward.value == (5 + delta) % 48)
            #expect(backward.value == ((5 - delta) % 48 + 48) % 48)
            // Symmetry: advancing then rewinding the same delta returns home.
            #expect(forward.rewound(by: delta) == start)
            #expect(backward.advanced(by: delta) == start)
        }
    }

    @Test("double advance equals add")
    func doubleAdvance() {
        let a = Angle48(40)
        #expect(a.advanced(by: 17) == Angle48(57))
        #expect(a.advanced(by: 17).advanced(by: 17) == Angle48(74))
        #expect(a.rewound(by: 48) == a)
    }

    @Test("opposite is half a turn")
    func opposite() {
        #expect(Angle48(0).opposite == Angle48(24))
        #expect(Angle48(23).opposite == Angle48(47))
        #expect(Angle48(24).opposite == Angle48(0))
        #expect(Angle48(47).opposite == Angle48(23))
        #expect(Angle48(10).opposite.opposite == Angle48(10))
    }

    @Test("line index maps every angle to its line 0...23")
    func lineIndex() {
        for a in 0..<48 {
            let angle = Angle48(a)
            #expect(angle.lineIndex >= 0 && angle.lineIndex <= 23)
            // An angle and its opposite share the line.
            #expect(angle.opposite.lineIndex == angle.lineIndex)
            // Exactly two angles map to each line.
            let onLine = (0..<48).filter { Angle48($0).lineIndex == angle.lineIndex }
            #expect(onLine.count == 2)
            #expect(onLine.contains(a))
            #expect(onLine.contains(angle.opposite.value))
        }
    }

    @Test("line sign distinguishes the two endpoints")
    func lineSign() {
        #expect(Angle48(0).lineSign == 1)
        #expect(Angle48(23).lineSign == 1)
        #expect(Angle48(24).lineSign == -1)
        #expect(Angle48(47).lineSign == -1)
        #expect(Angle48(12).lineSign == 1)
        #expect(Angle48(36).lineSign == -1)
    }

    @Test("same-line predicate")
    func sameLine() {
        #expect(Angle48(5).isOnSameLine(as: Angle48(29)))
        #expect(Angle48(5).isOnSameLine(as: Angle48(5)))
        #expect(!Angle48(5).isOnSameLine(as: Angle48(30)))
        #expect(Angle48(24).isOnSameLine(as: Angle48(0)))
    }

    @Test("difference is the shortest signed way around")
    func difference() {
        #expect(Angle48(5).difference(from: Angle48(0)) == 5)
        #expect(Angle48(0).difference(from: Angle48(5)) == -5)
        #expect(Angle48(47).difference(from: Angle48(0)) == -1)
        #expect(Angle48(1).difference(from: Angle48(47)) == 2)
        #expect(Angle48(24).difference(from: Angle48(0)) == 24)
        #expect(Angle48(0).difference(from: Angle48(24)) == 24)  // exact antipodes resolve positive by convention
        #expect(Angle48(12).difference(from: Angle48(36)) == 24)
        for a in 0..<48 {
            for b in 0..<48 {
                let d = Angle48(a).difference(from: Angle48(b))
                #expect(d >= -24 && d <= 24)
                #expect(Angle48(b).advanced(by: d) == Angle48(a))
            }
        }
    }

    @Test("clock labels read like a clock face")
    func clockLabels() {
        #expect(Angle48(0).clockLabel == "12 o'clock")
        #expect(Angle48(12).clockLabel == "3 o'clock")
        #expect(Angle48(24).clockLabel == "6 o'clock")
        #expect(Angle48(36).clockLabel == "9 o'clock")
        #expect(Angle48(16).clockLabel == "4 o'clock")
        #expect(Angle48(18).clockLabel == "4:30")
        #expect(Angle48(2).clockLabel == "12:30")
    }

    @Test("codable round trip")
    func codableRoundTrip() throws {
        for a in 0..<48 {
            let original = Angle48(a)
            let data = try JSONEncoder().encode(original)
            let restored = try JSONDecoder().decode(Angle48.self, from: data)
            #expect(restored == original)
        }
    }

    @Test("constants")
    func constants() {
        #expect(Angle48.count == 48)
        #expect(Angle48.quarter == Angle48(12))
        #expect(Angle48.half == Angle48(24))
    }
}
