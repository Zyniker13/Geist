/// NMRender: input handling, HUD, rendering types.
/// Depends on NMCore.
import Foundation

// MARK: - Render Types

/// Viewport configuration.
public struct Viewport: Codable, Sendable, Equatable, Hashable {
    public var tileWidth: Int
    public var tileHeight: Int
    public var offsetX: Int
    public var offsetY: Int

    public init(tileWidth: Int = 32, tileHeight: Int = 32, offsetX: Int = 0, offsetY: Int = 0) {
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// HUD element types.
public enum HUDElement: Codable, Sendable, Equatable, Hashable {
    case score(Int)
    case hour(Int)
    case weather(String)
    case customerCount(Int)
    case speed(Int)
    case budget(Int, used: Int)
    case pauseOverlay
    case gameOver(score: Int, survived: Bool)
}
