import SwiftUI
import MUCore

/// Debug overlay state (S0.7): FPS, tick, seed, and state hash.
///
/// Values come from the running simulation once the core loop lands (P2); the seed and
/// hash are live from P0 via the trivial-state harness.
@MainActor
final class DebugState: ObservableObject {
    @Published var visible = false
    @Published var fps = 0
    @Published var tick = 0
    @Published var seed: UInt64 = 1
    @Published var hash = ""

    func loadFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uitest-overlay") {
            visible = true
        }
        if let index = arguments.firstIndex(of: "-uitest-seed"), index + 1 < arguments.count,
           let value = UInt64(arguments[index + 1]) {
            seed = value
        }
        refreshHash()
    }

    func toggle() {
        visible.toggle()
    }

    func refreshHash() {
        hash = String(format: "%016llx", stateHash(TrivialState(seed: seed)))
    }
}

/// The overlay itself: four monospaced rows over the scene, bottom-left.
struct DebugOverlay: View {
    @ObservedObject var debug: DebugState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FPS \(debug.fps)")
                .accessibilityIdentifier("debug.fps")
            Text("tick \(debug.tick)")
                .accessibilityIdentifier("debug.tick")
            Text("seed \(debug.seed)")
                .accessibilityIdentifier("debug.seed")
            Text("hash \(debug.hash)")
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

/// P0 placeholder menu (S0.4): the app launches here until the core-loop slice in P2.
struct MenuView: View {
    @EnvironmentObject var debug: DebugState

    var body: some View {
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
                    // The playable slice arrives with P2.
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("menu.play")
                Spacer()
                Text("Placeholder menu — core loop lands in P2")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(24)

            VStack {
                Spacer()
                HStack {
                    if debug.visible {
                        DebugOverlay(debug: debug)
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
    }
}
