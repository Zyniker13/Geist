/// Stable, deterministic state hashing (INV-5 checkpoints).
///
/// Swift's `Hashable` is seed-randomized per process, so checkpoints use an
/// explicit FNV-1a digest over a canonical byte encoding of the state. The
/// encoding is versioned: `ENCODING_VERSION` bumps whenever the field set
/// changes, invalidating old golden hashes on purpose.
public enum StateHash {
    public static let encodingVersion: UInt8 = 5

    /// FNV-1a 64-bit digest of the game state.
    public static func digest(_ state: GameState) -> UInt64 {
        var hasher = FNV1a()
        hasher.byte(encodingVersion)
        hasher.int(state.clock.tick)
        hasher.int(state.clock.ticksPerHour)
        hasher.int(state.speedMultiplier)
        hasher.bool(state.isPaused)
        hasher.int(state.score)
        hasher.int(state.walkwayBudget)
        hasher.int(state.usedBudget)
        // Fixture tokens granted by upgrades (ADR-0010).
        hasher.int(state.fixtureStock.lantern)
        hasher.int(state.fixtureStock.awning)
        hasher.int(state.fixtureStock.busker)
        hasher.int(state.fixtureStock.bridge)
        hasher.int(state.fixtureStock.seating)
        // Demand weights (canonical color order, never dictionary order).
        for color in StallColor.allCases {
            hasher.int(state.zoneWeights[color.debugName] ?? 1)
        }
        hasher.bool(state.calmFirstNight)
        // Tunable spawn ramp (fixed length 12, canonical element order).
        for rate in state.spawnRates { hasher.int(rate) }
        // Challenge modifiers (canonical enum order, never array order).
        for modifier in ChallengeModifier.allCases {
            hasher.bool(state.challengeModifiers.contains(modifier))
        }
        hasher.int(state.queueCapacityMod)
        hasher.int(state.scorePerServe)
        hasher.int(state.clock.nightHours)
        // Walkways: sorted so the digest never depends on Set iteration order.
        hasher.int(state.walkwayTiles.count)
        for tile in state.walkwayTiles.sorted(by: { ($0.col, $0.row) < ($1.col, $1.row) }) {
            hasher.int(tile.col)
            hasher.int(tile.row)
        }
        hasher.int(state.nextCustomerID)
        hasher.int(state.nextFixtureID)
        hasher.int(state.fieldVersion)
        hasher.string(state.contentVersion)

        // Weather
        switch state.weather {
        case .clear:
            hasher.byte(0)
        case .rain(let d):
            hasher.byte(1)
            hasher.int(d)
        }

        // Rain schedule
        hasher.int(state.rainSchedule.count)
        for shower in state.rainSchedule {
            hasher.int(shower.startTick)
            hasher.int(shower.durationTicks)
        }

        // Grid
        hasher.int(state.grid.width)
        hasher.int(state.grid.height)
        for row in 0..<state.grid.height {
            for col in 0..<state.grid.width {
                switch state.grid.tile(at: Tile(col: col, row: row)) {
                case .ground: hasher.byte(0)
                case .plaza: hasher.byte(1)
                case .water(.canal): hasher.byte(2)
                case .building: hasher.byte(3)
                }
            }
        }

        // Gates (sorted by id)
        for gate in state.gates.sorted(by: { $0.id < $1.id }) {
            hasher.int(gate.id)
            hasher.int(gate.position.col)
            hasher.int(gate.position.row)
            hasher.bool(gate.isOpen)
            hasher.optionalInt(gate.opensAtTick)
        }

        // Stalls (sorted by id)
        for stall in state.stalls.sorted(by: { $0.id < $1.id }) {
            hasher.int(stall.id)
            hasher.int(stall.color.hashValueForEncoding)
            hasher.int(stall.position.col)
            hasher.int(stall.position.row)
            hasher.bool(stall.isOpen)
            hasher.optionalInt(stall.scheduledOpenTick)
            hasher.int(stall.queue.count)
            for id in stall.queue { hasher.int(id) }
            hasher.int(stall.serviceProgress)
            hasher.int(stall.overflowTimer)
            hasher.int(stall.serviceTicks)
        }

        // Fixtures (sorted by id)
        for fixture in state.fixtures.sorted(by: { $0.id < $1.id }) {
            hasher.int(fixture.id)
            switch fixture.kind {
            case .lantern: hasher.byte(0)
            case .awning: hasher.byte(1)
            case .busker: hasher.byte(2)
            case .bridge(let length): hasher.byte(3); hasher.int(length)
            case .seat(let count): hasher.byte(4); hasher.int(count)
            }
            hasher.int(fixture.position.col)
            hasher.int(fixture.position.row)
            hasher.int(fixture.radius)
            switch fixture.direction {
            case .none: hasher.byte(255)
            case .north: hasher.byte(0)
            case .south: hasher.byte(1)
            case .east: hasher.byte(2)
            case .west: hasher.byte(3)
            }
        }

        // Customers (sorted by id)
        for customer in state.customers.sorted(by: { $0.id < $1.id }) {
            hasher.int(customer.id)
            hasher.int(customer.color.hashValueForEncoding)
            hasher.int(Int(customer.position.x))
            hasher.int(Int(customer.position.y))
            hasher.byte(customer.state.stateByte)
            hasher.optionalInt(customer.targetStall)
            hasher.optionalInt(customer.targetSeatID)
            hasher.int(customer.waitAtGate)
            hasher.int(customer.seatTimer)
        }

        // Pending offers
        hasher.int(state.pendingOffers.count)
        for offer in state.pendingOffers {
            hasher.string(offer.id)
        }

        return hasher.finish()
    }

