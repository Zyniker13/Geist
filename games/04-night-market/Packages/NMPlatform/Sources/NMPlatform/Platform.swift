/// NMPlatform: input, platform abstraction.
/// Depends on NMCore.
import Foundation

// MARK: - Platform Types

/// Input event.
public enum InputEvent: Codable, Sendable, Equatable, Hashable {
    case tap(col: Int, row: Int)
    case pan(dx: Int, dy: Int)
    case pinch(scale: Float)
    case keyPress(String)
    case menuAction(String)
}

/// Platform input protocol.
public protocol InputProvider: Sendable {
    func pollEvents() -> [InputEvent]
}
