import SwiftUI
import MUCore
import MUContent

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
struct GameDebugOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FPS \(model.fps)")
                .accessibilityIdentifier("debug.fps")
            Text("tick \(model.state.tick)")
                .accessibilityIdentifier("debug.tick")
            Text("hash \(model.hashLabel)")
                .accessibilityIdentifier("debug.hash")
            Text(String(format: "frame %.2fms", model.frameMs))
                .accessibilityIdentifier("debug.frame")
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

/// The menu overlay (S0.7, P0 harness): trivial-state tick/seed/hash.
struct MenuDebugOverlay: View {
    var seed: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FPS 0")
                .accessibilityIdentifier("debug.fps")
            Text("tick 0")
                .accessibilityIdentifier("debug.tick")
            Text("seed \(seed)")
                .accessibilityIdentifier("debug.seed")
            Text("hash \(String(format: "%016llx", stateHash(TrivialState(seed: seed))))")
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
                PlayView(config: GameLaunchConfig.resolved(), catalog: catalog)
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
                Spacer()
            }
            .padding(24)
        }
    }
}
