import SwiftUI
import MUCore
import MUContent

/// Debug overlay visibility state (S0.7), launched by `-uitest-overlay`,
/// the three-finger double tap (iOS), or ⌘⇧D (macOS).
@MainActor
final class DebugState: ObservableObject {
    @Published var visible = false
    @Published var seed: UInt64 = 1

    func loadFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uitest-overlay") {
            visible = true
        }
        if let index = arguments.firstIndex(of: "-uitest-seed"), index + 1 < arguments.count,
           let value = UInt64(arguments[index + 1]) {
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
    @State private var playing = false
    @State private var catalog = RegionCatalog(regions: [])

    var body: some View {
        ZStack {
            if playing {
                PlayView(config: GameLaunchConfig.fromLaunchArguments(), catalog: catalog)
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
        .onAppear {
            catalog = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(regions: [])
            // The UI-test harness starts a session without tapping Play.
            if ProcessInfo.processInfo.arguments.contains("-uitest-play") {
                playing = true
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
