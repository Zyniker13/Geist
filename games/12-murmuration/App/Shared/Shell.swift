import SwiftUI
import MUCore
import MUContent
import MUMeta

/// Debug overlay visibility state (S0.7), launched by `-uitest-overlay`,
/// the three-finger double tap (iOS), or ⌘⇧D (macOS).
@MainActor
final class DebugState: ObservableObject {
    @Published var visible = false
    @Published var seed: UInt64 = 1

    init() {
        applyLaunchFlags()
    }

    /// -uitest-overlay and -uitest-seed, applied at construction so the
    /// overlay state does not wait for .task/.onAppear callbacks (which
    /// never fired on the CI runner while body evaluation provably did).
    private func applyLaunchFlags() {
        let arguments = MULaunch.arguments()
        if arguments.contains("-uitest-overlay") {
            visible = true
        }
        MULaunch.note(
            "debugstate: overlayFlag=\(arguments.contains("-uitest-overlay")) visible=\(visible)"
        )
        if let index = arguments.firstIndex(of: "-uitest-seed"), index + 1 < arguments.count,
            let value = UInt64(arguments[index + 1])
        {
            seed = value
        }
    }

    func toggle() {
        visible.toggle()
    }
}

/// The live in-game overlay: FPS, tick, state hash, frame cost.
///
/// The model changes published state every frame, which re-evaluates any
/// observing view every frame. On macOS that per-frame churn destabilized
/// the accessibility tree on the CI runner (rows observed with empty
/// labels, siblings dropping out). The overlay therefore holds no model
/// observation: it samples the model on a 2 Hz task into local state, and
/// its Equatable conformance keeps parent-driven re-evaluations from
/// re-rendering the body. A sampled overlay still satisfies the gate
/// cadence: FPS windows refresh at ~1 Hz and frame cost updates per frame.
struct GameDebugOverlay: View, Equatable {
    private struct Sample {
        var fps = 0
        var tick = 0
        var hash = ""
        var frameMs = 0.0
        var leaders = ""
        var centroids = ""
        var difficulty = ""
        var daily = ""
        var posts = ""
        var pending = ""
    }

    /// All parent-created instances are equal: the body reads only the
    /// sampled state, so parent churn must not re-render it.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { true }

