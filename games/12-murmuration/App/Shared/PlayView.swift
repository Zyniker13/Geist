// Murmuration app — the play screen (S2.1/S2.2).
//
// The Metal surface plus the HUD overlay, the day-end results card, and the
// debug overlay. Shared between iOS and macOS; only the surface type differs.

import SwiftUI
import MUCore
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
    /// When true, launch the five-step tutorial (P3.2) in its solo region.
    var tutorial = false
    /// When true, run the local two-flock versus (MU-P3.3): the rival flock
    /// is human-driven (no GentleRival) and each touch routes to the nearest
    /// flock.
    var versus = false
    /// The rival pilot's difficulty tier (MU-P4.1); nil keeps the region
    /// default.
    var rivalDifficulty: RivalDifficulty?
    /// Falcon-count override for test fixtures; nil keeps the region
    /// default. The versus routing test pins a two-flock stage and runs
    /// falcon-free (`-uitest-falcons 0`).
    var falconOverride: Int?

    /// Parse the effective UI-test flags (file config on macOS, else argv).
    static func resolved() -> GameLaunchConfig {
        var config = GameLaunchConfig()
        let args = MULaunch.arguments()
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
        if args.contains("-uitest-tutorial") { config.tutorial = true }
        if args.contains("-uitest-versus") { config.versus = true }
        if let difficulty = value("-uitest-difficulty"),
           let tier = RivalDifficulty(rawValue: difficulty) {
            config.rivalDifficulty = tier
        }
        if let seed = value("-uitest-seed"), let n = UInt64(seed) { config.seed = n }
        if let falcons = value("-uitest-falcons"), let n = Int(falcons) {
            config.falconOverride = max(n, 0)
        }
        return config
    }
}

struct PlayView: View {
    @StateObject private var model: GameModel
    @EnvironmentObject private var debug: DebugState

    init(config: GameLaunchConfig, catalog: RegionCatalog) {
        let region = catalog.region(id: config.regionID) ?? catalog.regions.first
        let chosen =
            region
            ?? Region(
                id: "fallback", name: "Fallback",
                worldWidth: 2048, worldHeight: 1536,
                birdCount: 800, falconCount: 1, hasRival: false, rivalStartBirds: 0,
                windSeedOffset: 0, seed: 1,
                roosts: [.init(x: 1024, y: 768, radius: 128)],
                fields: [.init(x: 1024, y: 768, radius: 128, richness: 10)],
                palette: .standard
            )
        // Tutorial (P3.2): load the five-step tutorial and play it in its
        // solo-objective region (a separate content category from the main
        // region set). Falls back to the configured region if either load
        // fails, so a missing tutorial degrades to normal play.
        var tutorial: Tutorial?
        var base = chosen
        if config.tutorial, let t = try? Tutorial.loadBundled() {
            tutorial = t
            if let solo = try? RegionCatalog.loadSoloBundled(),
               let soloRegion = solo.region(id: t.region) {
                base = soloRegion
            }
        }
        var adjusted: Region
        if let birds = config.birdOverride {
            adjusted = base.withBirdCount(birds)
        } else if let seed = config.seed {
            adjusted = base.reseeded(seed)
        } else {
            adjusted = base
        }
        if let falcons = config.falconOverride {
            adjusted = adjusted.withFalconCount(falcons)
        }
        _model = StateObject(
            wrappedValue: GameModel(
                region: adjusted,
                totalDays: config.totalDays,
                autoplay: config.autoplay,
                ticksPerFrame: config.ticksPerFrame,
                tutorial: tutorial,
                versus: config.versus,
                rivalDifficulty: config.rivalDifficulty
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
            if MULaunch.arguments().contains("-uitest-trace") {
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
