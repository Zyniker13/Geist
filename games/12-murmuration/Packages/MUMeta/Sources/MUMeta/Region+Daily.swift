import MUContent

extension Region {
    /// A copy with the daily modifier applied (MU-P5.2): the six
    /// modifiers map to region/engine knobs — strong winds scale the
    /// wind magnitude x2, extra falcons add one, scarce fields halve
    /// richness, fog halves the wind regeneration cadence, double roosts
    /// duplicate every roost (a second, smaller roost shares the
    /// center), and tiny flock halves the starting birds (floor 200).
    public func applying(dailyModifier: DailyModifier) -> Region {
        switch dailyModifier {
        case .strongWinds:
            return withWindStrength(131_072)
        case .extraFalcons:
            return withFalconCount(falconCount + 1)
        case .scarceFields:
            return withFields(
                fields.map { field in
                    FieldDef(
                        x: field.x, y: field.y, radius: field.radius,
                        richness: max(field.richness / 2, 1)
                    )
                }
            )
        case .fog:
            return withWindRegenTicksOverride(300)
        case .doubleRoosts:
            return withRoosts(
                roosts.flatMap { roost in
                    [
                        roost,
                        RoostDef(
                            x: roost.x, y: roost.y, radius: max(roost.radius / 2, 32)
                        ),
                    ]
                }
            )
        case .tinyFlock:
            return withBirdCount(max(birdCount / 2, 200))
        }
    }
}