    let model: GameModel
    @State private var sample = Sample()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FPS \(sample.fps)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("FPS \(sample.fps)")
                .accessibilityIdentifier("debug.fps")
            Text("tick \(sample.tick)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("tick \(sample.tick)")
                .accessibilityIdentifier("debug.tick")
            Text("hash \(sample.hash)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("hash \(sample.hash)")
                .accessibilityIdentifier("debug.hash")
            Text("frame \(sample.frameMs, specifier: "%.2f")ms")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("frame \(sample.frameMs, specifier: "%.2f")ms")
                .accessibilityIdentifier("debug.frame")
            if !sample.difficulty.isEmpty {
                Text("diff \(sample.difficulty)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("diff \(sample.difficulty)")
                    .accessibilityIdentifier("debug.difficulty")
            }
            if !sample.daily.isEmpty {
                Text("daily \(sample.daily)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("daily \(sample.daily)")
                    .accessibilityIdentifier("debug.daily")
            }
            if !sample.posts.isEmpty {
                Text("posts \(sample.posts)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("posts \(sample.posts)")
                    .accessibilityIdentifier("debug.posts")
            }
            if !sample.leaders.isEmpty {
                Text(sample.leaders)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sample.leaders)
                    .accessibilityIdentifier("debug.leaders")
            }
            if !sample.centroids.isEmpty {
                Text(sample.centroids)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sample.centroids)
                    .accessibilityIdentifier("debug.centroids")
            }
            if !sample.pending.isEmpty {
                Text("pending \(sample.pending)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("pending \(sample.pending)")
                    .accessibilityIdentifier("debug.pending")
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.55))
        .cornerRadius(6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("debug.overlay")
        .task { await pollModel() }
    }

    /// Samples the model every 0.5 s until the overlay leaves the tree.
    private func pollModel() async {
        while !Task.isCancelled {
            sample = Sample(
                fps: model.fps,
                tick: model.state.tick,
                hash: model.hashLabel,
                frameMs: model.frameMs,
                leaders: Self.leaderLabel(model.state),
                centroids: Self.centroidLabel(model.state),
                difficulty: model.region.hasRival ? model.rivalDifficulty.rawValue : "",
                daily: model.dailyModifier.map {
                    "\(model.dailyDayNumber ?? -1) \($0.displayName)"
                } ?? "",
                posts: model.postCounts,
                pending: Self.pendingLabel(model)
            )
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// "P n L<flock>" while a hover preview is live (MU-P7.2): the number
    /// of previewed waypoints and which flock it steers. Empty when idle.
    @MainActor static func pendingLabel(_ model: GameModel) -> String {
        guard let builder = model.previewBuilder, let flock = model.previewFlock else {
            return ""
        }
        return "\(builder.waypoints.count) L\(flock)"
    }

    /// "L0 x,y L1 x,y" for each flock's leader (MU-P3.3 evidence).
    nonisolated static func leaderLabel(_ state: GameState) -> String {
        var parts: [String] = []
        for flock in 0..<state.subFlockCount where flock < state.leaderPaths.count {
            let p = state.leaderPaths[flock]
            parts.append("L\(flock) \(p.currentX),\(p.currentY)")
        }
        return parts.joined(separator: " ")
    }

    /// "C0 x,y C1 x,y" for each flock's bird centroid when there is more
    /// than one flock (MU-P3.3). Touch routing keys on the centroid
    /// (`GameSurface.routeFlock`), not the leader path point — the two can
    /// drift apart while a flock forages — so UI tests that aim gestures
    /// at a flock must aim at its centroid for nearest-flock routing to be
    /// deterministic.
    nonisolated static func centroidLabel(_ state: GameState) -> String {
        guard state.subFlockCount > 1 else { return "" }
        var parts: [String] = []
        for flock in 0..<state.subFlockCount {
            let c = centroidOfFlock(
                birds: state.birds, assignments: state.subFlockAssignments, subFlock: UInt8(flock)
            )
            parts.append("C\(flock) \(c.x),\(c.y)")
        }
        return parts.joined(separator: " ")
    }
}

/// The menu overlay (S0.7, P0 harness): trivial-state tick/seed/hash.
struct MenuDebugOverlay: View {
    var seed: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FPS 0")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("FPS 0")
                .accessibilityIdentifier("debug.fps")
            Text("tick 0")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("tick 0")
                .accessibilityIdentifier("debug.tick")
            Text("seed \(seed)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("seed \(seed)")
                .accessibilityIdentifier("debug.seed")
            Text("hash \(String(format: "%016llx", stateHash(TrivialState(seed: seed))))")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("hash \(String(format: "%016llx", stateHash(TrivialState(seed: seed))))")
                .accessibilityIdentifier("debug.hash")
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.55))
        .cornerRadius(6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("debug.overlay")
    }
}

/// The menu (S0.4): Play enters the P2 vertical slice.
struct MenuView: View {
    @EnvironmentObject var debug: DebugState
    // Startup state resolves at view-init time, not in .task/.onAppear:
    // on the CI runner those callbacks never fired while body evaluation
    // provably did (menu tests passed), so flag-driven state must not
    // wait for them (docs/STATUS.md, run 44286953243).
    @State private var playing: Bool
    @State private var versusMode = false
    @State private var campaignMode = false
    @State private var dailyMode = false
    /// The menu's rival-difficulty choice (MU-P4.1).
    @State private var difficultyMode: RivalDifficulty = .gentle
    @State private var catalog: RegionCatalog

    init() {
        let arguments = MULaunch.arguments()
        let autoPlay = arguments.contains("-uitest-play")
        _playing = State(initialValue: autoPlay)
        _catalog = State(
            initialValue: (try? RegionCatalog.loadBundled()) ?? RegionCatalog(regions: [])
        )
        if autoPlay {
            MUTrace.log("shell: launching play session args=\(arguments.joined(separator: " "))")
        }
    }

    var body: some View {
        ZStack {
            if playing {
                PlayView(config: launchConfig, catalog: catalog)
            } else {
                menu
            }
            if debug.visible && !playing {
                VStack {
                    Spacer()
                    HStack {
                        MenuDebugOverlay(seed: debug.seed)
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
    }

    /// The launch config with the menu's mode choice applied (the flag
    /// overrides argv's `-uitest-versus` when set from the menu). Campaign
    /// resume: play the first stage without a recorded end size.
    private var launchConfig: GameLaunchConfig {
        var config = GameLaunchConfig.resolved()
        if versusMode { config.versus = true }
        if campaignMode {
            let meta = MetaStore.load()
            let campaign = Campaign(route: MetaState.campaignRoute)
            let next = campaign.nextStage(endSizes: meta.campaignEndSizes)
            config.campaignStage = next
            if next < meta.campaignEndSizes.count + 1, next > 0,
               let carried = meta.campaignEndSizes[next - 1] {
                config.campaignCarriedBirds = carried
            } else if next == 0 {
                config.campaignCarriedBirds = catalog
                    .region(id: MetaState.campaignRoute[0])?.birdCount
            }
        }
        if dailyMode { config.daily = true }
        // An explicit UI-test flag wins over the menu picker default.
        config.rivalDifficulty = config.rivalDifficulty ?? difficultyMode
        return config
    }

    private var menu: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.965, green: 0.706, blue: 0.561),  // apricot #F6B48F
                    Color(red: 0.851, green: 0.518, blue: 0.608),  // rose #D9849B
                    Color(red: 0.431, green: 0.353, blue: 0.600),  // violet #6E5A99
                    Color(red: 0.180, green: 0.165, blue: 0.310),  // dusk indigo #2E2A4F
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                Text("Murmuration")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Steer a flock of thousands with sweeping gestures.")
                    .foregroundStyle(.white.opacity(0.85))
                Button("Play") {
                    playing = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("menu.play")
                // Local two-flock versus (MU-P3.3): two human pilots on one
                // screen; each touch steers the flock nearest it. On the Mac
                // the second flock is the option-drag.
                Button("Versus — two flocks, one screen") {
                    versusMode = true
                    playing = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("menu.versus")
                // Migration campaign (MU-P5.1): twelve regions back to
                // back; the flock carries between them. Resume at the
                // first stage without an end size.
                Button("Migration — twelve regions") {
                    campaignMode = true
                    playing = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("menu.campaign")
                // Today's daily (MU-P5.2): same wind map and modifier on
                // every device for the date.
                Button("Daily challenge") {
                    dailyMode = true
                    playing = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("menu.daily")
                // Rival difficulty (MU-P4.1): the tier overrides the region's
                // default. Regions without a rival ignore it.
                Picker("Rival difficulty", selection: $difficultyMode) {
                    Text("Gentle").tag(RivalDifficulty.gentle)
                    Text("Normal").tag(RivalDifficulty.normal)
                    Text("Hard").tag(RivalDifficulty.hard)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                .accessibilityIdentifier("menu.difficulty")
                Spacer()
            }
            .padding(24)
        }
    }
}
