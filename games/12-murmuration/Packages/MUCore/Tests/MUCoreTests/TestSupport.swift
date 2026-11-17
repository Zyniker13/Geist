import XCTest
@testable import MUCore

/// Shared test-state builder for the rules-engine suites: a 2048×1536 world
/// with one centered field, configurable roosts spread along the horizontal
/// axis, and the standard falcon/wind configuration.
func makeState(
    birdCount: Int = 100,
    falconCount: Int = 1,
    hasRival: Bool = false,
    roostCount: Int = 1,
    seed: UInt64 = 42
) -> GameState {
    let roostX = roostCount == 1
        ? [Int32(512)]
        : (0..<roostCount).map { Int32(256 + $0 * (2048 - 512) / (roostCount - 1)) }
    let roostY = [Int32](repeating: 768, count: roostCount)
    return GameState(
        birdCount: birdCount,
        worldWidth: 2048,
        worldHeight: 1536,
        boidsParams: BoidsParams(),
        fieldRichness: [10],
        fieldRadius: [128],
        fieldCenterX: [1024],
        fieldCenterY: [768],
        roostCount: roostCount,
        roostCenterX: roostX,
        roostCenterY: roostY,
        roostRadius: [Int](repeating: 128, count: roostCount),
        falconCount: falconCount,
        hasRival: hasRival,
        windSeedOffset: 0,
        seed: seed
    )
}
