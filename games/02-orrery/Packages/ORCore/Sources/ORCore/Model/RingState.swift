/// One ring of the orrery (R-1…R-3).
///
/// A ring carries its slot count, its current `offset` (the rotation of slot 0
/// away from the 0 angle, normalized mod 48), its per-round `speed`, and the
/// occupants of its slots. Slot `k` sits at angle `(offset + k × 48 / slots)`
/// (R-2). The angle-step per slot is `48 / slots`, an exact integer for every
/// slot count in the catalog (8, 12, 16, 24, 48).
public struct RingState: Sendable, Codable, Hashable {
    /// Number of slots on this ring.
    public var slots: Int
    /// Current rotation offset in angle units (0…47, INV-2).
    public var offset: Int
    /// Angle units the ring advances per round (negative = counter-rotation).
    public var speed: Int

    /// Slot → owner (planet on the board). A slot holds at most one planet (INV-1).
    public var occupants: [Int: PlayerID]

    public init(slots: Int, offset: Int = 0, speed: Int, occupants: [Int: PlayerID] = [:]) {
        self.slots = slots
        self.offset = ((offset % 48) + 48) % 48
        self.speed = speed
        self.occupants = occupants
    }

    /// Angle units between adjacent slots on this ring.
    public var slotStep: Int {
        48 / slots
    }

    /// The angle of slot `k` (R-2), normalized mod 48.
    public func angle(ofSlot k: Int) -> Angle48 {
        Angle48(offset + k * slotStep)
    }

    /// The slot whose angle is `angle`, if one exists at that exact angle.
    /// (Slot counts 8/12/16/24/48 all divide 48, so every angle hosts a slot
    /// on every ring; a future variant with a non-dividing count would return nil.)
    public func slot(at angle: Angle48) -> Int? {
        let relative = angle.value - offset
        let normalized = ((relative % 48) + 48) % 48
        guard slotStep > 0, normalized % slotStep == 0 else { return nil }
        return normalized / slotStep
    }

    /// The owner of the planet at `angle`, if any.
    public func owner(at angle: Angle48) -> PlayerID? {
        slot(at: angle).flatMap { occupants[$0] }
    }

    /// All occupied slots as (slot, owner) pairs in slot order.
    public var occupiedSlots: [(slot: Int, owner: PlayerID)] {
        occupants.keys.sorted().compactMap { key in
            occupants[key].map { (key, $0) }
        }
    }

    /// Every planet on this ring as (angle, owner) pairs, in angle order.
    public var planetsByAngle: [(angle: Angle48, owner: PlayerID)] {
        occupiedSlots
            .map { (angle(ofSlot: $0.slot), $0.owner) }
            .sorted { $0.angle.value < $1.angle.value }
    }

    /// Rotate the offset by `delta` angle units, normalizing (R-7, INV-2).
    public mutating func rotate(by delta: Int) {
        offset = ((offset + delta) % 48 + 48) % 48
    }

    /// Place `owner`'s planet into an empty slot. Returns false (leaving state
    /// untouched) when the slot is out of range or already occupied (INV-1).
    public mutating func place(owner: PlayerID, slot k: Int) -> Bool {
        guard occupants[k] == nil, k >= 0, k < slots else { return false }
        occupants[k] = owner
        return true
    }

    /// Remove and return the owner of slot `k`, if occupied.
    public mutating func remove(slot k: Int) -> PlayerID? {
        occupants.removeValue(forKey: k)
    }
}
