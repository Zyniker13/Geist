// Murmuration Meta — campaign model (MU-P5.1).
//
// A campaign is a fixed sequence of regions played back to back; the
// flock size the player ends one region with carries into the next
// (ROADMAP §P5.1 "carried flock size between regions"). The campaign is
// pure data plus pure functions over that data: region ids from the
// content catalog, per-stage carry math, and a deterministic stage
// selection for tests. Persistence lives in the app layer.

import Foundation
import MUContent
import MUCore

/// One stage of the migration campaign: which region plays, and what the
/// player carries into it.
public struct CampaignStage: Codable, Sendable, Equatable, Identifiable {
    /// Region id (must exist in the bundled region catalog).
    public let regionID: String
    /// The flock size carried into this stage (clamped to the region's
    /// bird-count bounds at stage start).
    public let carriedBirds: Int

    public var id: String { regionID }
}

/// The twelve-region migration campaign (MU-P5.1).
///
/// Region order is the campaign route; carry rules are deterministic:
/// the flock the player ends a region with (birds alive at dusk) becomes
/// the next region's starting flock, clamped to a floor of 400 and the
/// region's own `birdCount` cap. A region lost badly (few birds alive)
/// therefore shrinks the flock the rest of the route plays with.
public struct Campaign: Sendable, Equatable {
    /// The campaign route in play order.
    public let route: [String]
    /// Carry floor: a stage never starts below this size.
    public let carryFloor: Int

    /// The standard route: every region in catalog order, floored at 400.
    public init(route: [String], carryFloor: Int = 400) {
        self.route = route
        self.carryFloor = carryFloor
    }

    /// The number of stages (12 in the shipped route).
    public var stageCount: Int { route.count }

    /// The stage list for a campaign that starts with the region's own
    /// bird count. `endSizes[i]` is the birds-alive reading that closes
    /// stage i (from the played session), or nil while the campaign has
    /// not reached that stage. A stage's carry is clamped to the floor
    /// and to the NEXT region's bird count (the size that stage can
    /// actually field); the final stage has no next cap.
    public func stages(
        startBirds: Int, endSizes: [Int?], regions: [String: Region]
    ) -> [CampaignStage] {
        var stages: [CampaignStage] = []
        var carried = startBirds
        for (index, regionID) in route.enumerated() {
            stages.append(CampaignStage(regionID: regionID, carriedBirds: carried))
            guard index < endSizes.count, let ended = endSizes[index] else { break }
            if index + 1 < route.count, let next = regions[route[index + 1]] {
                carried = min(max(ended, carryFloor), max(next.birdCount, carryFloor))
            } else {
                carried = max(ended, carryFloor)
            }
        }
        return stages
    }

    /// The index of the first stage whose end size is unknown (the next
    /// stage to play), or `stageCount` when the campaign is complete.
    public func nextStage(endSizes: [Int?]) -> Int {
        for (index, size) in endSizes.enumerated() where size == nil { return index }
        return min(endSizes.count, stageCount)
    }

    /// True when every stage has an end size.
    public func isComplete(endSizes: [Int?]) -> Bool {
        nextStage(endSizes: endSizes) >= stageCount
    }

    /// Total birds alive at the campaign's close (the last recorded end
    /// size), for the campaign summary card.
    public func finalFlock(endSizes: [Int?]) -> Int? {
        endSizes.last { $0 != nil } ?? nil
    }
}