    /// Human-readable 16-hex-digit form.
    public static func hex(_ state: GameState) -> String {
        hexDigest(digest(state))
    }

    /// Zero-padded lowercase hex of a raw digest.
    public static func hexDigest(_ digest: UInt64) -> String {
        var value = digest
        var chars: [Character] = []
        let digits: [Character] = Array("0123456789abcdef")
        for _ in 0..<16 {
            chars.append(digits[Int(value & 0xF)])
            value >>= 4
        }
        return String(chars.reversed())
    }
}

/// FNV-1a 64-bit.
struct FNV1a {
    private var hash: UInt64 = 0xcbf29ce484222325

    mutating func byte(_ value: UInt8) {
        hash ^= UInt64(value)
        hash = hash &* 0x100000001b3
    }

    mutating func int(_ value: Int) {
        var v = UInt64(bitPattern: Int64(value))
        for _ in 0..<8 {
            byte(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
    }

    mutating func bool(_ value: Bool) {
        byte(value ? 1 : 0)
    }

    mutating func optionalInt(_ value: Int?) {
        switch value {
        case .none:
            byte(0)
        case .some(let v):
            byte(1)
            int(v)
        }
    }

    mutating func string(_ value: String) {
        for scalar in value.unicodeScalars {
            byte(UInt8(truncatingIfNeeded: scalar.value))
            byte(UInt8(truncatingIfNeeded: scalar.value >> 8))
        }
        byte(0)
    }

    mutating func optionalDirection(_ value: Direction?) {
        switch value {
        case .none: byte(255)
        case .north: byte(0)
        case .south: byte(1)
        case .east: byte(2)
        case .west: byte(3)
        }
    }

    func finish() -> UInt64 {
        hash
    }
}

extension StallColor {
    /// Stable ordinal for hashing (independent of Swift's randomized Hashable).
    var hashValueForEncoding: Int {
        switch self {
        case .noodles: return 0
        case .tea: return 1
        case .skewers: return 2
        case .dumplings: return 3
        case .sweets: return 4
        case .seafood: return 5
        }
    }
}

extension CustomerState {
    var stateByte: UInt8 {
        switch self {
        case .walkingToGate: return 0
        case .atGateWaiting: return 1
        case .walkingToStall: return 2
        case .inQueue: return 3
        case .beingServed: return 4
        case .walkingToSeat: return 5
        case .seated: return 6
        case .walkingToExit: return 7
        case .despawned: return 8
        }
    }
}
