// Murmuration app — the play screen (S2.1/S2.2).
//
// The Metal surface plus the HUD overlay, the day-end results card, and the
// debug overlay. Shared between iOS and macOS; only the surface type differs.

import SwiftUI
import MUCore
import MUContent
import MUMeta
import MUPlatform

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
    /// Poster injection for UI tests (MU-P7.1): "-uitest-poster mock" uses
    /// the deterministic MockPoster instead of Game Center.
    var poster: ScoresPosting?
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
    /// Campaign mode (MU-P5.1): the campaign's stage index to play and
    /// the flock size carried into it. When set, `-uitest-region` is
    /// ignored and the stage's region plays.
    var campaignStage: Int?
    var campaignCarriedBirds: Int?
    /// Daily mode (MU-P5.2): play today's daily challenge (modifier +
    /// daily wind map) instead of the plain region.
    var daily = false
    /// UI-test override for the daily's day number (0 = today). Real
    /// launches are always today.
    var dailyDayOverride: Int?
    /// Scripted hover path (MU-P7.2): waypoint pairs "x,y" separated by
    /// `;`, fed one per frame through the hover preview while
    /// `-uitest-preview` is active. Nil = no scripted hover.
    var hoverScript: [SIMD2<Float>]?
    /// Accessibility options (MU-P8.1): Reduce Motion and high-contrast
    /// rival patterning. Set from the menu toggles (or the UI-test flags
    /// `-uitest-reduce-motion` / `-uitest-high-contrast`).
    var reduceMotion = false
    var highContrastRival = false
    /// Falcon-assist steering (MU-P8.2): sim-level auto-avoidance of
    /// falcons (an avoidance force in the boids kernel, seeded
    /// deterministically). Menu toggle or `-uitest-assist`.
    var falconAssist = false

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
        if args.contains("-uitest-poster-mock") { config.poster = MockPoster() }
        if args.contains("-uitest-tutorial") { config.tutorial = true }
        if args.contains("-uitest-versus") { config.versus = true }
        if let difficulty = value("-uitest-difficulty"),
            let tier = RivalDifficulty(rawValue: difficulty)
        {
            config.rivalDifficulty = tier
        }
        if let seed = value("-uitest-seed"), let n = UInt64(seed) { config.seed = n }
        if let falcons = value("-uitest-falcons"), let n = Int(falcons) {
            config.falconOverride = max(n, 0)
        }
        if let stage = value("-uitest-campaign"), let n = Int(stage) {
            config.campaignStage = max(n, 0)
        }
        if let carried = value("-uitest-carry"), let n = Int(carried) {
            config.campaignCarriedBirds = max(n, 1)
        }
        if args.contains("-uitest-daily") { config.daily = true }
        if let day = value("-uitest-daily-day"), let n = Int(day) {
            config.dailyDayOverride = n
        }
        if args.contains("-uitest-reduce-motion") { config.reduceMotion = true }
        if args.contains("-uitest-high-contrast") { config.highContrastRival = true }
        if args.contains("-uitest-assist") { config.falconAssist = true }
        if let script = value("-uitest-hover") {
            config.hoverScript = script.split(separator: ";").compactMap { part in
                let pair = part.split(separator: ",")
                guard pair.count == 2, let x = Float(pair[0]), let y = Float(pair[1]) else {
                    return nil
                }
                return SIMD2(x, y)
            }
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
                let soloRegion = solo.region(id: t.region)
            {
                base = soloRegion
            }
        }
        // Campaign (MU-P5.1): the stage's region replaces the launch
        // region; the carried flock size becomes the bird override.
        if let stage = config.campaignStage,
            stage < MetaState.campaignRoute.count,
            let campaignRegion = catalog.region(id: MetaState.campaignRoute[stage])
        {
            base = campaignRegion
        }
        // Daily (MU-P5.2): today's wind map replaces the region's own; the
        // modifier is recorded for the HUD and the difficulty row. UI tests
        // pin a day number so the challenge is deterministic across runs.
        var dailyModifier: DailyModifier?
        var dailyDayNumber: Int?
        if config.daily {
            let now: Date
            if let day = config.dailyDayOverride {
                now = DailyChallenge.epoch.addingTimeInterval(Double(day) * DailyChallenge.secondsPerDay)
            } else {
                now = Date()
            }
            let challenge = DailyChallenge(date: DailyChallenge.epoch, now: now)
            base = base.withWindOffset(challenge.windSeedOffset)
            base = base.applying(dailyModifier: challenge.modifier)
            dailyModifier = challenge.modifier
            dailyDayNumber = challenge.dayNumber
        }
        var adjusted: Region
        if let birds = config.campaignCarriedBirds {
            adjusted = base.withBirdCount(birds)
        } else if let birds = config.birdOverride {
            adjusted = base.withBirdCount(birds)
        } else if let seed = config.seed {
            adjusted = base.reseeded(seed)
        } else {
            adjusted = base
        }
        if let falcons = config.falconOverride {
            adjusted = adjusted.withFalconCount(falcons)
        }
        if config.falconAssist {
            adjusted = adjusted.withFalconAssist(true)
        }
        let accessibilityReduceMotion =
            config.reduceMotion
            || Accessibility.platformReduceMotionEnabled()
        _model = StateObject(
            wrappedValue: GameModel(
                region: adjusted,
                totalDays: config.totalDays,
                autoplay: config.autoplay,
                ticksPerFrame: config.ticksPerFrame,
                tutorial: tutorial,
                versus: config.versus,
                rivalDifficulty: config.rivalDifficulty,
                dailyModifier: dailyModifier,
                dailyDayNumber: dailyModifier != nil ? dailyDayNumber : nil,
                campaignStage: config.campaignStage,
                poster: config.poster,
                reduceMotion: accessibilityReduceMotion,
                highContrastRival: config.highContrastRival
            ))
        // Applied after init via the view's task (published-mutable only).
        _pendingPauseAt = State(initialValue: config.pauseAt)
        _pendingHash = State(initialValue: config.hashUpdates)
        launchConfig = config
    }

    @State private var pendingPauseAt: Int?
    @State private var pendingHash: Bool
    /// The ambience engine (MU-P6.2). Owned by the view so it starts and
    /// stops with the play screen; `@State` keeps it across re-renders.
    @State private var audio: AudioController?

    /// The launch config this view was built from; the .task closure needs
    /// it for flags (scripted hover) that arrive after init.
    private let launchConfig: GameLaunchConfig

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
            // Scripted hover (MU-P7.2): when -uitest-preview is active and
            // a hover script was given, queue its points; one is consumed
            // per engine tick through the real preview path.
            if launchConfig.hoverScript != nil
                && MULaunch.arguments().contains("-uitest-preview")
            {
                model.scriptedHover = launchConfig.hoverScript ?? []
            }
            if MULaunch.arguments().contains("-uitest-trace") {
                model.enablePlaybackTrace()
            }
            // Ambience (MU-P6.2): start the engine and hand the model the
            // controller so ticks feed it metrics. Tests and CI launch with
            // audio unavailable-safe: start() degrades to silence.
            if audio == nil {
                let controller = AudioController()
                controller.setRegion(regionID: model.region.id, padLevel: 0.28)
                controller.start()
                audio = controller
                model.audio = controller
            }
        }
        .onDisappear {
            audio?.stop()
            model.audio = nil
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
