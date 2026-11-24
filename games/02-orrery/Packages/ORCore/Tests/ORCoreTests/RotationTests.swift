/// Rotation and slot-angle math (OR-P1.1): R-1, R-2, R-3, R-7.
import Testing
@testable import ORCore

@Suite("Rotation Tests")
struct RotationTests {

    // MARK: R-2 slot angles

    @Test("slot k of ring i sits at (offset + k × 48/slots) mod 48 (R-2)")
    func slotAngles() {
        let r8 = RingState(slots: 8, offset: 0, speed: 12)
        #expect(r8.slotStep == 6)
        #expect(r8.angle(ofSlot: 0).value == 0)
        #expect(r8.angle(ofSlot: 3).value == 18)
        #expect(r8.angle(ofSlot: 7).value == 42)

        let r12 = RingState(slots: 12, offset: 0, speed: 8)
        #expect(r12.slotStep == 4)
        #expect(r12.angle(ofSlot: 5).value == 20)

        let r16 = RingState(slots: 16, offset: 0, speed: -3)
        #expect(r16.slotStep == 3)

        let r24 = RingState(slots: 24, offset: 0, speed: 2)
        #expect(r24.slotStep == 2)

        // With a nonzero offset.
        let offsetRing = RingState(slots: 8, offset: 30, speed: 0)
        #expect(offsetRing.angle(ofSlot: 2).value == (30 + 12) % 48)
    }

    @Test("variant Standard matches R-2/R-3 slot counts and speeds")
    func standardVariantShape() {
        let v = Variant.standard
        #expect(v.rings.map(\.slots) == [8, 12, 16, 24])
        #expect(v.rings.map(\.speed) == [12, 8, -3, 2])
        #expect(v.reserve == 10)
        #expect(v.maxRounds == 20)
        #expect(v.capturesToWin == 5)
    }

    // MARK: R-7 end-of-round rotation

    @Test("rotateRings advances each ring by its speed, negative counter-rotates (R-7)")
    func roundRotation() {
        let rings = Variant.standard.rings.enumerated().map { index, spec in
            RingState(slots: spec.slots, offset: index * 5, speed: spec.speed)
        }
        let (rotated, deltas) = Rotation.rotateRings(rings)
        #expect(deltas == [12, 8, -3, 2])
        #expect(rotated[0].offset == (0 + 12) % 48)   // 12
        #expect(rotated[1].offset == (5 + 8) % 48)    // 13
        #expect(rotated[2].offset == (10 - 3 + 48) % 48)  // 7
        #expect(rotated[3].offset == (15 + 2) % 48)   // 17
    }

    @Test("rotation carries occupants along: a planet's angle moves with its ring (R-7)")
    func occupantsRideTheRing() {
        var ring = RingState(slots: 8, offset: 0, speed: 12, occupants: [0: .one])
        #expect(ring.angle(ofSlot: 0).value == 0)
        ring.rotate(by: ring.speed)
        #expect(ring.offset == 12)
        #expect(ring.angle(ofSlot: 0).value == 12)
        // The planet's identity (slot 0) is unchanged; only its angle moved.
        #expect(ring.occupants == [0: .one])
    }

    @Test("nudge rotates exactly one slot step (R-5)")
    func nudgeStep() {
        var ring = RingState(slots: 12, offset: 0, speed: 8)
        ring.rotate(by: ring.slotStep)
        #expect(ring.offset == 4)
        ring.rotate(by: -ring.slotStep)
        #expect(ring.offset == 0)
    }

    // MARK: INV-2 offset normalization

    @Test("offsets stay in 0...47 under wrap in both directions (INV-2)")
    func offsetNormalization() {
        var ring = RingState(slots: 16, offset: 46, speed: -3)
        ring.rotate(by: -3)
        #expect(ring.offset == 43)
        ring = RingState(slots: 16, offset: 47, speed: 3)
        ring.rotate(by: 3)
        #expect(ring.offset == 2)
        ring.rotate(by: 48)
        #expect(ring.offset == 2)
        ring.rotate(by: -48)
        #expect(ring.offset == 2)
        // Constructor normalizes too.
        #expect(RingState(slots: 8, offset: 49, speed: 0).offset == 1)
        #expect(RingState(slots: 8, offset: -1, speed: 0).offset == 47)
    }

    @Test("angle(of:) and slot(at:) round-trip across all rings of Standard")
    func slotAngleRoundTrip() {
        for (index, spec) in Variant.standard.rings.enumerated() {
            let ring = RingState(slots: spec.slots, offset: 7, speed: spec.speed)
            for slot in 0..<spec.slots {
                let angle = ring.angle(ofSlot: slot)
                #expect(ring.slot(at: angle) == slot, "ring \(index + 1) slot \(slot)")
            }
        }
    }
}
