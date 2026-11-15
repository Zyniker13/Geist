/// NMAudio: audio types and playback protocol.
/// Depends on NMCore.
import Foundation

// MARK: - Audio Types

/// Audio event.
public struct AudioEvent: Codable, Sendable, Equatable, Hashable {
    public let kind: AudioKind
    public let volume: Float
    public let pitch: Float

    public enum AudioKind: Codable, Sendable, Equatable, Hashable {
        case serve
        case overflow
        case rain
        case customerArrive
        case nightEnd
    }
}

/// Audio playback protocol (abstract).
public protocol AudioPlayer: Sendable {
    func play(_ event: AudioEvent)
    func setVolume(_ volume: Float)
    func setMuted(_ muted: Bool)
}
