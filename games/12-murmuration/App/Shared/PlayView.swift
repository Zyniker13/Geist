// Murmuration app — the play screen (S2.1/S2.2).
//
// The Metal surface plus the HUD overlay, the day-end results card, and the
// debug overlay. Shared between iOS and macOS; only the surface type differs.

import SwiftUI
import MUContent

/// Launch-time configuration for a play session (UI-test harness and menu).
struct GameLaunchConfig {
    var regionID = "meadow"
    var totalDays = 1
    var autoplay = false
    var ticksPerFrame = 1
    var birdOverride: Int?
    var pauseAt: Int?
    var hashUpdates = false
    var seed: UInt64?

    /// Parse the -uitest-* launch arguments.
    static func fromLaunchArguments() -> GameLaunchConfig {
        var config = GameLaunchConfig()
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
                return nil
            }
            return args[index + 1]
        }
        if let id = value("-uitest-region") { config.regionID = id }
        if let days = value("-uitest-days"), let n = Int(days) { config.totalDays = max(n, 1) }
        if args.contains("-uitest-autoplay") { config.autoplay = true }
        if let ticks = value("-uitest-fast"), let n = Int(ticks) { config.ticksPerFrame = max(n, 1) }
        if let birds = value("-uitest-birds"), let n = Int(birds) { config.birdOverride = n }
        if let at = value("-uitest-pause-at"), let n = Int(at) { config.pauseAt = n }
        if args.contains("-uitest-hash") { config.hashUpdates = true }
        if let seed = value("-uitest-seed"), let n = UInt64(seed) { config.seed = n }
        return config
    }
}

struct PlayView: View {
    @StateObject private var model: GameModel
    @EnvironmentObject private var debug: DebugState

    init(config: GameLaunchConfig, catalog: RegionCatalog) {
        let region = catalog.region(id: config.regionID) ?? catalog.regions.first
        let chosen = region ?? Region(
            id: "fallback", name: "Fallback",
            worldWidth: 2048, worldHeight: 1536,
            birdCount: 800, falconCount: 1, hasRival: false, rivalStartBirds: 0,
            windSeedOffset: 0, seed: 1,
            roosts: [.init(x: 1024, y: 768, radius: 128)],
            fields: [.init(x: 1024, y: 768, radius: 128, richness: 10)],
            palette: .standard
        )
        let adjusted: Region
        if let birds = config.birdOverride {
            adjusted = chosen.withBirdCount(birds)
        } else if let seed = config.seed {
            adjusted = chosen.reseeded(seed)
        } else {
            adjusted = chosen
        }
        _model = StateObject(wrappedValue: GameModel(
            region: adjusted,
            totalDays: config.totalDays,
            autoplay: config.autoplay,
            ticksPerFrame: config.ticksPerFrame
        ))
        // Applied after init via the view's task (published-mutable only).
        _pendingPauseAt = State(initialValue: config.pauseAt)
        _pendingHash = State(initialValue: config.hashUpdates)
    }

    @State private var pendingPauseAt: Int?
    @State private var pendingHash: Bool

    var body: some View {
        ZStack {
            surface
                .ignoresSafeArea()
            HUD(model: model)
            if model.dayEnded && !model.finished {
                ResultsCard(model: model)
            }
            if model.finished {
                FinalCard(model: model)
            }
            if debug.visible {
                VStack {
                    Spacer()
                    HStack {
                        GameDebugOverlay(model: model)
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
        .task {
            model.pauseAtTick = pendingPauseAt
            model.hashUpdates = pendingHash
            if ProcessInfo.processInfo.arguments.contains("-uitest-trace") {
                model.enablePlaybackTrace()
            }
        }
    }

    @ViewBuilder
    private var surface: some View {
        #if os(iOS)
        GameSurface(model: model)
        #else
        GameSurfaceMac(model: model)
        #endif
    }
}

struct FinalCard: View {
    @ObservedObject var model: GameModel

    private var tally: (player: Int, rival: Int) {
        model.results.reduce((0, 0)) {
            ($0.0 + $1.playerRoosts, $0.1 + $1.rivalRoosts)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Program done")
                .font(.title2.weight(.semibold))
            Text("\(tally.player) player roosts — \(tally.rival) rival")
            ForEach(model.results) { result in
                Text("Day \(result.day): \(result.playerRoosts)–\(result.rivalRoosts), \(result.birdsAlive) birds")
            }
            Button("Back to menu") {}
                .accessibilityIdentifier("game.menu")
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.final")
    }
}
